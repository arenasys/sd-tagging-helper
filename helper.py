import sys
import traceback
import datetime
import glob
import os
import json
import time
import argparse
import platform
import shutil
import statistics
import signal
import subprocess

from PIL import Image, ImageDraw, ImageQt
from PyQt5.QtCore import pyqtProperty, pyqtSignal, pyqtSlot, QObject, QUrl, QThread, QCoreApplication, Qt, QRunnable, QThreadPool, QPointF
from PyQt5.QtGui import QDesktopServices
from PyQt5.QtQml import QQmlApplicationEngine
from PyQt5.QtWidgets import QFileDialog, QApplication
from PyQt5.QtQuick import QQuickImageProvider

import qml_rc

CONFIG = "config.json"
EXT = [".png", ".jpg", ".jpeg", ".webp"]
MX_TAGS = 30
SMILES = ["0_0","(o)_(o)","+_+","+_-","._.","<o>_<o>","<|>_<|>","=_=",">_<","3_3","6_9",">_o","@_@","^_^","o_o","u_u","x_x","|_|","||_||"]
ELLIPSIS = "•••"

MX_FILE = 250
MX_PATH = 4000
if platform.system() == "Windows":
    MX_PATH = 250

def get_metadata(image_file):
    tags = []
    m1 = image_file + ".txt"
    m2 = ".".join(image_file.split(".")[:-1]) + ".txt"
    for m in [m1, m2]:
        if os.path.isfile(m):
            tags = get_tags(m)
            break
    else:
        g = image_file + ".json"
        if os.path.isfile(g):
            tags = get_tags_gallerydl(g)
    return tags

def get_images(images_path, staging_path):
    images = []

    files = []
    for e in EXT:
        files += glob.glob(images_path + "/*" + e)

    for f in files:
        old_m = os.path.join("staging", os.path.basename(f) + ".json")
        m = os.path.join(staging_path, os.path.basename(f) + ".json")
        if os.path.exists(old_m) and not os.path.exists(m):
            print(f"INFO: migrating {old_m} to {m}")
            shutil.copy(old_m, m)

        img = Img(f, m)
        img.readStagingData()
        if not img.ready:
            img.tags = get_metadata(f)
        images += [img]

    return images

def positionContain(w, h, d):
    if w > h:
        w,h = d, (h/w)*d
    else:
        w,h = (w/h)*d, d
    x = int((d-w)/2)
    y = int((d-h)/2)
    return x, y, w, h

def positionCenter(w, h, d):
    if w < h:
        w,h = d, (h/w)*d
    else:
        w,h = (w/h)*d, d
    x = int((d-w)/2)
    y = int((d-h)/2)
    return x, y, w, h

def extract_tags_gallerydl(text):
    j = json.loads(text)
    booru = j["category"]
    tags = []
    if booru == "danbooru" or booru == "sankaku":
        tags = j["tag_string"].split()
    elif booru == "gelbooru" or booru == "rule34":
        tags = j["tags"].split()
    else:
        print(f"ERROR: {booru} is UNSUPPORTED!")
        exit(1)
    tags = [t.strip() for t in tags]
    return tags

def extract_tags(text):
    seperator = " "
    if "," in text:
        seperator = ","
    tags = [t.strip().replace(" ", "_") for t in text.split(seperator)]
    return tags

def tags_to_prompt(tags):
    tags = tags.copy()
    for i in range(len(tags)):
        t = tags[i]
        if not t in SMILES:
            tags[i] = t.replace("_", " ")
    prompt = ", ".join(tags)
    return prompt

def get_tags(tag_file):
    with open(tag_file, "r", encoding="utf-8") as f:
        return extract_tags(f.read())

def get_tags_gallerydl(tag_file):
    with open(tag_file, "r", encoding="utf-8") as f:
        return extract_tags_gallerydl(f.read())

def get_tags_from_csv(path):
    tags = []
    with open(path, "r", encoding="utf-8") as file:
        for line in file:
            t = line.rstrip().split(",")
            if len(t) >= 2:
                tags += [(t[0],int(t[1]))]
            else:
                tags += [(t[0],0)]
    return tags

def put_tag_in_csv(path, tag):
    with open(path, "a", encoding="utf-8") as file:
        file.write(f"{tag},6\n")

def get_json(file):
    if not os.path.isfile(file):
        return {}
    with open(file, "r", encoding="utf-8") as f:
        return json.loads(f.read())

def put_json(j, file, append=True):
    if append and os.path.isfile(file):
        jj = get_json(file)
        for k in jj:
            if not k in j:
                j[k] = jj[k]
    
    with open(file, "w", encoding="utf-8") as f:
        json.dump(j, f)

def to_filename(base, tags):
    illegal = '<>:"/\\|?*'
    name = ''.join([c for c in tags_to_prompt(tags) if not c in illegal])
    return os.path.join(base, name)

class DDBWorker(QObject):
    resultCallback = pyqtSignal(list)
    loadedCallback = pyqtSignal()

    def __init__(self,  parent=None):
        super().__init__(parent)

    def add_import_paths(self, webui_folder):
        self.webui_folder = webui_folder
        sys.path.insert(0, self.webui_folder)

        venv_folder = os.path.join(self.webui_folder, 'venv', 'lib', '*')
        for venv_path in glob.glob(venv_folder, recursive = True):
            if not venv_path.endswith("site-packages"):
                venv_path = os.path.join(venv_path, "site-packages")

            if os.path.isdir(venv_path):
                sys.path.insert(0, venv_path)

    @pyqtSlot()
    def load(self):
        model_path = os.path.join(self.webui_folder, "models", "torch_deepdanbooru", "model-resnet_custom_v3.pt")

        if not os.path.exists(model_path):
            print("NO DDB MODEL FOUND")
            return

        import torch
        from modules import deepbooru_model
        self.model = deepbooru_model.DeepDanbooruModel()

        self.model.load_state_dict(torch.load(model_path, map_location="cpu"))
        self.model.eval()

        self.loadedCallback.emit()

    @pyqtSlot('QString', bool, float, float, float)
    def interrogate(self, file, ready, x, y, s):
        img = Img(file, "")
        if ready:
            img.setCrop(x,y,s)
        else:
            img.prepare()

        img = img.doCrop(512)

        import numpy as np
        import torch

        a = np.expand_dims(np.array(img, dtype=np.float32), 0) / 255

        with torch.no_grad():
            x = torch.from_numpy(a)
            y = self.model(x)[0]
            y = y.detach().cpu().numpy()

        outputs = []
        for tag, probability in zip(self.model.tags, y):
            outputs += [(tag, probability)]
        outputs.sort(key=lambda a: a[1], reverse=True)        
        if len(outputs) > 100:
            outputs = outputs[:100]
        outputs = [t[0] for t in outputs]

        self.resultCallback.emit(outputs)

class CropRunnableSignals(QObject):
    completed = pyqtSignal(int, 'QString')

class CropRunnable(QRunnable):
    def __init__(self, index, img, dim, out_folder, img_mode, prompt_mode, ext_mode):
        super(CropRunnable, self).__init__()
        self.index = index
        self.img = img
        self.dim = dim
        self.out_folder = out_folder
        self.img_mode = img_mode
        self.prompt_mode = prompt_mode
        self.ext_mode = ext_mode
        self.signals = CropRunnableSignals()

    @pyqtSlot()
    def run(self):
        source_name = os.path.basename(self.img.source)

        img_path = os.path.join(self.out_folder, os.path.splitext(source_name)[0])

        if self.prompt_mode == 0:
            self.img.writePrompt(img_path+".txt")
        elif self.prompt_mode == 1:
            self.img.writePromptJson(img_path+".json")
        elif self.prompt_mode == 2 and self.img.tags:
            tags = self.img.getTags()
            while True:
                img_path = to_filename(self.out_folder, tags)
                if len(img_path) < MX_PATH and len(img_path)-len(self.out_folder) < MX_FILE:
                    break
                tags = tags[:-1]

        if self.img_mode != 3:
            img_ext = ""
            if self.ext_mode == 0:
                img_ext = ".jpg"
            elif self.ext_mode == 1:
                img_ext = ".png"
            elif self.ext_mode == 2:
                img_ext = os.path.splitext(self.img.source)[1]

            img_file = img_path+img_ext

            if self.img_mode == 0:
                self.img.writeCrop(img_file, self.dim)
            elif self.img_mode == 1:
                self.img.writeScale(img_file, self.dim)
            elif self.img_mode == 2:
                self.img.writeOriginal(img_file)

        self.signals.completed.emit(self.index, source_name)

class CropWorker(QObject):
    progressCallback = pyqtSignal(float, 'QString')

    def __init__(self, images, out_folder, dimension, parent=None):
        super().__init__(parent)
        self.images = images
        self.out_folder = out_folder
        self.dim = dimension
        self.image_mode = 0
        self.ext_mode = 0
        self.prompt_mode = 0
        self.thread_count = 0
        self.pool = QThreadPool()

    @pyqtSlot(int, int, int, int)
    def setup(self, img_mode, ext_mode, prompt_mode, thread_count):
        self.img_mode = img_mode
        self.ext_mode = ext_mode
        self.prompt_mode = prompt_mode
        self.thread_count = thread_count

    @pyqtSlot()
    def start(self):
        self.progress = 0
        self.total = len(self.images)
        self.finishTotal = self.total
        
        self.progressCallback.emit(0.0, "Starting...")

        self.pool.setMaxThreadCount(self.thread_count)
        
        args = (self.dim, self.out_folder, self.img_mode, self.prompt_mode, self.ext_mode)
        runnables = [CropRunnable(i, self.images[i], *args) for i in range(len(self.images))]

        for r in runnables:
            r.signals.completed.connect(self.runnableCompleted)
            r.setAutoDelete(True)
            self.pool.start(r)

    @pyqtSlot()
    def stop(self):
        self.pool.clear()
        self.finishTotal = self.progress + self.pool.activeThreadCount()

    @pyqtSlot(int, 'QString')
    def runnableCompleted(self, index, name):
        self.progress += 1
        self.progressCallback.emit(self.progress/self.total, name)

        if self.progress == self.finishTotal:
            self.progressCallback.emit(-1.0, "Done")

class Cache:
    def __init__(self, mx):
        self.mx = mx
        self.queue = []
        self.cache = {}
    
    def fetch(self, file):
        if not file in self.cache:
            if len(self.queue) == self.mx:
                pop = self.queue[0]
                del self.cache[pop]
            self.queue += [file]
            self.cache[file] = Image.open(file).convert("RGB")
        return self.cache[file]

class Img:
    def __init__(self, image_path, staging_path):
        self.cache = None
        self.globals = None
        self.source = image_path
        self.staging_path = staging_path
        self.ready = False # ready to be displayed (needs crop offsets/scale)
        self.changed = False
        self.ddb = []
        self.w, self.h = None, None
        self.offset_x, self.offset_y, self.scale = None, None, None
        self.letterboxs = []
        self.tags = []

    def contain(self):
        if not self.w or not self.h:
            with Image.open(self.source) as img:
                self.w, self.h = img.size
        x, y, w, h = positionContain(self.w, self.h, 1024)
        self.setCrop(x/1024, y/1024, 1.0)

    def center(self):
        if not self.w or not self.h:
            with Image.open(self.source) as img:
                self.w, self.h = img.size
        x, y, w, h = positionCenter(self.w, self.h, 1024)
        _, _, w2, _ = positionContain(self.w, self.h, 1024)
        self.setCrop(x/1024, y/1024, w/w2)
        
    def readStagingData(self):
        if not os.path.isfile(self.staging_path):
            self.tags = []
            return False

        data = {}
        with open(self.staging_path, 'r', encoding="utf-8") as f:
            data = json.load(f)
        x,y,s = data["offset_x"], data["offset_y"], data["scale"]
        self.setCrop(x,y,s)
        self.tags = data["tags"]
        return True
    
    def writeStagingData(self):
        data = {"offset_x": self.offset_x,
                "offset_y": self.offset_y,
                "scale": self.scale,
                "tags": self.tags}
        with open(self.staging_path, 'w', encoding="utf-8") as f:
            json.dump(data, f)
        self.changed = False

    def addLetterbox(self, polygon, edges):
        self.letterboxs += [(polygon, edges)]

    def computeLetterboxs(self, w, h, dim):
        x, y = int(self.offset_x*dim), int(self.offset_y*dim)

        L, T = x>0, y>0
        R, B = x<(dim-w)-1, y<(dim-h)-1

        lx, rx  = x, w-1+x
        ty, by = y, h-1+y
        d = dim - 1

        self.letterboxs = []

        # number of pixels to inset the edge
        s = 1

        #L,R,B,T
        if(L and not T and not B):
            self.addLetterbox([(0,0), (lx,0), (lx, d), (0, d)], [((lx+s,s), (lx+s, d-s))])
        if(R and not T and not B):
            self.addLetterbox([(d,0), (d, d), (rx, d), (rx,0)], [((rx-s,s), (rx-s, d-s))])
        if(T and not L and not R):
            self.addLetterbox([(0,0), (d,0), (d, ty), (0, ty)], [((s, ty+s), (d-s, ty+s))])
        if(B and not L and not R):
            self.addLetterbox([(0, d), (0,by), (d,by), (d, d)], [((s,by-s), (d-s,by-s))])

        #TL, BL, TR, BR
        if(L and T and not R and not B):
            poly = [(0,0), (d,0), (d, ty), (lx, ty), (lx, d), (0, d)]
            edges = [((lx+s, ty+s), (d-s, ty+s)), ((lx+s, ty+s), (lx+s, d-s))]
            self.addLetterbox(poly, edges)
        if(L and B and not R and not T):
            poly = [(0,0), (lx,0), (lx, by), (d, by), (d, d), (0, d)]
            edges = [((lx+s, s), (lx+s, by-s)), ((lx+s, by-s), (d-s, by-s))]
            self.addLetterbox(poly, edges)
        if(R and T and not L and not B):
            poly = [(0,0), (d,0), (d, d), (rx, d), (rx, ty), (0, ty)]
            edges = [((s, ty+s), (rx-s, ty+s)), ((rx-s, ty+s), (rx-s, d-s))]
            self.addLetterbox(poly, edges)
        if(R and B and not L and not T):
            poly = [(d,0), (d, d), (0, d), (0, by), (rx, by), (rx,0)]
            edges = [((rx-s, s), (rx-s, by-s)), ((rx-s, by-s), (s, by-s))]
            self.addLetterbox(poly, edges)

        #LU, TU, RU, BU
        if(L and T and B and not R):
            poly = [(0,0), (d,0), (d, ty), (lx, ty), (lx, by), (d, by), (d, d), (0, d)]
            edges = [((lx+s, ty+s), (d-s,ty+s)), ((lx+s, ty+s), (lx+s, by-s)), ((lx+s, by-s), (d-s, by-s))]
            self.addLetterbox(poly, edges)
        if(T and L and R and not B):
            poly = [(0,0), (d,0), (d, d), (rx, d), (rx, ty), (lx, ty), (lx, d), (0, d)]
            edges = [((lx+s,d-s), (lx+s,ty+s)), ((lx+s, ty+s), (rx-s, ty+s)), ((rx-s, ty+s), (rx-s, d-s))]
            self.addLetterbox(poly, edges)
        if(R and T and B and not L):
            poly = [(0,0), (d,0), (d, d), (0, d), (0, by), (rx, by), (rx, ty), (0, ty)]
            edges = [((s, ty+s), (rx-s,ty+s)), ((rx-s,ty+s), (rx-s, by-s)), ((rx-s, by-s), (s, by-s))]
            self.addLetterbox(poly, edges)
        if(B and L and R and not T):
            poly = [(0,0), (lx,0), (lx, by), (rx, by), (rx, 0), (d, 0), (d, d), (0, d)]
            edges = [((lx+s,s), (lx+s,by-s)), ((lx+s, by-s), (rx-s, by-s)), ((rx-s, by-s), (rx-s, s))]
            self.addLetterbox(poly, edges)

        #All
        dh = d//2
        if(L and R and T and B):
            poly = [(0,0), (d, 0), (d, d), (dh, d), (dh, by), (rx, by), (rx, ty), (lx, ty), (lx, by), (dh, by), (dh,d), (0,d)]
            edges = [((lx+s, ty+s), (rx-s, ty+s)), ((rx-s, ty+s), (rx-s, by-s)), ((rx-s, by-s), (lx+s, by-s)), ((lx+s, by-s), (lx+s, ty+s))]
            self.addLetterbox(poly, edges)

    def computeEdgeColor(self, crop, center, letterbox):
        _, edges = letterbox
        cx, cy = center

        s = 32
        samples = []

        for i in range(len(edges)):
            a, b = edges[i]
            ax, ay = a
            bx, by = b

            dx, dy = (bx-ax)/s, (by-ay)/s

            for k in range(1,s):
                x, y = int(ax+dx*k), int(ay+dy*k)
                p = crop.getpixel((x,y))
                samples += [p]

        c = (0,0,0)
        for d in samples:
            c = (c[0]+d[0], c[1]+d[1], c[2]+d[2])
        l = len(samples)
        color = (int(c[0]//l),int(c[1]//l),int(c[2]//l))
        var = statistics.variance([sum(d)//3 for d in samples])

        return color, var

    def doCrop(self, dim):
        if self.cache:
            img = self.cache.fetch(self.source)
        else:
            img = Image.open(self.source).convert('RGB')

        self.w, self.h = img.size[0], img.size[1]
        x, y, w, h = positionContain(img.size[0], img.size[1], dim) 

        s = (w/img.size[0]) * self.scale

        img = img.resize((int(round(img.size[0] * s)),int(round(img.size[1] * s))))

        self.computeLetterboxs(img.size[0], img.size[1], dim)

        crop = Image.new(mode='RGB',size=(dim,dim))
        crop.paste(img, (int(self.offset_x*dim), int(self.offset_y*dim)))
        draw = ImageDraw.Draw(crop)  

        center = (self.offset_x*dim + img.size[0]//2, self.offset_y*dim + img.size[1]//2)

        for letterbox in self.letterboxs:
            color, var = self.computeEdgeColor(crop, center, letterbox)
            if var < 200:
                polygon, _ = letterbox
                draw.polygon(polygon, fill=color)

        #crop.paste(img, (int(self.offset_x*dim), int(self.offset_y*dim)))

        return crop

    def getTags(self):
        if self.globals:
            return self.globals.composite(self.tags).copy()
        else:
            return self.tags.copy()

    def buildPrompt(self):
        return tags_to_prompt(self.getTags())

    def writeCrop(self, crop_file, dim):
        if not self.ready:
            self.center()

        crop = self.doCrop(dim)

        if crop_file.endswith(".jpg"):
            crop.save(crop_file, quality=95)
        else:
            crop.save(crop_file)

    def writeScale(self, scale_file, dim):
        if self.cache:
            img = self.cache.fetch(self.source)
        else:
            img = Image.open(self.source).convert('RGB')
        self.w, self.h = img.size[0], img.size[1]

        s = dim/min(self.w, self.h)
        if self.w > self.h:
            w = self.w * s
            h = dim
        else:
            w = dim
            h = self.h * s

        img = img.resize((int(w),int(h)))

        if scale_file.endswith(".jpg"):
            img.save(scale_file, quality=95)
        else:
            img.save(scale_file)

    def writeOriginal(self, out_file):
        in_ext = os.path.splitext(self.source)[1]
        out_ext = os.path.splitext(out_file)[1]

        if in_ext == out_ext:
            shutil.copyfile(self.source, out_file)
            return
        
        if self.cache:
            img = self.cache.fetch(self.source)
        else:
            img = Image.open(self.source).convert('RGB')
        self.w, self.h = img.size[0], img.size[1]

        if out_file.endswith(".jpg"):
            img.save(out_file, quality=95)
        else:
            img.save(out_file)
    
    def writePrompt(self, prompt_file):
        with open(prompt_file, "w", encoding="utf-8") as f:
            f.write(self.buildPrompt())
        
    def writePromptJson(self, prompt_file):
        tags = []
        if self.globals:
            tags = self.globals.composite(self.tags)
        else:
            tags = self.tags

        put_json({"tags": tags}, prompt_file)

    def setCrop(self, x, y, s):
        if(self.ready and x == self.offset_x and y == self.offset_y and s == self.scale):
            return
        self.offset_x = x
        self.offset_y = y
        self.scale = s

        if self.ready:
            self.changed = True
        else:
            self.ready = True

    def addTag(self, tag, prefix=False):
        if not tag in self.tags:
            if prefix:
                self.tags.insert(0, tag)
            else:
                self.tags.append(tag)
            self.changed = True

    def deleteTag(self, idx):
        del self.tags[idx]
        self.changed = True
    
    def moveTag(self, from_idx, to_idx):
        self.tags.insert(to_idx, self.tags.pop(from_idx))
        self.changed = True

    def setTags(self, tags):
        self.tags = tags
        self.changed = True

    def reset(self):
        if not self.readStagingData():
            self.center()
        self.changed = False
    
    def fullReset(self):
        self.tags = get_metadata(self.source)
        self.prepare()
        self.writeStagingData()
        self.changed = False

    def prepare(self):
        self.center()
        

class PreviewProviderSignals(QObject):
    updated = pyqtSignal()

class PreviewProvider(QQuickImageProvider):
    def __init__(self):
        super(PreviewProvider, self).__init__(QQuickImageProvider.Image)
        self.preview = None
        self.source = None
        self.dim = 0
        self.count = 0
        self.last = None
        self.signals = PreviewProviderSignals()
    
    def setSource(self, source, dim):
        self.source = source
        self.dim = dim

    def requestImage(self, p_str, size):
        if p_str != self.last:
            img = self.source.doCrop(self.dim)
            self.preview = ImageQt.ImageQt(img)
            self.last = p_str
            
            self.signals.updated.emit()

        return self.preview, self.preview.size()

class Globals():
    def __init__(self, config):
        self.config_path = config
        self.tags = [ELLIPSIS]
        self.changed = False

        self.readStagingData()

    def composite(self, input):
        i = self.tags.index(ELLIPSIS)
        a, b = self.tags[:i], self.tags[i+1:]
        a = [t for t in a if not t in input]
        b = [t for t in b if not t in input]
        output = a + input + b
        return output
    
    def addTag(self, tag, prefix=False):
        if not tag in self.tags:
            if prefix:
                self.tags.insert(0, tag)
            else:
                self.tags.append(tag)
            self.changed = True

    def deleteTag(self, idx):
        del self.tags[idx]
        self.changed = True
    
    def moveTag(self, from_idx, to_idx):
        self.tags.insert(to_idx, self.tags.pop(from_idx))
        self.changed = True
    
    def buildPrompt(self):
        return tags_to_prompt(self.tags)

    def writeStagingData(self):
        data = {"global": self.tags}
        put_json(data, self.config_path)
        self.changed = False
    
    def readStagingData(self):
        self.tags = [ELLIPSIS]
        if not os.path.isfile(self.config_path):
            return
        cfg = get_json(self.config_path)
        if "global" in cfg:
            self.tags = cfg["global"]

class Backend(QObject):
    updated = pyqtSignal()
    changedUpdated = pyqtSignal()
    tagsUpdated = pyqtSignal()
    imageUpdated = pyqtSignal()
    searchUpdated = pyqtSignal()
    favUpdated = pyqtSignal()
    suggestionsUpdated = pyqtSignal()
    previewUpdated = pyqtSignal()

    listEvent = pyqtSignal(int)

    cropWorkerUpdated = pyqtSignal()
    cropWorkerSetup = pyqtSignal(int,int,int,int)
    cropWorkerStart = pyqtSignal()
    cropWorkerStop = pyqtSignal()

    ddbWorkerUpdated = pyqtSignal()
    ddbWorkerInterrogate = pyqtSignal('QString', bool, float, float, float)

    def __init__(self, in_folder, tags_file, webui_folder, parent=None):
        super().__init__(parent)
        self.cache = Cache(8)

        # crop worker & state
        self.cropThread = QThread(self)
        self.cropWorker = None

        self.setInputFolder(in_folder, True)

        self.webui_folder = webui_folder
        
        # general state
        self.isShowingGlobal = False
        self.isPrefixingTags = False

        # global tag list
        self.tags_file = tags_file
        tags = get_tags_from_csv(tags_file)
        self.tagLookup = {}
        for t in tags:
            self.tagLookup[t[0]] = t[1]
        self.tagIndex = [t[0] for t in tags]

        # GUI state
        self.isShowingTagColors = False
        self.currentSearch = ""
        self.searchResults = []
        self.listIndex = 0
        self.imgIndex = -1
        self.current = None
        self.fav = []
        self.freq = {}
        self.isShowingFrequent = True
        self.previewProvider = PreviewProvider()
        self.previewProvider.signals.updated.connect(self.previewCallback)
        self.previewCount = 0
        self.previewPrompt = ""
        self.previewVisible = False
        self.cycleDelta = None
        self.setActive(0)

        # GUI init
        self.search("")        
        self.loadConfig()
        self.saveConfig()

        # ddb worker & state
        self.ddbWorker = DDBWorker()
        self.ddbCurrent = -1
        self.ddbLoading = True
        self.ddbAll = False
        self.ddbAdd = False
        self.ddbActive = self.webui_folder != None
        self.ddbThread = None
        if self.ddbActive:
            self.ddbInit()

        # clean up ddb thread
        parent.aboutToQuit.connect(self.closing)

    def load(self):
        self.in_config = os.path.join(self.in_folder, CONFIG)
        in_cfg = get_json(self.in_config)

        self.out_folder = None
        self.staging_folder = None
        self.dim = None

        if "output" in in_cfg:
            self.out_folder = in_cfg["output"]
        if "staging" in in_cfg:
            self.staging_folder = in_cfg["staging"]
        if "dimension" in in_cfg:
            self.dim = in_cfg["dimension"]
        
        if not self.out_folder:
            self.out_folder = os.path.join(self.in_folder, "output")
        if not self.staging_folder:
            self.staging_folder = os.path.join(self.in_folder, "staging")
        if not self.dim:
            self.dim = 1024

        if not os.path.exists(self.out_folder):
            os.makedirs(self.out_folder)
        if not os.path.exists(self.staging_folder):
            os.makedirs(self.staging_folder)

        self.globals = Globals(self.in_config)
        self.images = get_images(self.in_folder, self.staging_folder)
        print(f"STATUS: loaded {len(self.images)} images, {len([i for i in self.images if i.tags])} have tags")
        if len(self.images) == 0:
            print(f"ERROR: no images found!")
            exit(1)

        for i in self.images:
            i.cache = self.cache
            i.globals = self.globals

        self.buildCropWorker()

    def setInputFolder(self, folder, fresh):
        if not folder:
            if fresh:
                cfg = get_json(CONFIG)
                if "input" in cfg:
                    folder = cfg["input"]
            if not folder:
                folder = str(QFileDialog.getExistingDirectory(None, "Select Input Folder"))
        if not folder:
            return False

        self.in_folder = folder
        self.load()

        return True

    def buildCropWorker(self):
        if self.cropWorker:
            self.cropWorkerStop.emit()
            while self.cropWorker.pool.activeThreadCount() > 0:
                time.sleep(0.01)
            self.cropWorker.deleteLater()

        self.cropWorker = CropWorker(self.images, self.out_folder, self.dim)
        self.cropWorkerActive = False
        self.cropWorkerProgress = 0.0
        self.cropWorkerStatus = ""
        self.cropInit()

    ### Properties

    @pyqtProperty(int, constant=True)
    def total(self):
        return len(self.images)

    @pyqtProperty(int, notify=updated)
    def active(self):
        return self.imgIndex
    
    @active.setter
    def active(self, a):
        self.setActive(a % len(self.images))
    
    def setActive(self, a):
        if self.isShowingGlobal:
            return

        self.imgIndex = a
        self.current = self.images[self.imgIndex]

        # setting the default crop state is expensive
        # (requires loading the image)
        # so only do it on demand
        if not self.current.ready:
            self.current.prepare()
            self.current.writeStagingData()
        
        self.setPreview()

        if not self.current.ddb:
            self.isShowingFrequent = True

        self.doUpdate()
        
    def doUpdate(self):
        self.changedUpdated.emit()
        self.imageUpdated.emit()
        self.tagsUpdated.emit()
        self.suggestionsUpdated.emit()
        self.previewUpdated.emit()
        self.updated.emit()

    @pyqtProperty('QString', notify=updated)
    def source(self):
        if self.isShowingGlobal:
            return "qrc:/icons/globe.png"
        return "file:///" + self.current.source
    
    @pyqtProperty(bool, notify=changedUpdated)
    def changed(self):
        return self.current.changed
    
    @pyqtProperty(float, notify=imageUpdated)
    def offset_x(self):
        if self.isShowingGlobal:
            return 0
        return self.current.offset_x
    
    @pyqtProperty(float, notify=imageUpdated)
    def offset_y(self):
        if self.isShowingGlobal:
            return 0
        return self.current.offset_y
    
    @pyqtProperty(float, notify=imageUpdated)
    def scale(self):
        if self.isShowingGlobal:
            return 1
        return self.current.scale

    @pyqtProperty(int, notify=updated)
    def dimension(self):
        return self.dim

    @pyqtProperty('QString', notify=previewUpdated)
    def preview(self):
        if self.isShowingGlobal:
            return "qrc:/icons/globe.png"
        return f"image://preview/{self.previewCount}.png"
    
    @pyqtProperty('QString', notify=tagsUpdated)
    def prompt(self):
        return self.current.buildPrompt()
    
    @pyqtProperty(list, notify=tagsUpdated)
    def tags(self):
        return self.current.tags
    
    @pyqtProperty(list, notify=searchUpdated)
    def results(self):
        return self.searchResults
    
    @pyqtProperty('QString', notify=cropWorkerUpdated)
    def cropStatus(self):
        return self.cropWorkerStatus
    
    @pyqtProperty(float, notify=cropWorkerUpdated)
    def cropProgress(self):
        return self.cropWorkerProgress
    
    @pyqtProperty(bool, notify=cropWorkerUpdated)
    def cropActive(self):
        return self.cropWorkerActive
    
    @pyqtProperty('QString', notify=updated)
    def title(self):
        if self.isShowingGlobal:
            return "Tagging Global"
        return f"Tagging {self.imgIndex+1} of {len(self.images)}"
    
    @pyqtProperty(list, notify=favUpdated)
    def favourites(self):
        return self.fav
    
    @pyqtProperty(list, notify=suggestionsUpdated)
    def frequent(self):
        f = [(k, self.freq[k]) for k in self.freq]
        f.sort(key=lambda a:a[1], reverse=True)
        return [t[0] for t in f]
    
    @pyqtProperty(list, notify=suggestionsUpdated)
    def ddb(self):
        if self.isShowingGlobal:
            return []
        return self.current.ddb
    
    @pyqtProperty(int, notify=suggestionsUpdated)
    def ddbStatus(self):
        # -2  - no webui folder set
        # -1  - not loaded
        # 0   - idle
        # 1   - processing single image
        # >=2 - processing multiple images

        if not self.ddbActive:
            return -2
        if self.ddbLoading:
            return -1
        if self.ddbCurrent == -1:
            return 0
        if self.ddbAll:
            return 2+self.ddbCurrent
        return 1
    
    @pyqtProperty(bool, notify=suggestionsUpdated)
    def showingFrequent(self):
        return self.isShowingFrequent

    @pyqtProperty(bool, notify=updated)
    def showingTagColors(self):
        return self.isShowingTagColors

    @pyqtProperty(int, notify=listEvent)
    def activeList(self):
        return self.listIndex

    @pyqtProperty(int, notify=updated)
    def maxThreads(self):
        try:
            n_threads = len(os.sched_getaffinity(0))
        except AttributeError:
            n_threads = os.cpu_count()
        return n_threads

    @pyqtProperty(list, notify=previewUpdated)
    def letterboxs(self):
        if self.isShowingGlobal:
            return []
        
        out = []
        for p, e in self.current.letterboxs:
            p = [QPointF(*v) for v in p]
            e = [[QPointF(*v) for v in edge] for edge in e]
            out += [[p,e]]
        return out

    @pyqtProperty(bool, notify=updated)
    def showingGlobal(self):
        return self.isShowingGlobal

    @pyqtProperty(bool, notify=updated)
    def ddbIsAdding(self):
        return self.ddbAdd

    @pyqtProperty(bool, notify=updated)
    def prefixingTags(self):
        return self.isPrefixingTags

    ### Slots

    @pyqtSlot('QString')
    def addTag(self, tag):
        if tag in self.current.tags:
            return
        self.current.addTag(tag, self.isPrefixingTags)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

        if not tag in self.freq:
            self.freq[tag] = 0
        self.freq[tag] += 1
        self.saveConfig()

        self.suggestionsUpdated.emit()

    @pyqtSlot(int)
    def deleteTag(self, idx):
        if idx < 0 or idx >= len(self.current.tags):
            return
        self.current.deleteTag(idx)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot('QString')
    def deleteTagByName(self, tag):
        idx = self.current.tags.index(tag)
        if idx < 0:
            return
        self.current.deleteTag(idx)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
    

    @pyqtSlot(int, int)
    def moveTag(self, from_idx, to_idx):
        self.current.moveTag(from_idx, to_idx)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot(int,int,int,int,int,int)
    def applyCrop(self, fx, fy, fw, fh, cw, ch):
        if self.isShowingGlobal:
            return

        x, y, w, h = positionContain(fw, fh, cw)
        self.current.setCrop(fx/cw, fy/cw, fw/w)

        self.setPreview()

        self.imageUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot()
    def saveStagingData(self):
        self.current.writeStagingData()
        self.changedUpdated.emit()

    @pyqtSlot()
    def contain(self):
        if self.isShowingGlobal:
            return
        self.current.contain()
        self.imageUpdated.emit()
        self.changedUpdated.emit()
    
    @pyqtSlot()
    def center(self):
        if self.isShowingGlobal:
            return
        self.current.center()
        self.imageUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot()
    def writeDebugCrop(self):
        if self.isShowingGlobal:
            return
        self.current.writeCrop("out.png", self.dim)

    @pyqtSlot()
    def reset(self):
        self.current.reset()
        self.tagsUpdated.emit()
        self.imageUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot('QString')
    def search(self, s):
        if not s:
            self.currentSearch = s
            if len(self.tagIndex) > MX_TAGS:
                self.searchResults = self.tagIndex[0:MX_TAGS]
            else:
                self.searchResults = self.tagIndex
        else:
            s = s.replace(" ", "_")
            self.currentSearch = s
            results = []
            for t in self.tagIndex:
                if s in t:
                    results += [t]
                if len(results) > MX_TAGS:
                    break

            self.searchResults = results
        self.searchUpdated.emit()

    @pyqtSlot('QString', result=bool)
    def tagExists(self, tag):
        return tag in self.tagLookup

    @pyqtSlot('QString', result=int)
    def tagType(self, tag):
        if tag in self.tagLookup:
            return self.tagLookup[tag]
        return 2
    
    @pyqtSlot()
    def toggleTagColors(self):
        self.isShowingTagColors = not self.isShowingTagColors
        self.updated.emit()
        self.saveConfig()

    @pyqtSlot(int, int, int, int)
    def package(self, img_mode, ext_mode, prompt_mode, thread_count):
        self.cropWorkerActive = True
        self.cropThread.start()
        self.cropWorkerSetup.emit(img_mode, ext_mode, prompt_mode, thread_count)
        self.cropWorkerStart.emit()
        self.cropWorkerUpdated.emit()
    
    @pyqtSlot()
    def stopPackage(self):
        self.cropWorkerStop.emit()

    @pyqtSlot()
    def cleanTags(self):
        if self.isShowingGlobal:
            return
        tags = [t for t in self.current.tags if t in self.tagLookup]
        self.current.setTags(tags)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot()
    def sortTags(self):
        if self.isShowingGlobal:
            return
        tags = [t for t in self.tagIndex if t in self.current.tags]
        tags += [t for t in self.current.tags if not t in tags]
        self.current.setTags(tags)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot()
    def fullReset(self):
        if self.isShowingGlobal:
            return
        self.current.fullReset()
        self.imageUpdated.emit()
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot('QString')
    def addFavourite(self, tag):
        self.fav += [tag]
        self.favUpdated.emit()
        self.saveConfig()

    @pyqtSlot('QString')
    def toggleFavourite(self, tag):
        if tag in self.fav:
            del self.fav[self.fav.index(tag)]
        else:
            self.fav += [tag]
        self.favUpdated.emit()
        self.saveConfig()

    @pyqtSlot(int)
    def deleteFavourite(self, idx):
        del self.fav[idx]
        self.favUpdated.emit()
        self.saveConfig()

    @pyqtSlot(int, int)
    def moveFavourite(self, from_idx, to_idx):
        self.fav.insert(to_idx, self.fav.pop(from_idx))
        self.favUpdated.emit()
        self.saveConfig()

    @pyqtSlot()
    def ddbInterrogate(self):
        if self.isShowingGlobal:
            return

        if not self.ddbActive:
            self.webui_folder = str(QFileDialog.getExistingDirectory(None, "Select WebUI Folder"))
            if not self.webui_folder:
                return
            self.ddbActive = True
            self.ddbInit()
            self.suggestionsUpdated.emit()
            self.saveConfig()
            return
        
        if self.ddbLoading:
            return

        if self.current.ddb:
            self.isShowingFrequent = False

        if self.ddbCurrent == -1:
            self.ddbCurrent = self.imgIndex
            im = self.current
            self.ddbWorkerInterrogate.emit(im.source, im.ready, im.offset_x, im.offset_y, im.scale)
        
        self.suggestionsUpdated.emit()
    
    def ddbInterrogateNext(self):
        self.ddbCurrent += 1
        if self.ddbCurrent >= len(self.images):
            self.ddbAll = False
            self.ddbCurrent = -1
            self.suggestionsUpdated.emit()
            return
        
        im = self.images[self.ddbCurrent]
        if im.ready:
            self.ddbWorkerInterrogate.emit(im.source, im.ready, im.offset_x, im.offset_y, im.scale)
        else:
            self.ddbWorkerInterrogate.emit(im.source, im.ready, 0.0, 0.0, 0.0)
        self.suggestionsUpdated.emit()

    @pyqtSlot()
    def ddbInterrogateAll(self):
        if not self.ddbActive:
            return
        if self.ddbLoading:
            return
        if self.ddbCurrent == -1:
            self.ddbAll = True
            self.ddbInterrogateNext()

    @pyqtSlot(bool)
    def ddbSetAdding(self, adding):
        self.ddbAdd = adding
        self.updated.emit()

    @pyqtSlot()
    def showFrequent(self):
        self.isShowingFrequent = True
        self.suggestionsUpdated.emit()

    @pyqtSlot()
    def showDDB(self):
        self.isShowingFrequent = False
        self.suggestionsUpdated.emit()

    @pyqtSlot()
    def copy(self):
        prompt = self.current.buildPrompt()
        QApplication.clipboard().setText(prompt)

    @pyqtSlot(bool)
    def paste(self, override):
        prompt = QApplication.clipboard().text()
        tags = extract_tags(prompt)
        
        real_tags = any([t in self.tagLookup for t in tags])
        if not real_tags:
            return

        if override:
            self.current.tags = []
        
        for t in tags:
            if not t in self.current.tags:
                self.current.addTag(t)
        
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot(int)
    def doListEvent(self, event):
        # events
        # -2 - cycle reverse
        # -1 - up 
        # 0  - enter
        # 1  - down
        # 2  - cycle forward
        # 3  - reject (empty list)

        if(event == 3): #reject in the same direct we were cycling
            event = 2 if self.cycleDelta == 1 else -2
        if(event == 2):
            self.cycleDelta = 1
            self.listIndex = (self.listIndex + 1)%6
        if(event == -2):
            self.cycleDelta = -1
            self.listIndex = (self.listIndex + 5)%6
            event = 2 # in the GUI, event 2 is any cycle direction

        self.listEvent.emit(event)
    
    @pyqtSlot(int)
    def changeList(self, index):
        self.listIndex = index
        self.listEvent.emit(2)
    
    @pyqtSlot('QString')
    def addCustomTag(self, tag):
        if tag in self.tagLookup:
            return
        self.tagLookup[tag] = 6
        self.tagIndex += [tag]
        put_tag_in_csv(self.tags_file, tag)

        self.tagsUpdated.emit()
        self.search(self.currentSearch)
    
    @pyqtSlot()
    def toggleGlobal(self):
        self.isShowingGlobal = not self.isShowingGlobal

        if self.isShowingGlobal:
            self.current = self.globals
            self.doUpdate()
        else:
            self.globals.writeStagingData()
            self.setActive(self.imgIndex)
            self.doUpdate()
        
    @pyqtSlot(bool)
    def setPrefixingTags(self, prefixing):
        self.isPrefixingTags = prefixing
        self.updated.emit()
        self.saveConfig()

    @pyqtSlot()
    def openOutputFolder(self):
        QDesktopServices.openUrl(QUrl(f"file:///{self.out_folder}"))

    @pyqtSlot()
    def doLoad(self):
        if not self.setInputFolder("", False):
            return
        self.setActive(0)
        self.saveConfig()

    @pyqtSlot()
    def setStagingFolder(self):
        folder = str(QFileDialog.getExistingDirectory(None, "Select Staging Folder"))
        if not folder:
            return
        
        self.staging_folder = folder
        self.saveConfig()
        self.setInputFolder(self.in_folder, False)
        self.setActive(0)
    
    @pyqtSlot()
    def setOutputFolder(self):
        folder = str(QFileDialog.getExistingDirectory(None, "Select Output Folder"))
        if not folder:
            return
        
        self.out_folder = folder
        self.saveConfig()

        self.buildCropWorker()


    @pyqtSlot(int)
    def setDimension(self, dim):
        if dim <= 0 or dim%32 != 0:
            return
        self.dim = dim 
        self.updated.emit()
        self.saveConfig()

        self.setPreview()
        self.previewUpdated.emit()

        self.buildCropWorker()

    @pyqtSlot()
    def openProjectPage(self):
        QDesktopServices.openUrl(QUrl("https://github.com/arenatemp/sd-tagging-helper/"))
    
    @pyqtSlot()
    def update(self):
        subprocess.run(["git", "pull"])
        print("INFO: restart program to see changes")

    ## Callbacks

    @pyqtSlot(float, 'QString')
    def cropProgressCallback(self, progress, status):
        self.cropWorkerProgress = progress
        self.cropWorkerStatus = status

        if self.cropWorkerProgress < 0:
            self.cropWorkerActive = False
            self.cropWorkerProgress = 0.0

        self.cropWorkerUpdated.emit()

    @pyqtSlot()
    def ddbLoadedCallback(self):
        self.ddbLoading = False
        self.suggestionsUpdated.emit()

    @pyqtSlot(list)
    def ddbResultCallback(self, tags):
        img = self.images[self.ddbCurrent]
        img.ddb = tags

        if self.ddbAdd:
            for t in tags:
                img.addTag(t)
            img.writeStagingData()
            if self.ddbCurrent == self.active:
                self.tagsUpdated.emit()

        if self.ddbCurrent == self.imgIndex:
            self.isShowingFrequent = False

        if self.ddbAll:
            self.ddbInterrogateNext()
        else:
            self.ddbCurrent = -1
            self.suggestionsUpdated.emit()
    
    @pyqtSlot()
    def closing(self):
        if self.cropThread:
            print("waiting for Worker...")
            self.cropWorkerStop.emit() #ask nicely for the worker to stop
            while self.cropWorker.pool.activeThreadCount() > 0:
                time.sleep(0.01)
            self.cropThread.quit()
            self.cropThread.wait()
        if self.ddbThread:
            print("waiting for DeepDanbooru...")
            self.ddbThread.quit()
            self.ddbThread.wait()

    @pyqtSlot()
    def previewCallback(self):
        self.previewUpdated.emit()

    ### Misc
    
    def setPreview(self):
        self.previewProvider.setSource(self.current, self.dim)
        self.previewCount += 1

    def cropInit(self):
        self.cropWorker.progressCallback.connect(self.cropProgressCallback)
        self.cropWorkerSetup.connect(self.cropWorker.setup)
        self.cropWorkerStart.connect(self.cropWorker.start)
        self.cropWorkerStop.connect(self.cropWorker.stop)
        self.cropWorker.moveToThread(self.cropThread)

    def ddbInit(self):
        self.ddbWorker.add_import_paths(self.webui_folder)
        self.ddbThread = QThread(self)
        self.ddbWorker.resultCallback.connect(self.ddbResultCallback)
        self.ddbWorker.loadedCallback.connect(self.ddbLoadedCallback)
        self.ddbWorkerInterrogate.connect(self.ddbWorker.interrogate)
        self.ddbWorker.moveToThread(self.ddbThread)
        self.ddbThread.started.connect(self.ddbWorker.load)
        self.ddbThread.start()

    def loadConfig(self):
        j = get_json(CONFIG)
        if 'fav' in j:
            self.fav = j["fav"]
        if 'freq' in j:
            self.freq = j["freq"]
        if 'webui' in j and self.webui_folder == None:
            self.webui_folder = j["webui"]
        if 'colors' in j:
            self.isShowingTagColors = j["colors"]
        if 'prefixing' in j:
            self.isPrefixingTags = j['prefixing']

    def saveConfig(self):
        put_json({"fav": self.fav, "freq": self.freq, "webui": self.webui_folder,
                  "colors": self.isShowingTagColors, "prefixing": self.isPrefixingTags, "input": self.in_folder}, CONFIG)
        put_json({"output": self.out_folder, "staging": self.staging_folder, "dimension": self.dim}, self.in_config)

def start():
    parser = argparse.ArgumentParser(description='manual image tag/cropping helper GUI')
    parser.add_argument('--input', type=str, help='folder to load images with optional associated tag file (eg: img.png, img.png.txt)')
    parser.add_argument('--tags', type=str, help='optional tag index file. defaults to danbooru tags')
    parser.add_argument('--webui', type=str, help='optional path to stable-diffusion-webui. enables the use of deepdanbooru')
    args = parser.parse_args()

    in_folder = args.input
    tags_file = args.tags
    webui_folder = args.webui
    
    if webui_folder and not os.path.isdir(webui_folder):
        print(f"ERROR: webui folder '{webui_folder}' does not exist!")
        exit(1)
    if webui_folder:
        webui_folder = os.path.abspath(webui_folder)

    if not tags_file:
        tags_file = os.path.join(os.path.abspath(os.path.dirname(__file__)), "danbooru.csv")
    if not os.path.isfile(tags_file):
        print(f"ERROR: tags file '{tags_file}' does not exist!")
        exit(1)

    QCoreApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    QCoreApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)

    class Application(QApplication):
        def event(self, e):
            return QApplication.event(self, e)

    app = Application(sys.argv)
    signal.signal(signal.SIGINT, lambda *a: app.quit())
    app.startTimer(100)

    # spin up the GUI
    backend = Backend(in_folder, tags_file, webui_folder, parent=app)

    engine = QQmlApplicationEngine()
    engine.addImageProvider("preview", backend.previewProvider)
    engine.quit.connect(app.quit)
    ctx = engine.rootContext()
    ctx.setContextProperty("backend", backend)

    engine.load(QUrl('qrc:/Main.qml'))

    sys.exit(app.exec())

def excepthook(exc_type, exc_value, exc_tb):
    tb = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    with open("crash.log", "a") as f:
        f.write(f"{datetime.datetime.now()}\n{tb}\n")
    print(tb)
    print("TRACEBACK SAVED: crash.log")
    QApplication.quit()

if __name__ == "__main__":
    sys.excepthook = excepthook
    start()
    
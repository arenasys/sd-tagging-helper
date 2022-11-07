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
import operator
#import requests
import signal

from PIL import Image, ImageDraw, ImageQt
from PyQt5.QtCore import pyqtProperty, pyqtSignal, pyqtSlot, QObject, QUrl, QThread, QCoreApplication, Qt, QRunnable, QThreadPool
from PyQt5.QtQml import QQmlApplicationEngine
from PyQt5.QtWidgets import QFileDialog, QApplication
from PyQt5.QtQuick import QQuickImageProvider

import qml_rc

CONFIG = "config.json"
EXT = [".png", ".jpg", ".jpeg", ".webp"]
MX_TAGS = 30
SMILES = ["0_0","(o)_(o)","+_+","+_-","._.","<o>_<o>","<|>_<|>","=_=",">_<","3_3","6_9",">_o","@_@","^_^","o_o","u_u","x_x","|_|","||_||"]

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
        m = os.path.join(staging_path, os.path.basename(f) + ".json")

        img = Img(f, m)
        img.readStagingData()
        if not img.ready:
            img.tags = get_metadata(f)
        images += [img]

    return images

def positionCenter(w, h, d):
    if w > h:
        w,h = d, (h/w)*d
    else:
        w,h = (w/h)*d, d
    x = int((d-w)/2)
    y = int((d-h)/2)
    return x, y, w, h

def positionFill(w, h, d):
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
    #prompt = re.sub(r'\([^)]*\)', '', prompt)
    return prompt

def get_edge_colors(img, vertical, inset=0.00, samples=32):
    a = (0,0,0)
    b = (0,0,0)

    inset = 2

    a_s = []
    b_s = []

    if vertical:
        for y in range(inset, img.size[1], img.size[1]//(samples-1)):
            a_s += [img.getpixel((inset,y))]
            b_s += [img.getpixel((img.size[0]-1-inset,y))]
    else:
        for x in range(inset, img.size[0], img.size[0]//(samples-1)):
            a_s += [img.getpixel((x,inset))]
            b_s += [img.getpixel((x,img.size[1]-1-inset))]

    a_v = statistics.variance([sum(i)//3 for i in a_s])
    b_v = statistics.variance([sum(i)//3 for i in b_s])

    a_t = (0,0,0)
    b_t = (0,0,0)
    for i in a_s:
        a_t = tuple(map(operator.add, a_t, i))
    for i in b_s:
        b_t = tuple(map(operator.add, b_t, i))
    
    l = len(a_s)

    a_t = tuple(map(operator.floordiv, a_t, (l,l,l)))
    b_t = tuple(map(operator.floordiv, b_t, (l,l,l)))

    a_t = (int(a_t[0]),int(a_t[1]),int(a_t[2]))
    b_t = (int(b_t[0]),int(b_t[1]),int(b_t[2]))


    return a_t, b_t, a_v, b_v

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

#def download(url, filename):
#    resp = requests.get(url, stream=True)
#    total = int(resp.headers.get('content-length', 0))
#
#    with open(filename, 'wb') as file, tqdm(
#        desc=filename,
#        total=total,
#        unit='iB',
#        unit_scale=True,
#        unit_divisor=1024,
#    ) as bar:
#        for data in resp.iter_content(chunk_size=1024):
#            size = file.write(data)
#            bar.update(size)

class DDBWorker(QObject):
    resultCallback = pyqtSignal(list)
    loadedCallback = pyqtSignal()

    def __init__(self,  parent=None):
        super().__init__(parent)
        self.image = None

    def add_import_paths(self, webui_folder):
        self.webui_folder = webui_folder
        self.deep_folder = os.path.join(self.webui_folder, 'models', 'deepbooru')

        sys.path.insert(0, self.webui_folder)
        sys.path.insert(0, self.deep_folder)

        venv_folder = os.path.join(self.webui_folder, 'venv', 'lib', '*')

        for venv_path in glob.glob(venv_folder, recursive = True):
            if not venv_path.endswith("site-packages"):
                venv_path = os.path.join(venv_path, "site-packages")

            if os.path.isdir(venv_path):
                sys.path.insert(0, venv_path)


    @pyqtSlot()
    def load(self):
        import deepdanbooru as dd
        import tensorflow as tf
        import numpy as np
        model_path = os.path.abspath(self.deep_folder)
        self.tags = dd.project.load_tags_from_project(model_path)
        self.model = dd.project.load_model_from_project(model_path, compile_model=False)
        self.loadedCallback.emit()

    @pyqtSlot(int, 'QString', bool, float, float, float)
    def interrogate(self, size, file, ready, x, y, s):
        import deepdanbooru as dd
        import tensorflow as tf
        import numpy as np

        img = Img(file, "")
        if ready:
            img.setCrop(x,y,s)
        else:
            img.prepare()
        
        image = img.doCrop(size)

        width = self.model.input_shape[2]
        height = self.model.input_shape[1]
        image = np.array(image)
        image = tf.image.resize(
            image,
            size=(height, width),
            method=tf.image.ResizeMethod.AREA,
            preserve_aspect_ratio=True,
        )
        image = image.numpy()  # EagerTensor to np.array
        image = dd.image.transform_and_pad_image(image, width, height)
        image = image / 255.0
        image_shape = image.shape
        image = image.reshape((1, image_shape[0], image_shape[1], image_shape[2]))

        v = self.model.predict(image)[0]

        outputs = []

        for i, tag in enumerate(self.tags):
            outputs += [(tag, v[i])]
        outputs.sort(key=lambda a: a[1], reverse=True)        
        
        if len(outputs) > 100:
            outputs = outputs[:100]

        self.resultCallback.emit([t[0] for t in outputs])

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
            tags = self.img.tags.copy()
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


class Img:
    def __init__(self, image_path, staging_path):
        self.source = image_path
        self.staging_path = staging_path
        self.ready = False # ready to be displayed (needs crop offsets/scale)
        self.changed = False
        self.ddb = []
        self.w, self.h = None, None
        self.offset_x, self.offset_y, self.scale = None, None, None

    def center(self):
        if not self.w or not self.h:
            with Image.open(self.source) as img:
                self.w, self.h = img.size
        x, y, w, h = positionCenter(self.w, self.h, 1024)
        self.setCrop(x/1024, y/1024, 1.0)

    def fill(self):
        if not self.w or not self.h:
            with Image.open(self.source) as img:
                self.w, self.h = img.size
        x, y, w, h = positionFill(self.w, self.h, 1024)
        _, _, w2, _ = positionCenter(self.w, self.h, 1024)
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

    def doCrop(self, dim):
        img = Image.open(self.source).convert('RGB')
        self.w, self.h = img.size[0], img.size[1]
        x, y, w, h = positionCenter(img.size[0], img.size[1], dim) 

        s = (w/img.size[0]) * self.scale
        img = img.resize((int(img.size[0] * s),int(img.size[1] * s)))

        L, T = int(self.offset_x*dim)>0, int(self.offset_y*dim)>0
        R, B = int(self.offset_x*dim)<(dim-img.size[0])-1, int(self.offset_y*dim)<(dim-img.size[1])-1

        if L or R:
            LC, RC, LV, RV = get_edge_colors(img, True)
        if T or B:
            TC, BC, TV, BV = get_edge_colors(img, False)        

        crop = Image.new(mode='RGB',size=(dim,dim))
        crop.paste(img, (int(self.offset_x*dim), int(self.offset_y*dim)))

        if(L and not B and not T and LV < 200):
            ImageDraw.floodfill(crop, (0,0), LC)
        if(R and not B and not T and RV < 200):
            ImageDraw.floodfill(crop, (dim-1,0), RC)
        if(T and not L and not R and TV < 200):
            ImageDraw.floodfill(crop, (0,0), TC)
        if(B and not L and not R and BV < 200):
            ImageDraw.floodfill(crop, (0, dim-1), BC)

        return crop

    def buildPrompt(self):
        return tags_to_prompt(self.tags)

    def writeCrop(self, crop_file, dim):
        if not self.ready:
            self.fill()

        crop = self.doCrop(dim)

        if crop_file.endswith(".jpg"):
            crop.save(crop_file, quality=95)
        else:
            crop.save(crop_file)

    def writeScale(self, scale_file, dim):
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
        put_json({"tags": self.tags}, prompt_file)

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

    def addTag(self, tag):
        self.tags += [tag]
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
            self.fill()
        self.changed = False
    
    def fullReset(self):
        self.tags = get_metadata(self.source)
        self.prepare()
        self.changed = False

    def prepare(self):
        self.center()
        self.writeStagingData()

class PreviewProvider(QQuickImageProvider):
    def __init__(self):
        super(PreviewProvider, self).__init__(QQuickImageProvider.Image)
        self.preview = None
        self.source = None
        self.dim = 1024
        self.count = 0
        self.last = None

    
    def setSource(self, source, dim):
        self.source = source
        self.dim = dim

    def requestImage(self, p_str, size):
        if p_str != self.last:
            img = self.source.doCrop(self.dim)
            self.preview = ImageQt.ImageQt(img)
            self.last = p_str

        return self.preview, self.preview.size()


class Backend(QObject):
    updated = pyqtSignal()
    changedUpdated = pyqtSignal()
    tagsUpdated = pyqtSignal()
    imageUpdated = pyqtSignal()
    searchUpdated = pyqtSignal()
    favUpdated = pyqtSignal()
    suggestionsUpdated = pyqtSignal()

    listEvent = pyqtSignal(int)

    cropWorkerUpdated = pyqtSignal()
    cropWorkerSetup = pyqtSignal(int,int,int,int)
    cropWorkerStart = pyqtSignal()
    cropWorkerStop = pyqtSignal()

    ddbWorkerUpdated = pyqtSignal()
    ddbWorkerInterrogate = pyqtSignal(int, 'QString', bool, float, float, float)

    def __init__(self, images, tags, out_folder, webui_folder, dimension, parent=None):
        super().__init__(parent)

        # general state
        self.images = images
        self.dim = dimension
        self.webui_folder = webui_folder

        # global tag list
        self.tagLookup = {}
        for t in tags:
            self.tagLookup[t[0]] = t[1]
        self.tagIndex = [t[0] for t in tags]

        # GUI state
        self.tagColors = False
        self.searchResults = []
        self.listIndex = 0
        self.imgIndex = -1
        self.current = self.images[self.imgIndex]
        self.fav = []
        self.freq = {}
        self.showFrequent = True
        self.previewProvider = PreviewProvider()
        self.previewCount = 0
        self.previewPrompt = ""
        self.previewVisible = False
        self.cycleDelta = None

        # GUI init
        self.setActive(0)
        self.search("")        
        self.loadConfig()
        self.saveConfig()
        
        # crop worker & state
        self.cropWorker = CropWorker(self.images, out_folder, self.dim)
        self.cropWorkerActive = False
        self.cropWorkerProgress = 0.0
        self.cropWorkerStatus = ""
        self.cropInit()

        # ddb worker & state
        self.ddbWorker = DDBWorker()
        self.ddbCurrent = -1
        self.ddbLoading = True
        self.ddbAll = False
        self.ddbActive = self.webui_folder != None
        self.ddbThread = None
        if self.ddbActive:
            self.ddbInit()

        # clean up ddb thread
        parent.aboutToQuit.connect(self.closing)

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
        if a == self.imgIndex:
            return
        self.imgIndex = a
        self.current = self.images[self.imgIndex]

        # setting the default crop state is expensive
        # (requires loading the image)
        # so only do it on demand
        if not self.current.ready:
            self.current.prepare()
        
        self.setPreview()

        if not self.current.ddb:
            self.showFrequent = True
        
        self.changedUpdated.emit()
        self.imageUpdated.emit()
        self.tagsUpdated.emit()
        self.suggestionsUpdated.emit()
        self.updated.emit()

    @pyqtProperty('QString', notify=updated)
    def source(self):
        return self.current.source
    
    @pyqtProperty(bool, notify=changedUpdated)
    def changed(self):
        return self.current.changed
    
    @pyqtProperty(float, notify=imageUpdated)
    def offset_x(self):
        return self.current.offset_x
    
    @pyqtProperty(float, notify=imageUpdated)
    def offset_y(self):
        return self.current.offset_y
    
    @pyqtProperty(float, notify=imageUpdated)
    def scale(self):
        return self.current.scale

    @pyqtProperty(int, notify=updated)
    def dimension(self):
        return self.dim

    @pyqtProperty('QString', notify=imageUpdated)
    def preview(self):
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
        return self.showFrequent

    @pyqtProperty(bool, notify=updated)
    def showingTagColors(self):
        return self.tagColors

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

    ### Slots

    @pyqtSlot('QString')
    def addTag(self, tag):
        if tag in self.current.tags:
            return
        self.current.addTag(tag)
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

    @pyqtSlot(int, int)
    def moveTag(self, from_idx, to_idx):
        self.current.moveTag(from_idx, to_idx)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot(int,int,int,int,int,int)
    def applyCrop(self, fx, fy, fw, fh, cw, ch):
        x, y, w, h = positionCenter(fw, fh, cw)
        self.current.setCrop(fx/cw, fy/cw, fw/w)

        self.setPreview()

        self.imageUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot()
    def saveStagingData(self):
        self.current.writeStagingData()
        self.changedUpdated.emit()

    @pyqtSlot()
    def center(self):
        self.current.center()
        self.imageUpdated.emit()
        self.changedUpdated.emit()
    
    @pyqtSlot()
    def fill(self):
        self.current.fill()
        self.imageUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot()
    def writeDebugCrop(self):
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
            if len(self.tagIndex) > MX_TAGS:
                self.searchResults = self.tagIndex[0:MX_TAGS]
            else:
                self.searchResults = self.tagIndex
        else:
            s = s.replace(" ", "_")
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
        self.tagColors = not self.tagColors
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
        tags = [t for t in self.current.tags if t in self.tagLookup]
        self.current.setTags(tags)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot()
    def sortTags(self):
        tags = [t for t in self.tagIndex if t in self.current.tags]
        tags += [t for t in self.current.tags if not t in tags]
        self.current.setTags(tags)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot()
    def fullReset(self):
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

        if(self.current.ddb):
            self.showFrequent = False

        if self.ddbCurrent == -1:
            self.ddbCurrent = self.imgIndex
            im = self.current
            self.ddbWorkerInterrogate.emit(self.dim, im.source, im.ready, im.offset_x, im.offset_y, im.scale)
        
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
            self.ddbWorkerInterrogate.emit(self.dim, im.source, im.ready, im.offset_x, im.offset_y, im.scale)
        else:
            self.ddbWorkerInterrogate.emit(self.dim, im.source, im.ready, 0.0, 0.0, 0.0)
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

    @pyqtSlot()
    def showFrequent(self):
        self.showFrequent = True
        self.suggestionsUpdated.emit()

    @pyqtSlot()
    def showDDB(self):
        self.showFrequent = False
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

        if self.ddbCurrent == self.imgIndex:
            self.showFrequent = False

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

    ### Misc
    
    def setPreview(self):
        self.previewProvider.setSource(self.current, self.dim)
        self.previewCount += 1

    def cropInit(self):
        self.cropThread = QThread(self)
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
            self.tagColors = j["colors"]

    def saveConfig(self):
        put_json({"fav": self.fav, "freq": self.freq, "webui": self.webui_folder, "colors": self.tagColors}, CONFIG)


def start():
    parser = argparse.ArgumentParser(description='manual image tag/cropping helper GUI')
    parser.add_argument('--input', type=str, help='folder to load images with optional associated tag file (eg: img.png, img.png.txt)')
    parser.add_argument('--dimension', type=int, help='dimension of output images. defaults to 1024x1024')
    parser.add_argument('--staging', type=str, help='folder to stage changes for each image. defaults to "staging"')
    parser.add_argument('--output', type=str, help='folder to write the packaged images/tags. defaults to "output"')
    parser.add_argument('--tags', type=str, help='optional tag index file. defaults to danbooru tags')
    parser.add_argument('--webui', type=str, help='optional path to stable-diffusion-webui. enables the use of deepdanbooru')
    args = parser.parse_args()

    in_folder = args.input
    dim = args.dimension
    out_folder = args.output
    staging_folder = args.staging
    tags_file = args.tags
    webui_folder = args.webui

    # check all the args, make sure they point to real folders/files, create default folders, etc
    if in_folder and not os.path.isdir(in_folder):
        print(f"ERROR: input folder '{in_folder}' does not exist!")
        exit(1)

    if not out_folder:
        out_folder = "output"
        if not os.path.exists(out_folder):
            os.makedirs(out_folder)
    if not os.path.isdir(out_folder):
        print(f"ERROR: output folder '{out_folder}' does not exist!")
        exit(1)
    out_folder = os.path.abspath(out_folder)

    if not staging_folder:
        staging_folder = "staging"

        #migrate old default folder
        if os.path.exists("metadata") and not os.path.exists("staging"):
            os.rename("metadata", "staging")

        if not os.path.exists(staging_folder):
            os.makedirs(staging_folder)
    if not os.path.isdir(staging_folder):
        print(f"ERROR: staging folder '{staging_folder}' does not exist!")
        exit(1)
    staging_folder = os.path.abspath(staging_folder)
    
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

    if not dim:
        dim = 1024
    if dim % 32 != 0 or dim <= 0:
        print(f"ERROR: dimension of '{dim}' is not valid!")

    QCoreApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    QCoreApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)

    class Application(QApplication):
        def event(self, e):
            return QApplication.event(self, e)

    app = Application(sys.argv)
    signal.signal(signal.SIGINT, lambda *a: app.quit())
    app.startTimer(100)

    # let the user choose a folder via the GUI, save it for later
    if not in_folder:
        cfg = {}
        if os.path.isfile(CONFIG):
            cfg = get_json(CONFIG)
        if "in_folder" in cfg:
            in_folder = cfg["in_folder"]
        else:
            in_folder = str(QFileDialog.getExistingDirectory(None, "Select Input Folder"))
            put_json({"in_folder": in_folder}, CONFIG)
    in_folder = os.path.abspath(in_folder)

    # load all the images & staging data
    images = get_images(in_folder, staging_folder)
    tags = get_tags_from_csv(tags_file)

    print(f"STATUS: loaded {len(images)} images, {len([i for i in images if i.tags])} have tags")

    if len(images) == 0:
        print(f"ERROR: no images found!")
        exit(1)
    
    # spin up the GUI
    backend = Backend(images, tags, out_folder, webui_folder, dim, parent=app)

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
    
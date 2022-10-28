import sys
import traceback
import datetime
import glob
import os
import json
import time
import argparse
import platform
from PIL import Image, ImageDraw, ImageOps, ImageFilter

from PyQt5.QtCore import pyqtProperty, pyqtSignal, pyqtSlot, QObject, QUrl, QThread, QCoreApplication, Qt
from PyQt5.QtQml import QQmlApplicationEngine
from PyQt5.QtWidgets import QFileDialog, QApplication
import qml_rc

CONFIG = "config.json"
EXT = [".png", ".jpg", ".jpeg", ".webp"]
MX_TAGS = 30

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

def get_images(images_path, metadata_path):
    images = []

    files = []
    for e in EXT:
        files += glob.glob(images_path + "/*" + e)

    for f in files:
        m = os.path.join(metadata_path, os.path.basename(f) + ".json")

        img = Img(f, m)
        img.readMetadata()
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
    tags = [t.strip() for t in text.split(seperator)]
    return tags

def tags_to_prompt(tags):
    tags = [t.replace("_", " ") for t in tags]
    prompt = ", ".join(tags)
    #prompt = re.sub(r'\([^)]*\)', '', prompt)
    return prompt

def get_edge_colors(img, vertical, inset=0.01, samples=16):
    a = (0,0,0)
    b = (0,0,0)

    inset = int(min(img.size[0], img.size[1])*0.01)

    a_s = []
    b_s = []

    if vertical:
        for y in range(0, img.size[1], img.size[1]//samples):
            a_s += [img.getpixel((inset,y))]
            b_s += [img.getpixel((img.size[0]-1-inset,y))]
    else:
        for x in range(0, img.size[0], img.size[0]//samples):
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
            tags += [line.rstrip().split(",")[0]]
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

def to_filename(base, tags, ext):
    illegal = '<>:"/\\|?*'
    name = ''.join([c for c in tags_to_prompt(tags) if not c in illegal])
    return os.path.join(base, name+ext)

class DDBWorker(QObject):
    resultCallback = pyqtSignal(list)
    loadedCallback = pyqtSignal()

    def __init__(self, webui_folder, parent=None):
        super().__init__(parent)
        self.image = None
        self.webui_folder = webui_folder
        self.deep_folder = os.path.join(self.webui_folder, 'models', 'deepbooru')

        venv_deep_folder = os.path.join(self.webui_folder, 'venv', 'Lib', 'site-packages')
        if os.path.isdir(venv_deep_folder):
            sys.path.insert(0, venv_deep_folder)

        sys.path.insert(0, self.webui_folder)
        sys.path.insert(0, self.deep_folder)

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
        if(ready):
            img.setCrop(x,y,s)
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


class CropWorker(QObject):
    currentCallback = pyqtSignal(int)

    def __init__(self, images, out_folder, dimension, parent=None):
        super().__init__(parent)
        self.images = images
        self.out_folder = out_folder
        self.dim = dimension
        self.mode = 0
        self.ext = 0

    @pyqtSlot(int, int)
    def setup(self, mode, ext):
        self.mode = mode
        self.ext = ext

    @pyqtSlot()
    def start(self):
        ext = [".jpg", ".png"][self.ext]
        total = len(self.images)
        print(f"STATUS: packaging {total} images. type {ext}. mode {self.mode}...")
        for i in range(total):
            self.currentCallback.emit(i+1)
            img = self.images[i]
            out_path = ""
            if self.mode == 0: #single image
                tags = img.tags
                base = len(self.out_folder)
                while True:
                    out_path = to_filename(self.out_folder, tags, ext)
                    if len(out_path) < MX_PATH and len(out_path)-len(self.out_folder) < MX_FILE:
                        break
                    tags = tags[:-1]
            elif self.mode == 1:
                name = os.path.basename(img.source)
                name = os.path.splitext(name)[0]
                img.writePrompt(os.path.join(self.out_folder, name+".txt"))
                out_path = os.path.join(self.out_folder, name+ext)

            img.writeCrop(out_path, self.dim)
        print(f"STATUS: done")
        self.currentCallback.emit(0)

class Img:
    def __init__(self, image_path, metadata_path):
        self.source = image_path
        self.metadata_path = metadata_path
        self.ready = False
        self.changed = False
        self.ddb = []

    def center(self):
        img = Image.open(self.source).convert('RGB')
        x, y, w, h = positionCenter(img.size[0], img.size[1], 1024)
        self.setCrop(x/1024, y/1024, 1.0)

    def fill(self):
        img = Image.open(self.source).convert('RGB')
        x, y, w, h = positionFill(img.size[0], img.size[1], 1024)
        _, _, w2, _ = positionCenter(img.size[0], img.size[1], 1024)
        self.setCrop(x/1024, y/1024, w/w2)
        
    def readMetadata(self):
        if not os.path.isfile(self.metadata_path):
            self.tags = []
            return False
        metadata = {}
        with open(self.metadata_path, 'r', encoding="utf-8") as f:
            metadata = json.load(f)
        x,y,s = metadata["offset_x"], metadata["offset_y"], metadata["scale"]
        self.setCrop(x,y,s)
        self.tags = metadata["tags"]
        return True
    
    def writeMetadata(self):
        metadata = {"offset_x": self.offset_x,
                    "offset_y": self.offset_y,
                    "scale": self.scale,
                    "tags": self.tags}
        with open(self.metadata_path, 'w', encoding="utf-8") as f:
            json.dump(metadata, f)
        self.changed = False

    def doCrop(self, dim):
        img = Image.open(self.source).convert('RGB')
        x, y, w, h = positionCenter(img.size[0], img.size[1], dim)

        if not self.ready:
            self.setCrop(x/dim, y/dim, 1.0)

        s = (w/img.size[0]) * self.scale
        img = img.resize((int(img.size[0] * s),int(img.size[1] * s)))
        crop = Image.new(mode='RGB',size=(dim,dim))
        crop.paste(img, (int(self.offset_x*dim), int(self.offset_y*dim)))
        return crop

    def buildPrompt(self):
        return tags_to_prompt(self.tags)

    def writeCrop(self, crop_file, dim):
        crop = self.doCrop(dim)

        if crop_file.endswith(".jpg"):
            crop.save(crop_file, quality=95)
        else:
            crop.save(crop_file)
    
    def writePrompt(self, prompt_file):
        with open(prompt_file, "w", encoding="utf-8") as f:
            f.write(self.buildPrompt())

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
        if not self.readMetadata():
            self.fill()
        self.changed = False
    
    def fullReset(self):
        self.tags = get_metadata(self.source)
        self.fill()
        self.writeMetadata()
        self.changed = False

class Backend(QObject):
    updated = pyqtSignal()
    changedUpdated = pyqtSignal()
    tagsUpdated = pyqtSignal()
    imageUpdated = pyqtSignal()
    searchUpdated = pyqtSignal()
    favUpdated = pyqtSignal()
    suggestionsUpdated = pyqtSignal()

    cropWorkerUpdated = pyqtSignal()
    cropWorkerSetup = pyqtSignal(int,int)
    cropWorkerStart = pyqtSignal()

    ddbWorkerUpdated = pyqtSignal()
    ddbWorkerInterrogate = pyqtSignal(int, 'QString', bool, float, float, float)

    def __init__(self, images, tags, out_folder, webui_folder, dimension, parent=None):
        super().__init__(parent)
        self._images = images
        self._tags = tags
        self._lookup = set(tags)
        self._results = []
        
        self._active = -1
        self.setActive(0)
        self._current = self._images[self._active]
        self._dim = dimension
        self.webui_folder = webui_folder

        self.search("")

        self._fav = []
        self._freq = {}
        self.loadConfig()
        self.saveConfig()
        self._showFrequent = True

        self.cropWorker = CropWorker(self._images, out_folder, self._dim)
        self.cropWorkerCurrent = 0
        self.cropThread = QThread(self)
        self.cropWorker.currentCallback.connect(self.currentCallback)
        self.cropWorkerSetup.connect(self.cropWorker.setup)
        self.cropWorkerStart.connect(self.cropWorker.start)
        self.cropWorker.moveToThread(self.cropThread)

        self.ddbMode = False
        self.ddbCurrent = -1
        self.ddbLoading = True
        self.ddbAll = False
        self.ddbActive = self.webui_folder != None
        self.ddbThread = None
        if self.ddbActive:
            self.ddbInit()

        parent.aboutToQuit.connect(self.closing)
    
    def ddbInit(self):
        self.ddbWorker = DDBWorker(self.webui_folder)
        self.ddbThread = QThread(self)
        self.ddbWorker.resultCallback.connect(self.ddbResultCallback)
        self.ddbWorker.loadedCallback.connect(self.ddbLoadedCallback)
        self.ddbWorkerInterrogate.connect(self.ddbWorker.interrogate)
        self.ddbWorker.moveToThread(self.ddbThread)
        self.ddbThread.started.connect(self.ddbWorker.load)
        self.ddbThread.start()

    @pyqtProperty(int, constant=True)
    def total(self):
        return len(self._images)

    @pyqtProperty(int, notify=updated)
    def active(self):
        return self._active
    @active.setter
    def active(self, a):
        a = a % len(self._images)
        if a >= 0 and a < len(self._images):
            self.setActive(a)
    def setActive(self, a):
        if a == self._active:
            return
        self._active = a
        self._current = self._images[self._active]
        if not self._current.ready:
            self._current.fill()

        if not self._current.ddb:
            self._showFrequent = True
        
        self.changedUpdated.emit()
        self.imageUpdated.emit()
        self.tagsUpdated.emit()
        self.suggestionsUpdated.emit()
        self.updated.emit()

    @pyqtProperty('QString', notify=updated)
    def source(self):
        return self._current.source
    @pyqtProperty(bool, notify=changedUpdated)
    def changed(self):
        return self._current.changed
    @pyqtProperty(float, notify=imageUpdated)
    def offset_x(self):
        return self._current.offset_x
    @pyqtProperty(float, notify=imageUpdated)
    def offset_y(self):
        return self._current.offset_y
    @pyqtProperty(float, notify=imageUpdated)
    def scale(self):
        return self._current.scale
    @pyqtProperty(list, notify=tagsUpdated)
    def tags(self):
        return self._current.tags
    @pyqtProperty(list, notify=searchUpdated)
    def results(self):
        return self._results
    @pyqtProperty('QString', notify=cropWorkerUpdated)
    def workerStatus(self):
        if self.cropWorkerCurrent == 0:
            return ""
        return os.path.basename(self._images[self.cropWorkerCurrent-1].source)
    @pyqtProperty(float, notify=cropWorkerUpdated)
    def workerProgress(self):
        return self.cropWorkerCurrent/len(self._images)
    @pyqtProperty('QString', notify=updated)
    def title(self):
        return f"Tagging {self._active+1} of {len(self._images)}"
    @pyqtProperty(list, notify=favUpdated)
    def favourites(self):
        return self._fav
    @pyqtProperty(list, notify=suggestionsUpdated)
    def suggestions(self):
        if self._showFrequent:
            f = [(k, self._freq[k]) for k in self._freq]
            f.sort(key=lambda a:a[1], reverse=True)
            return [t[0] for t in f]
        else:
            return self._current.ddb
    @pyqtProperty(int, notify=suggestionsUpdated)
    def ddbStatus(self):
        if not self.ddbActive:
            return -2
        if self.ddbLoading:
            return -1
        if self.ddbCurrent == -1:
            return 0 #idle
        if self.ddbAll:
            return 2+self.ddbCurrent #working on all 
        return 1 #working 
    @pyqtProperty(bool, notify=suggestionsUpdated)
    def showingFrequent(self):
        return self._showFrequent


    @pyqtSlot('QString', result=bool)
    def lookup(self, tag):
        return tag in self._lookup

    @pyqtSlot('QString')
    def addTag(self, tag):
        if tag in self._current.tags:
            return
        self._current.addTag(tag)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

        if not tag in self._freq:
            self._freq[tag] = 0
        self._freq[tag] += 1
        self.saveConfig()

        self.suggestionsUpdated.emit()

    @pyqtSlot(int)
    def deleteTag(self, idx):
        if idx < 0 or idx >= len(self._current.tags):
            return
        self._current.deleteTag(idx)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot(int, int)
    def moveTag(self, from_idx, to_idx):
        self._current.moveTag(from_idx, to_idx)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot(int,int,int,int,int,int)
    def applyCrop(self, fx, fy, fw, fh, cw, ch):
        x, y, w, h = positionCenter(fw, fh, cw)
        self._current.setCrop(fx/cw, fy/cw, fw/w)
        self.imageUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot()
    def saveMetadata(self):
        self._current.writeMetadata()
        self.changedUpdated.emit()

    @pyqtSlot()
    def center(self):
        self._current.center()
        self.imageUpdated.emit()
        self.changedUpdated.emit()
    
    @pyqtSlot()
    def fill(self):
        self._current.fill()
        self.imageUpdated.emit()
        self.changedUpdated.emit()

    @pyqtSlot()
    def writeDebugCrop(self):
        self._current.writeCrop("out.png", self._dim)

    @pyqtSlot()
    def reset(self):
        self._current.reset()
        self.tagsUpdated.emit()
        self.imageUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot('QString')
    def search(self, s):
        if not s:
            if len(self._tags) > MX_TAGS:
                self._results = self._tags[0:MX_TAGS]
            self._results = self._tags
        s = s.replace(" ", "_")
        results = []
        for t in self._tags:
            if s in t:
                results += [t]
            if len(results) > MX_TAGS:
                break

        self._results = results
        self.searchUpdated.emit()

    @pyqtSlot(int)
    def currentCallback(self, current):
        self.cropWorkerCurrent = current
        self.cropWorkerUpdated.emit()
        if current == 0:
            self.cropThread.quit()

    @pyqtSlot(int, int)
    def package(self, mode, ext):
        self.cropThread.start()
        self.cropWorkerSetup.emit(mode, ext)
        self.cropWorkerStart.emit()

    @pyqtSlot()
    def cleanTags(self):
        tags = [t for t in self._current.tags if t in self._lookup]
        self._current.setTags(tags)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot()
    def sortTags(self):
        tags = [t for t in self._tags if t in self._current.tags]
        tags += [t for t in self._current.tags if not t in tags]
        self._current.setTags(tags)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot()
    def fullReset(self):
        self._current.fullReset()
        self.imageUpdated.emit()
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()

    @pyqtSlot('QString')
    def addFavourite(self, tag):
        self._fav += [tag]
        self.favUpdated.emit()
        self.saveConfig()

    @pyqtSlot('QString')
    def toggleFavourite(self, tag):
        if tag in self._fav:
            del self._fav[self._fav.index(tag)]
        else:
            self._fav += [tag]
        self.favUpdated.emit()
        self.saveConfig()

    @pyqtSlot(int)
    def deleteFavourite(self, idx):
        del self._fav[idx]
        self.favUpdated.emit()
        self.saveConfig()

    @pyqtSlot(int, int)
    def moveFavourite(self, from_idx, to_idx):
        self._fav.insert(to_idx, self._fav.pop(from_idx))
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

        if(self._current.ddb):
            self._showFrequent = False

        if self.ddbCurrent == -1:
            self.ddbCurrent = self._active
            im = self._current
            self.ddbWorkerInterrogate.emit(self._dim, im.source, im.ready, im.offset_x, im.offset_y, im.scale)
        
        self.suggestionsUpdated.emit()
    
    def ddbInterrogateNext(self):
        self.ddbCurrent += 1
        if self.ddbCurrent >= len(self._images):
            self.ddbAll = False
            self.ddbCurrent = -1
            self.suggestionsUpdated.emit()
            return
        
        im = self._images[self.ddbCurrent]
        if im.ready:
            self.ddbWorkerInterrogate.emit(self._dim, im.source, im.ready, im.offset_x, im.offset_y, im.scale)
        else:
            self.ddbWorkerInterrogate.emit(self._dim, im.source, im.ready, 0.0, 0.0, 0.0)
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
    def ddbLoadedCallback(self):
        self.ddbLoading = False
        self.suggestionsUpdated.emit()

    @pyqtSlot(list)
    def ddbResultCallback(self, tags):
        img = self._images[self.ddbCurrent]
        img.ddb = tags

        if self.ddbCurrent == self._active:
            self._showFrequent = False

        if self.ddbAll:
            self.ddbInterrogateNext()
        else:
            self.ddbCurrent = -1
            self.suggestionsUpdated.emit()

    @pyqtSlot()
    def showFrequent(self):
        self._showFrequent = True
        self.suggestionsUpdated.emit()

    @pyqtSlot()
    def closing(self):
        if self.ddbThread:
            self.ddbThread.quit()
            self.ddbThread.wait()

    @pyqtSlot()
    def copy(self):
        prompt = self._current.buildPrompt()
        QApplication.clipboard().setText(prompt)

    @pyqtSlot(bool)
    def paste(self, override):
        prompt = QApplication.clipboard().text()
        tags = [t.strip().replace(" ", "_") for t in prompt.split(", ")]
        
        real_tags = any([t in self._lookup for t in tags])
        if not real_tags:
            return

        if override:
            self._current.tags = []
        
        for t in tags:
            if not t in self._current.tags:
                self._current.addTag(t)
        
        self.tagsUpdated.emit()
        self.changedUpdated.emit()
        self.updated.emit()


    def loadConfig(self):
        j = get_json(CONFIG)
        if 'fav' in j:
            self._fav = j["fav"]
        if 'freq' in j:
            self._freq = j["freq"]
        if 'webui' in j and self.webui_folder == None:
            self.webui_folder = j["webui"]

    def saveConfig(self):
        put_json({"fav": self._fav, "freq": self._freq, "webui": self.webui_folder}, CONFIG)


def start():
    parser = argparse.ArgumentParser(description='manual image tag/cropping helper GUI')
    parser.add_argument('--input', type=str, help='folder to load images with optional associated tag file (eg: img.png, img.png.txt)')
    parser.add_argument('--dimension', type=int, help='dimension of output images. defaults to 1024x1024')
    parser.add_argument('--metadata', type=str, help='folder to store metadata for each image. defaults to "metadata"')
    parser.add_argument('--output', type=str, help='folder to write the packaged images/tags. defaults to "output"')
    parser.add_argument('--tags', type=str, help='optional tag index file. defaults to danbooru tags')
    parser.add_argument('--webui', type=str, help='optional path to stable-diffusion-webui. enables the use of deepdanbooru')
    args = parser.parse_args()

    in_folder = args.input
    dim = args.dimension
    out_folder = args.output
    meta_folder = args.metadata
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

    if not meta_folder:
        meta_folder = "metadata"
        if not os.path.exists(meta_folder):
            os.makedirs(meta_folder)
    if not os.path.isdir(meta_folder):
        print(f"ERROR: metadata folder '{metadata_folder}' does not exist!")
        exit(1)
    meta_folder = os.path.abspath(meta_folder)
    
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
    app = QApplication(sys.argv)

    # let the user choose a folder via the GUI, save it for later
    if not in_folder:
        if os.path.isfile(CONFIG):
            in_folder = get_json(CONFIG)["in_folder"]
        else:
            in_folder = str(QFileDialog.getExistingDirectory(None, "Select Input Folder"))
            put_json({"in_folder": in_folder}, CONFIG)
    in_folder = os.path.abspath(in_folder)

    # load all the images/metadata
    images = get_images(in_folder, meta_folder)
    tags = get_tags_from_csv(tags_file)
    print(f"STATUS: loaded {len(images)} images, {len([i for i in images if i.tags])} have tags")

    if len(images) == 0:
        print(f"ERROR: no images found!")
        exit(1)
    
    # spin up the GUI
    backend = Backend(images, tags, out_folder, webui_folder, dim, parent=app)

    engine = QQmlApplicationEngine()
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
    
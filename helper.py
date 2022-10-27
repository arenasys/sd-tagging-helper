import sys
import glob
import os
import json
import time
import argparse
from PIL import Image, ImageDraw, ImageOps, ImageFilter

from PyQt5.QtCore import pyqtProperty, pyqtSignal, pyqtSlot, QObject, QUrl, QThread
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQml import QQmlApplicationEngine
import qml_rc

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

class Worker(QObject):
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
            name = ""
            if self.mode == 0: #single image
                tags = img.tags
                while len(", ".join(tags)) > 240:
                    tags = tags[:-1]
                name = tags_to_prompt(tags)
                illegal = '<>:"/\\|?*'
                name = ''.join([c for c in name if not c in illegal])
            elif self.mode == 1:
                name = os.path.basename(img.source)
                name = os.path.splitext(name)[0]
                img.writePrompt(os.path.join(self.out_folder, name+".txt"))

            img.writeCrop(os.path.join(self.out_folder, name+ext), self.dim)
        print(f"STATUS: done")
        self.currentCallback.emit(0)

class Img:
    def __init__(self, image_path, metadata_path):
        self.source = image_path
        self.metadata_path = metadata_path
        self.ready = False
        self.changed = False

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
            return
        metadata = {}
        with open(self.metadata_path, 'r') as f:
            metadata = json.load(f)
        x,y,s = metadata["offset_x"], metadata["offset_y"], metadata["scale"]
        self.setCrop(x,y,s)
        self.tags = metadata["tags"]
    
    def writeMetadata(self):
        metadata = {"offset_x": self.offset_x,
                    "offset_y": self.offset_y,
                    "scale": self.scale,
                    "tags": self.tags}
        with open(self.metadata_path, 'w') as f:
            json.dump(metadata, f)
        self.changed = False

    def writeCrop(self, crop_file, dim):
        img = Image.open(self.source).convert('RGB')
        x, y, w, h = positionCenter(img.size[0], img.size[1], dim)

        if not self.ready:
            self.setCrop(x/dim, y/dim, 1.0)

        s = (w/img.size[0]) * self.scale
        img = img.resize((int(img.size[0] * s),int(img.size[1] * s)))
        crop = Image.new(mode='RGB',size=(dim,dim))
        crop.paste(img, (int(self.offset_x*dim), int(self.offset_y*dim)))

        if crop_file.endswith(".jpg"):
            crop.save(crop_file, quality=95)
        else:
            crop.save(crop_file)
    
    def writePrompt(self, prompt_file):
        with open(prompt_file, "w") as f:
            f.write(tags_to_prompt(self.tags))

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


class Backend(QObject):
    updated = pyqtSignal()
    changedUpdated = pyqtSignal()
    tagsUpdated = pyqtSignal()
    imageUpdated = pyqtSignal()
    searchUpdated = pyqtSignal()
    workerUpdated = pyqtSignal()

    workerSetup = pyqtSignal(int,int)
    workerStart = pyqtSignal()

    def __init__(self, images, tags, out_folder, dimension, parent=None):
        super().__init__(parent)
        self._images = images
        self._tags = tags
        self._results = tags
        self._active = -1
        self.setActive(0)
        self._current = self._images[self._active]
        self._dim = dimension

        self.worker = Worker(self._images, out_folder, self._dim)
        self.workerCurrent = 0
        self.thread = QThread(self)
        self.worker.currentCallback.connect(self.currentCallback)
        self.workerSetup.connect(self.worker.setup)
        self.workerStart.connect(self.worker.start)
        self.worker.moveToThread(self.thread)

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
            self._current.center()
        
        self.changedUpdated.emit()
        self.imageUpdated.emit()
        self.tagsUpdated.emit()
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
    @pyqtProperty('QString', notify=workerUpdated)
    def workerStatus(self):
        if self.workerCurrent == 0:
            return ""
        return os.path.basename(self._images[self.workerCurrent-1].source)
    @pyqtProperty(float, notify=workerUpdated)
    def workerProgress(self):
        return self.workerCurrent/len(self._images)
    @pyqtProperty('QString', notify=updated)
    def title(self):
        return f"Tagger {self._active+1} of {len(self._images)}"

    @pyqtSlot('QString')
    def addTag(self, tag):
        if tag in self._current.tags:
            return
        self._current.addTag(tag)
        self.tagsUpdated.emit()
        self.changedUpdated.emit()

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

        #self._current.writeCrop("out.png", self._dim)

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

    @pyqtSlot('QString')
    def search(self, s):
        if not s:
            self._results = self._tags
        self._results = [t for t in self._tags if s in t]
        self.searchUpdated.emit()

    @pyqtSlot(int)
    def currentCallback(self, current):
        self.workerCurrent = current
        self.workerUpdated.emit()
        if current == 0:
            self.thread.quit()


    @pyqtSlot(int, int)
    def package(self, mode, ext):
        self.thread.start()
        self.workerSetup.emit(mode, ext)
        self.workerStart.emit()

ext = [".png", ".jpg", ".jpeg", ".webp"]
def get_images(images_path, metadata_path):
    images_path = os.path.abspath(images_path)
    metadata_path = os.path.abspath(metadata_path)

    images = []

    files = []
    for e in ext:
        files += glob.glob(images_path + "/*" + e)

    for f in files:
        m = os.path.join(metadata_path, os.path.basename(f) + ".json")

        img = Img(f, m)
        img.readMetadata()
        if not img.ready:
            tags = []
            m1 = f + ".txt"
            m2 = ".".join(f.split(".")[:-1]) + ".txt"
            for m in [m1, m2]:
                if os.path.isfile(m):
                    tags = get_tags(m)
                    break
            img.tags = tags
        images += [img]

    return images

def get_tags(tag_file):
    with open(tag_file, "r") as f:
        return extract_tags(f.read())

def get_tags_from_csv(path):
    tags = []
    with open(path) as file:
        for line in file:
            tags += [line.rstrip().split(",")[0]]
    return tags


parser = argparse.ArgumentParser(description='manual image tag/cropping helper GUI')
parser.add_argument('--input', type=str, help='folder to load images with optional associated tag file (eg: img.png, img.png.txt)')
parser.add_argument('--dimension', type=int, help='dimension of output images. defaults to 1024x1024')
parser.add_argument('--metadata', type=str, help='folder to store metadata for each image. defaults to "metadata"')
parser.add_argument('--output', type=str, help='folder to write the packaged images/tags. defaults to "output"')
parser.add_argument('--tags', type=str, help='optional tag index file. defaults to danbooru tags')
args = parser.parse_args()

in_folder = args.input
dim = args.dimension
out_folder = args.output
meta_folder = args.metadata
tags_file = args.tags

if not in_folder:
    print("ERROR: specify an input folder!")
    exit(1)
if not os.path.isdir(in_folder):
    print("ERROR: input folder '{in_folder}' does not exist!")
    exit(1)

if not out_folder:
    out_folder = "output"
    if not os.path.exists(out_folder):
        os.makedirs(out_folder)
if not os.path.isdir(out_folder):
    print("ERROR: output folder '{out_folder}' does not exist!")
    exit(1)

if not meta_folder:
    meta_folder = "metadata"
    if not os.path.exists(meta_folder):
        os.makedirs(meta_folder)
if not os.path.isdir(meta_folder):
    print("ERROR: metadata folder '{out_folder}' does not exist!")
    exit(1)

if not tags_file:
    tags_file = os.path.join(os.path.abspath(os.path.dirname(__file__)), "danbooru.csv")
if not os.path.isfile(tags_file):
    print("ERROR: tags file '{tags_file}' does not exist!")
    exit(1)

if not dim:
    dim = 1024
if dim % 32 != 0 or dim <= 0:
    print("ERROR: dimension of '{dim}' is not valid!")


images = get_images(in_folder, meta_folder)
tags = get_tags_from_csv(tags_file)
print(f"STATUS: loaded {len(images)} images, {len([i for i in images if i.tags])} have tags")

app = QGuiApplication(sys.argv)
backend = Backend(images, tags, out_folder, dim, app)

engine = QQmlApplicationEngine()
engine.quit.connect(app.quit)
ctx = engine.rootContext()
ctx.setContextProperty("backend", backend)

engine.load(QUrl('qrc:/Main.qml'))

sys.exit(app.exec())
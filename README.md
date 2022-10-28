## Helper GUI for manual tagging/cropping
--------
A GUI to help with manual tagging and cropping. Written in Python/Qt5.
![example](https://github.com/arenatemp/sd-tagging-helper/raw/master/screenshot.png)

### Requirements
Pillow and PyQt5
```
pip install pillow pyqt5
```

### Workings
Operates on a folder of input images. Each image can optionally have an associated tag file.
```
GIVEN img0000.png
LOOKS FOR img0000.txt
LOOKS FOR img0000.png.txt
LOOKS FOR img0000.png.json
```
A txt file is expected to contain comma seperated tags. The json file is expected to be a gallery-dl metadata file.
The input folder/files are left untouched, all changes made are saved into the metadata folder as json files. So changes are persistant but also no data loss is possible.

There are two modes of cropping, you can freely change between them with `Alt`. Red indicates some metadata changes have not been saved yet, enabling you to revert to the last save with `Ctrl+Z`. Metadata is saved automatically when changing modes or changing image. Press the save button or `Ctrl+S` to save manually. Right click the reset button to show the option to fully reset back to the original input state.

When ready the inputs can be packaged into the output folder, in this folder the images will be cropped/resized and the modified tags written.
The two modes of packaging are:
- Single image
- Image/prompt pairs

Single image will save an image with the filename set to the prompt.
Image/prompt pairs will save the image with its original name and a corresponding text file containing the prompt (like the input folder format).
The prompt will be comma seperated and be cleaned (replace underscores with spaces etc).

### DeepDanbooru
Assumes you have a working instance of [stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui) with DeepDanbooru working.
Press the interrogate button and select the `stable-diffusion-webui` folder, this will be saved for next session.

### Usage
The minimal usage is to run `helper.py` or `start.bat`. The program will ask you for an input folder, which will be remembered for next time. A metadata and output folder will be created in the current directory, and the output dimension will be 1024x1024. For more parameters read `python help.py --help`.

### Hotkeys
```
Alt      - Switch croping mode
Ctrl + S - Save metadata
Ctrl + Z - Reset metadata to last saved state
Ctrl + A - Auto position image. contain all mode
Ctrl + D - Auto position image. fill mode
Ctrl + E - Write current crop to out.png (for testing)

LEFT  - Previous image
RIGHT - Next image
UP    - Move selected tag up
DOWN  - Move selected tag down
```

### Compiling
If you change the GUI `.qml` files the `qml_rc.py` will need to be recompiled:
```
pyrcc5 -o qml_rc.py qml/qml.qrc
```
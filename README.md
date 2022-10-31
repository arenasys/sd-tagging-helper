## Helper GUI for manual tagging/cropping
--------
A GUI to help with manual tagging and cropping. Written in Python/Qt5.
![example](https://github.com/arenatemp/sd-tagging-helper/raw/master/screenshot.png)

### Requirements
Pillow and PyQt5
```
pip install pillow pyqt5==5.15.7
```

### Workings
Operates on a workflow of: input ➜ staging ➜ output. The input is a folder of images + metadata. The staging folder will store any changes you make. And the output folder is populated on demand by packaging up the input and staging data. When loading an image it will attempt to find the prompt/metadata associated with it:
```
GIVEN img0000.png
LOOKS FOR img0000.txt
LOOKS FOR img0000.png.txt
LOOKS FOR img0000.png.json
```
A txt file is expected to contain comma seperated tags. A json file is expected to be a [gallery-dl](https://github.com/mikf/gallery-dl) metadata file.
Since all changes are made in the staging folder, the input data/images are left untouched. Meaning no data loss is possible.

There are two modes of cropping, you can freely change between them with `Alt`. Red indicates some changes have not been saved yet, enabling you to revert to the last save with `Ctrl+Z`. Changes are saved automatically when switching modes or image. Press the save button or `Ctrl+S` to save manually. Right click the reset button to show the option to fully reset back to the original input state.

When ready the inputs can be packaged into the output folder, in this folder the images will be cropped/resized and the modified tags written.
The two modes of packaging are:
- Single image
- Image/prompt pairs

Single image will save an image with the filename set to the prompt.
Image/prompt pairs will save the image with its original name and a corresponding text file containing the prompt (like the input folder format).
The prompt will be comma separated and be cleaned (underscores replaced with spaces etc).

### DeepDanbooru
Assumes you have a working instance of [stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui) with DeepDanbooru working.
Press the interrogate button and select the `stable-diffusion-webui` folder, this will be saved for next session.
An alternate layout was added for efficient tagging, switch to it with `Ctrl+L`

### Usage
The minimal usage is to run `helper.py` or `start.bat`. The program will ask you for an input folder, which will be remembered for next time. A staging and output folder will be created in the current directory, and the output dimension will be 1024x1024. For more parameters read `python helper.py --help`.

### Hotkeys
```
Alt      - Switch croping mode
Ctrl + S - Save changes
Ctrl + Z - Reset to last saved state
Ctrl + A - Auto position image. contain all mode
Ctrl + D - Auto position image. fill mode
Ctrl + E - Write current crop to out.png (for testing)
Ctrl + C - Copy prompt into clip board
Ctrl + V - Paste a prompt onto the current image, adding missing tags
Ctrl + B - Paste a prompt onto the current image, deleting the previous tags
Ctrl + L - Switch to an alternate GUI layout
Ctrl + K - Toggle tag colors
Ctrl + Q - Interrogate image via DeepDanbooru

Left  - Previous image
Right - Next image
Up    - Move selected tag up OR Move selection up
Down  - Move selected tag down OR Move selection up

Enter - Delete tag OR Add tag

Tab        - Cycle between tag lists
Ctrl + Tab - Reverse cycle between tag lists

WASD  - Move image (alt crop mode)
```

### Compiling
If you change the GUI `.qml` files then `qml_rc.py` will need to be recompiled:
```
pyrcc5 -o qml_rc.py qml/qml.qrc
```
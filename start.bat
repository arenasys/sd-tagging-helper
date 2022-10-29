if not DEFINED IS_MINIMIZED set IS_MINIMIZED=1 && start "" /min "%~dpnx0" %* && exit
@echo off

if not exist .\venv\ (
	mkdir venv
    python -m venv .\venv\
	start /wait /b "" .\venv\Scripts\pip3.exe install -q pillow pyqt5==5.15.7
)

:: --input,     type=str, folder to load images with optional associated tag file (eg: img.png, img.png.txt)
:: --dimension, type=int, dimension of output images. defaults to 1024
:: --metadata,     type=str, folder to store metadata for each image. defaults to "metadata"
:: --output,     type=str, folder to write the packaged images/tags. defaults to "output"
:: --tags,     type=str, optional tag index file. defaults to danbooru tags
:: --webui,     type=str, optional path to stable-diffusion-webui. enables the use of deepdanbooru

.\venv\Scripts\python.exe helper.py

exit
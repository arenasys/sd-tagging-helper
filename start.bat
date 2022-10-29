if not DEFINED IS_MINIMIZED set IS_MINIMIZED=1 && start "" /min "%~dpnx0" %* && exit
@echo off

if not exist .\venv\ (
	mkdir venv
    python -m venv .\venv\
	start /wait /b "" .\venv\Scripts\pip3.exe install -q pillow pyqt5==5.15.7
)

.\venv\Scripts\python.exe helper.py

exit
# PdfToCbr
PdfToCbr is a GUI to extract images from a PDF file and save them in a folder or as CBZ/CBR archives.

<p align=center>
  <img alt="PdfToCbr main screen" align="center" width="441" height="604" src="https://raw.githubusercontent.com/tudo75/PdfToCbr/refs/heads/BatchMode/images/img_2025-12-09_12-54-24.png">
</p>

<p align=center>
  <img alt="PdfToCbr batch mode screen" align="center" width="602" height="482" src="https://raw.githubusercontent.com/tudo75/PdfToCbr/refs/heads/BatchMode/images/img_2025-12-09_12-54-40.png">
</p>

## Requirements
First of all the system must support threads.

To compile some libraries are needed:

* meson
* ninja-build
* valac
* libgtk-3-dev
* libglib2.0-dev
* libpoppler-dev
* libcairo2-dev
* libarchive-dev

To install on Ubuntu based distros:

    sudo apt install meson ninja-build build-essential valac cmake libgtk-3-dev libglib2.0-dev libpoppler-dev libcairo2-dev libarchive-dev

## Install
Clone the repository:
	
	git clone https://github.com/tudo75/PdfToCbr.git
	cd PdfToCbr

And from inside the cloned folder:
	
	meson setup build --prefix=/usr
	ninja -v -C build PdfToCbr-gmo
	ninja -v -C build pdftocbr-cli
	ninja -v -C build pdftocbr
	sudo ninja -v -C build install

## Uninstall
To uninstall and remove all added files, go inside the cloned folder and:

	sudo ninja -v -C build uninstall
	sudo rm /usr/share/locale/en/LC_MESSAGES/PdfToCbr.mo
	sudo rm /usr/share/locale/it/LC_MESSAGES/PdfToCbr.mo






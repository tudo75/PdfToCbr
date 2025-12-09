# PdfToCbr
PdfToCbr is a GUI to extract images from a PDF file and save them in a folder or as CBZ/CBR archives.

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






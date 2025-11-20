#!/bin/bash
valac --pkg libusb-1.0 --pkg gio-2.0 --pkg gdk-pixbuf-2.0 brotherprinterusb.vala -o brother-usb

# Test commands
# 
# Debug command:
# 
# $>> ./brother-usb --debug 0000 test.png
# 
#
# Analizza il risultato: Verrà creato un file brother_dump.bin. 
# Puoi ispezionarlo con hexdump per vedere se la sequenza di byte corrisponde esattamente al PDF Brother:
# 
# $>> hexdump -C brother_dump.bin | head
#
# 
# Oppure inviarlo manualmente alla stampante (se è configurata su /dev/usb/lp0) 
# per testare se il file generato funziona:
# 
# $>> sudo cat brother_dump.bin > /dev/usb/lp0
# 
# 
# 
# 
# 

/*
    usb_scanner.vala

    valac --pkg libusb-1.0 usbscanner.vala
*/

using LibUSB;
using GLib; // for Glib.Error

const int TARGET_VID = 0x04f9; // Brother Industries, Ltd.
const int TIMEOUT_MS = 1000;

// Placeholder variables to store dynamically found endpoints
uint8 global_out_endpoint = 0x00;
uint8 global_in_endpoint = 0x00;

int main () {
    Context context;
    Device[] devices;

    LibUSB.Context.init (out context);
    devices = context.get_device_list ();

    stdout.printf ("\nSearching for devices with Vendor ID 0x%04x...\n", TARGET_VID);

    int count = 0;
    int i = 0;
    while (devices[i] != null) {
        var dev = devices[i];
        DeviceDescriptor desc = DeviceDescriptor (dev);

        if (desc.idVendor == TARGET_VID) {
            count++;
            stdout.printf ("\n--- Found Device %d ---\n", count);
            stdout.printf ("Bus %04x Device %04x: Vendor ID 0x%04x, Product ID 0x%04x\n",
                           dev.get_bus_number (), dev.get_device_address (), desc.idVendor, desc.idProduct);
            
            // Call function to discover endpoints
            find_endpoints(dev);

            // --- Open and communicate with the specific device ---
            DeviceHandle handle = null;
            if (global_in_endpoint == 0x00 || global_out_endpoint == 0x00) {
                 stdout.printf("Could not find suitable IN/OUT bulk endpoints. Skipping communication.\n");
                 i++;
                 continue;
            }

            try {
                dev.open (out handle);
                stdout.printf ("Device opened. Attempting to claim interface 0...\n");

                // Detach kernel driver if active and claim the interface
                if (handle.kernel_driver_active(0) == 1) {
                    handle.detach_kernel_driver(0);
                    stdout.printf("Kernel driver detached.\n");
                }
                handle.claim_interface(0);
                stdout.printf("Interface 0 claimed.\n");

                // --- Perform Read and Write Operations using dynamically found endpoints ---
                perform_read_write(handle);

            } catch (GLib.Error e) {
                stdout.printf ("\nError opening/communicating with device: %s\n", e.message);
                stdout.printf("You might need elevated privileges (sudo) or udev rules.\n");
            } finally {
                // Cleanup operations
                if (handle != null) {
                    try {
                        handle.release_interface(0);
                        //dev.close();
                        stdout.printf("Device closed and interface released.\n");
                    } catch (GLib.Error e) {
                        stdout.printf("Error during cleanup: %s\n", e.message);
                    }
                }
            }
        }
        i++;
    }

    if (count == 0) {
        stdout.printf ("No devices found with Vendor ID 0x%04x.\n", TARGET_VID);
    }

    //context.free_device_list(devices, true);
    //context.exit();
    return 0;
}

// Function to iterate through descriptors and find endpoints
void find_endpoints(Device dev) {
    ConfigDescriptor config;
    global_in_endpoint = 0x00;
    global_out_endpoint = 0x00;

    try {
        dev.get_active_config_descriptor(out config);

        for (int i = 0; i < config.bNumInterfaces; i++) {
            Interface iface = config.interfaces[i];
            for (int j = 0; j < iface.num_altsetting; j++) {
                InterfaceDescriptor iface_desc = iface.altsetting[j];

                for (int k = 0; k < iface_desc.bNumEndpoints; k++) {
                    EndpointDescriptor ep_desc = iface_desc.endpoint[k];
                    uint8 ep_address = ep_desc.bEndpointAddress;
                    uint8 transfer_type_bits = ep_desc.bmAttributes & 0x03;

                    // Check if it's a BULK endpoint
                    if (transfer_type_bits == (uint8)TransferType.BULK) {
                        if ((ep_address & (uint8)EndpointDirection.IN) == (uint8)EndpointDirection.IN) {
                            global_in_endpoint = ep_address;
                        } else {
                            global_out_endpoint = ep_address;
                        }
                    }
                }
            }
        }
    } catch (GLib.Error e) {
        stdout.printf("Error reading configuration descriptors: %s\n", e.message);
    } finally {
        if (config != null) {
            config.free();
        }
    }
}


// Function to handle read and write operations
void perform_read_write(DeviceHandle handle) {
    // --- Write Data (Bulk Transfer OUT) ---
    uint8[] write_buffer = {0x1b, 0x40}; // Example: simple printer command (initialize printer)
    int actual_written;

    try {
        stdout.printf("Attempting bulk write to endpoint 0x%02x\n", global_out_endpoint);
        handle.bulk_transfer(global_out_endpoint, write_buffer, out actual_written, TIMEOUT_MS);
        stdout.printf("Bulk write successful. Bytes written: %d\n", actual_written);
    } catch (GLib.Error e) {
        stdout.printf("Bulk write failed: %s\n", e.message);
    }

    // --- Read Data (Bulk Transfer IN) ---
    uint8[] read_buffer = new uint8[64]; // Ensure buffer is large enough for Max Packet Size
    int actual_read;

    try {
        stdout.printf("Attempting bulk read from endpoint 0x%02x\n", global_in_endpoint);
        handle.bulk_transfer(global_in_endpoint, read_buffer, out actual_read, TIMEOUT_MS);
        stdout.printf("Bulk read successful. Bytes read: %d\n", actual_read);
        // Process read_buffer[0...actual_read-1]
    } catch (GLib.Error e) {
        stdout.printf("Bulk read failed: %s\n", e.message);
    }
}


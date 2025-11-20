using GLib;
using Gdk;
using LibUSB;

public struct LabelConfig {
    public int width_mm;      
    public bool is_continuous; 
    public int label_length_mm; 
}

public class BrotherPrinterUSB : Object {
    private Context ctx;
    private DeviceHandle? handle = null;
    private uint8 endpoint_out = 0;
    private const uint16 VENDOR_ID = 0x04f9; 
    private uint16 product_id; 
    
    // --- Variabili per Debug ---
    public bool debug_mode = false;
    private FileOutputStream? debug_stream = null;

    public BrotherPrinterUSB(uint16 product_id) {
        this.product_id = product_id;
    }

    public bool open_device() {
        // --- MODALITÀ DEBUG ---
        if (this.debug_mode) {
            try {
                var file = File.new_for_path("brother_dump.bin");
                // Sostituisce il file se esiste
                this.debug_stream = file.replace(null, false, FileCreateFlags.NONE);
                stdout.printf("[DEBUG] Modalità simulazione attiva.\n");
                stdout.printf("[DEBUG] I comandi verranno salvati in 'brother_dump.bin'\n");
                return true; // Simuliamo una connessione riuscita
            } catch (GLib.Error e) {
                stderr.printf("Errore apertura file debug: %s\n", e.message);
                return false;
            }
        }

        // --- MODALITÀ REALE (USB) ---
        int r = Context.init(out ctx);
        if (r < 0) return false;

        this.handle = ctx.open_device_with_vid_pid(VENDOR_ID, this.product_id);
        if (this.handle == null) {
            stderr.printf("Stampante non trovata.\n");
            return false;
        }

        if (this.handle.kernel_driver_active(0) == 1) {
            this.handle.detach_kernel_driver(0);
        }

        if (this.handle.claim_interface(0) != 0) return false;
        if (!find_bulk_out_endpoint()) return false;

        return true;
    }

    private bool find_bulk_out_endpoint() {
        Device device = this.handle.get_device();
        ConfigDescriptor config;
        if (device.get_active_config_descriptor(out config) != 0) return false;

        for (int i = 0; i < config.interface.length; i++) {
            var iface_desc = config.interface[i].altsetting[0];
            for (int e = 0; e < iface_desc.endpoint.length; e++) {
                var ep = iface_desc.endpoint[e];
                bool is_out = (ep.bEndpointAddress & EndpointDirection.IN) == 0;
                bool is_bulk = ((int)ep.bmAttributes & 0x03) == 2; 
                if (is_out && is_bulk) {
                    this.endpoint_out = ep.bEndpointAddress;
                    return true;
                }
            }
        }
        return false;
    }

    private void send_bytes(uint8[] data) throws GLib.Error {
        // --- DIRAMAZIONE DEBUG ---
        if (this.debug_mode) {
            if (this.debug_stream != null) {
                size_t bytes_written;
                this.debug_stream.write_all(data, out bytes_written);
                stdout.printf("[DEBUG] Scritti %lu bytes su file.\n", bytes_written);
            }
            return;
        }

        // --- DIRAMAZIONE USB ---
        if (handle == null) throw new IOError.NOT_CONNECTED("Non connesso");
        int transferred = 0;
        int r = this.handle.bulk_transfer(this.endpoint_out, data, out transferred, 5000);
        if (r != 0) throw new IOError.FAILED(@"USB Error: $r");
    }

    public void close() {
        if (this.debug_mode) {
            // Chiudiamo il file stream
            if (this.debug_stream != null) {
                try {
                    this.debug_stream.close();
                    stdout.printf("[DEBUG] File chiuso correttamente.\n");
                } catch (GLib.Error e) {
                    stderr.printf("Errore chiusura file: %s\n", e.message);
                }
                this.debug_stream = null;
            }
        } else {
            // Chiudiamo USB
            if (handle != null) {
                handle.release_interface(0);
                handle = null;
            }
        }
    }

    private void set_label_info(LabelConfig config, int raster_height) throws GLib.Error {
        var cmd = new ByteArray();
        cmd.append({0x1b, 0x69, 0x7a}); 
        cmd.append({0x86}); 
        uint8 media_type = config.is_continuous ? 0x0a : 0x0b;
        cmd.append({media_type});
        cmd.append({(uint8)config.width_mm});
        cmd.append({(uint8)config.label_length_mm});
        uint32 rh = (uint32)raster_height;
        cmd.append({(uint8)(rh & 0xFF), (uint8)((rh >> 8) & 0xFF), (uint8)((rh >> 16) & 0xFF), (uint8)((rh >> 24) & 0xFF)});
        cmd.append({0x00, 0x00});
        send_bytes(cmd.data);
    }

    public void print_image(string image_path, LabelConfig config) {
        try {
            var pixbuf = new Pixbuf.from_file(image_path);
            int img_width = pixbuf.get_width();
            int height = pixbuf.get_height();
            int channels = pixbuf.get_n_channels();
            int rowstride = pixbuf.get_rowstride();
            unowned uint8[] pixels = pixbuf.get_pixels();

            int fixed_raster_bytes = 16; 

            stdout.printf("Elaborazione: %dx%d (Debug: %s)\n", img_width, height, this.debug_mode.to_string());

            // 1. Invalidate (100 byte)
            uint8[] clear = {};
            for(int i=0; i<100; i++) clear += 0x00; 
            send_bytes(clear);

            // 2. Init & Raster Mode
            send_bytes({0x1b, 0x40});
            send_bytes({0x1b, 0x69, 0x61, 0x01});

            // 3. Setup
            set_label_info(config, height);

            // 4. Dati
            send_bytes({0x47});
            for (int y = 0; y < height; y++) {
                var line_buffer = new ByteArray();

                for (int i = 0; i < fixed_raster_bytes; i++) {
                    uint8 byte_val = 0;
                    for (int bit = 0; bit < 8; bit++) {
                        int target_x = i * 8 + bit;
                        if (target_x < img_width) {
                            int p_index = y * rowstride + target_x * channels;
                            if ((pixels[p_index] + pixels[p_index+1] + pixels[p_index+2]) / 3 < 128) {
                                byte_val |= (uint8)(1 << (7 - bit)); 
                            }
                        }
                    }
                    line_buffer.append({byte_val});
                }
                send_bytes(line_buffer.data);
            }

            // 5. End
            send_bytes({0x1a}); 
            
            stdout.printf("Operazione completata.\n");

        } catch (GLib.Error e) {
            stderr.printf("Errore: %s\n", e.message);
        }
    }
}

// --- MAIN AGGIORNATO ---
int main(string[] args) {
    // Parsing argomenti manuale per supportare il flag opzionale
    string? pid_arg = null;
    string? img_arg = null;
    bool debug_flag = false;

    // Saltiamo args[0] (nome programma)
    for (int i = 1; i < args.length; i++) {
        if (args[i] == "--debug" || args[i] == "-d") {
            debug_flag = true;
        } else if (pid_arg == null) {
            pid_arg = args[i];
        } else if (img_arg == null) {
            img_arg = args[i];
        }
    }

    if (pid_arg == null || img_arg == null) {
        stdout.printf("Uso: %s [--debug] <PID_HEX> <IMG>\n", args[0]);
        stdout.printf("Esempio USB:   %s 2042 test.png\n", args[0]);
        stdout.printf("Esempio DEBUG: %s --debug 2042 test.png\n", args[0]);
        return 1;
    }

    int pid_val;
    pid_arg.scanf("%x", out pid_val);
    
    var printer = new BrotherPrinterUSB((uint16)pid_val);
    printer.debug_mode = debug_flag; // Attivazione flag

    var config = LabelConfig() {
        width_mm = 24,          
        is_continuous = true,   
        label_length_mm = 0     
    };

    if (printer.open_device()) {
        printer.print_image(img_arg, config);
        printer.close();
    }

    return 0;
}
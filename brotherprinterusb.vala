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

    public BrotherPrinterUSB(uint16 product_id) {
        this.product_id = product_id;
    }

    public bool open_device() {
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
        if (handle == null) throw new IOError.NOT_CONNECTED("Non connesso");
        int transferred = 0;
        int r = this.handle.bulk_transfer(this.endpoint_out, data, out transferred, 5000);
        if (r != 0) throw new IOError.FAILED(@"USB Error: $r");
    }

    public void close() {
        if (handle != null) {
            handle.release_interface(0);
            handle = null;
        }
    }

    private void set_label_info(LabelConfig config, int raster_height) throws GLib.Error {
        var cmd = new ByteArray();
        
        // Header
        cmd.append({0x1b, 0x69, 0x7a}); 
        // Flag (Raster Number valid)
        cmd.append({0x86}); 
        // Media Type
        uint8 media_type = config.is_continuous ? 0x0a : 0x0b;
        cmd.append({media_type});
        // Width
        cmd.append({(uint8)config.width_mm});
        // Length
        cmd.append({(uint8)config.label_length_mm});
        // Raster Number (Height)
        uint32 rh = (uint32)raster_height;
        cmd.append({(uint8)(rh & 0xFF), (uint8)((rh >> 8) & 0xFF), (uint8)((rh >> 16) & 0xFF), (uint8)((rh >> 24) & 0xFF)});
        // Page / Reserved
        cmd.append({0x00, 0x00});

        send_bytes(cmd.data);
    }

    public void print_image(string image_path, LabelConfig config) {
        try {
            // --- Fase 0: Preparazione Immagine ---
            var pixbuf = new Pixbuf.from_file(image_path);
            int img_width = pixbuf.get_width();
            int height = pixbuf.get_height();
            int channels = pixbuf.get_n_channels();
            int rowstride = pixbuf.get_rowstride();
            unowned uint8[] pixels = pixbuf.get_pixels();

            // CORREZIONE RICHIESTA: Forza 16 byte (128 pixel) di larghezza raster
            int fixed_raster_bytes = 16; 

            stdout.printf("Stampa: Input %dx%d -> Raster fisso %d byte/riga\n", img_width, height, fixed_raster_bytes);

            // --- Fase 1: Inizializzazione ---
            
            // CORREZIONE RICHIESTA: Invalidate esatto a 100 byte
            uint8[] clear = {};
            for(int i=0; i<100; i++) clear += 0x00; 
            send_bytes(clear);

            // Initialize
            send_bytes({0x1b, 0x40});

            // Raster Mode
            send_bytes({0x1b, 0x69, 0x61, 0x01});

            // --- Fase 2: Setup Info Carta ---
            set_label_info(config, height);

            // --- Fase 3: Invio Dati Raster ---
            for (int y = 0; y < height; y++) {
                var line_buffer = new ByteArray();
                
                // Comando 'G' + 16 (Low) + 0 (High)
                // CORREZIONE RICHIESTA: Length hardcoded a 16 byte
                line_buffer.append({0x47, 0x10, 0x00}); 

                for (int i = 0; i < fixed_raster_bytes; i++) {
                    uint8 byte_val = 0;
                    for (int bit = 0; bit < 8; bit++) {
                        // Calcoliamo la coordinata X assoluta che stiamo scrivendo
                        int target_x = i * 8 + bit;
                        
                        // Prendiamo il pixel solo se rientra nell'immagine originale
                        if (target_x < img_width) {
                            int p_index = y * rowstride + target_x * channels;
                            // Soglia B/N
                            if ((pixels[p_index] + pixels[p_index+1] + pixels[p_index+2]) / 3 < 128) {
                                byte_val |= (uint8)(1 << (7 - bit)); 
                            }
                        }
                        // Se target_x >= img_width, il bit rimane 0 (bianco) -> Padding automatico
                    }
                    line_buffer.append({byte_val});
                }
                send_bytes(line_buffer.data);
            }

            // --- Fase 4: Chiusura ---
            send_bytes({0x1a}); // Print with feeding
            
            stdout.printf("Dati inviati.\n");

        } catch (GLib.Error e) {
            stderr.printf("Errore stampa: %s\n", e.message);
        }
    }
}

int main(string[] args) {
    if (args.length < 3) {
        stdout.printf("Uso: %s <PID_HEX> <IMG>\n", args[0]);
        return 1;
    }

    int pid_val;
    args[1].scanf("%x", out pid_val);
    string img = args[2];

    var printer = new BrotherPrinterUSB((uint16)pid_val);

    var config = LabelConfig() {
        width_mm = 24,          
        is_continuous = true,   
        label_length_mm = 0     
    };

    if (printer.open_device()) {
        printer.print_image(img, config);
        printer.close();
    }

    return 0;
}

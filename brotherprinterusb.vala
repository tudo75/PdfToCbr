using GLib;
using Gdk;
using LibUSB;

// Configurazione per il tipo di etichetta
public struct LabelConfig {
    public int width_mm;      // Es. 24, 62, 29
    public bool is_continuous; // true per nastro continuo, false per etichette pre-tagliate (Die-Cut)
    public int label_length_mm; // 0 per continuo, altrimenti lunghezza etichetta
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

    // --- Connessione USB (Invariata rispetto a prima) ---
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
                bool is_bulk = ((int)ep.bmAttributes & 0x03) == (int)TransferType.BULK;

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

    // --- NUOVO: Impostazione Formato Carta (ESC i z) ---
    private void set_label_info(LabelConfig config) throws GLib.Error {
        // Protocollo Brother 'Print Information Command' (ESC i z)
        // Bytes: 1B 69 7A [Flags] [MediaType] [Width] [Length] ...
        
        var cmd = new ByteArray();
        cmd.append({0x1b, 0x69, 0x7a}); // Header

        // Flags: 0x80 (validità flag) + bit specifici. 
        // Per semplicità usiamo 0x84 (Flag validità + width/length validi)
        // Alcuni modelli vecchi vogliono 0x86 o 0x00, ma 0x84 è standard QL moderni.
        cmd.append({0x84}); 

        // Media Type: 0x0A = Continuo, 0x0B = Pre-tagliato (Die-Cut)
        uint8 media_type = config.is_continuous ? 0x0a : 0x0b;
        cmd.append({media_type});

        // Width (mm)
        cmd.append({(uint8)config.width_mm});

        // Length (mm): 0 per continuo
        cmd.append({(uint8)config.label_length_mm});

        // 4 byte per Raster number (0,0,0,0 va bene per l'auto-detect su molti modelli)
        // Oppure bisogna calcolare i dati esatti. Lasciamo a 0 per ora.
        cmd.append({0x00, 0x00, 0x00, 0x00});

        // 2 byte finali (Page Num / Reserved)
        cmd.append({0x00, 0x00});

        send_bytes(cmd.data);
    }

    // --- Logica di Stampa Aggiornata ---
    public void print_image(string image_path, LabelConfig config) {
        try {
            // 1. Invalida (buffer clear)
            uint8[] clear = {};
            for(int i=0; i<200; i++) clear += 0x00; 
            send_bytes(clear);

            // 2. Inizializza (ESC @)
            send_bytes({0x1b, 0x40});

            // 3. Switch to Raster Mode (ESC i a 1) - FONDAMENTALE farlo PRIMA di settare la carta
            send_bytes({0x1b, 0x69, 0x61, 0x01});

            // 4. Invia configurazione carta (24mm, Continuo, ecc)
            set_label_info(config);

            // 5. Elaborazione Immagine
            var pixbuf = new Pixbuf.from_file(image_path);
            int width = pixbuf.get_width();
            int height = pixbuf.get_height();
            int channels = pixbuf.get_n_channels();
            int rowstride = pixbuf.get_rowstride();
            unowned uint8[] pixels = pixbuf.get_pixels();

            stdout.printf("Stampa su nastro %dmm (%s): Immagine %dx%d\n", 
                config.width_mm, 
                config.is_continuous ? "Continuo" : "Die-Cut",
                width, height);

            for (int y = 0; y < height; y++) {
                int raster_width_bytes = (width + 7) / 8; 
                var line_buffer = new ByteArray();
                
                line_buffer.append({0x67, 0x00, (uint8)raster_width_bytes}); 

                for (int i = 0; i < raster_width_bytes; i++) {
                    uint8 byte_val = 0;
                    for (int bit = 0; bit < 8; bit++) {
                        int x = i * 8 + bit;
                        if (x < width) {
                            int p_index = y * rowstride + x * channels;
                            // Lettura pixel (converte in bianco/nero)
                            if ((pixels[p_index] + pixels[p_index+1] + pixels[p_index+2]) / 3 < 128) {
                                byte_val |= (uint8)(1 << (7 - bit));
                            }
                        }
                    }
                    line_buffer.append({byte_val});
                }
                send_bytes(line_buffer.data);
            }

            // 6. Stampa finale (Form Feed)
            send_bytes({0x0c});
            
            // Se vuoi tagliare il nastro continuo automaticamente dopo la stampa:
            send_bytes({0x1b, 0x69, 0x43, 0x01}); // ESC i C 1

            stdout.printf("Comando inviato.\n");

        } catch (GLib.Error e) {
            stderr.printf("Errore stampa: %s\n", e.message);
        }
    }
}

// --- Main ---
int main(string[] args) {
    if (args.length < 3) {
        stdout.printf("Uso: %s <PRODUCT_ID_HEX> <IMMAGINE>\n", args[0]);
        return 1;
    }

    int pid_val;
    args[1].scanf("%x", out pid_val);
    uint16 pid = (uint16)pid_val;
    string img = args[2];

    var printer = new BrotherPrinterUSB(pid);

    // DEFINIZIONE CONFIGURAZIONE: 24mm CONTINUO
    var config = LabelConfig() {
        width_mm = 24,          // 24mm
        is_continuous = true,   // Nastro continuo
        label_length_mm = 0     // Ignorato per continuo
    };

    if (printer.open_device()) {
        printer.print_image(img, config);
        printer.close();
    }

    return 0;
}

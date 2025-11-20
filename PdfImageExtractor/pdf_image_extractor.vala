using GLib;
using Poppler;
using Cairo;
using Gdk; // In GTK4 questo fa riferimento a gdk-pixbuf-2.0 per la classe Pixbuf

/**
 * Applicazione per estrarre immagini da un PDF (Compatibile con GTK4/GdkPixbuf).
 */
public class PdfImageExtractor : Object {

    public static int main(string[] args) {
        if (args.length < 3) {
            stderr.printf("Utilizzo: %s <file_input.pdf> <cartella_output> [formato: png|jpg]\n", args[0]);
            return 1;
        }

        string input_path = args[1];
        string output_dir = args[2];
        string format = (args.length > 3) ? args[3].down() : "png";
        if (format == "jpeg") format = "jpg";

        if (format != "png" && format != "jpg") {
            stderr.printf("Errore: Formato '%s' non supportato.\n", format);
            return 1;
        }

        if (!FileUtils.test(input_path, FileTest.EXISTS)) {
            stderr.printf("Errore: Il file '%s' non esiste.\n", input_path);
            return 1;
        }

        if (!FileUtils.test(output_dir, FileTest.IS_DIR)) {
            DirUtils.create_with_parents(output_dir, 0755);
        }

        try {
            File file = File.new_for_path(input_path);
            string uri = file.get_uri();

            var document = new Poppler.Document.from_file(uri, null);
            int n_pages = document.get_n_pages();
            int total_images = 0;

            stdout.printf("Estrazione immagini in corso (%s)...\n", format.up());

            for (int i = 0; i < n_pages; i++) {
                var page = document.get_page(i);
                var image_mapping = page.get_image_mapping();
                int page_img_count = 0;

                foreach (var mapping in image_mapping) {
                    var image_id = mapping.image_id;
                    var surface = page.get_image(image_id);
                    
                    string filename = GLib.Path.build_filename(output_dir, "page_%d_img_%d.%s".printf(i + 1, page_img_count + 1, format));

                    if (format == "png") {
                        surface.write_to_png(filename);
                    } else if (format == "jpg") {
                        // Conversione manuale Surface -> Pixbuf per GTK4/GdkPixbuf
                        var pixbuf = surface_to_pixbuf(surface);
                        
                        if (pixbuf != null) {
                            pixbuf.save(filename, "jpeg", "quality", "90", null);
                        } else {
                            stderr.printf("Warn: Impossibile convertire immagine pagina %d.\n", i + 1);
                        }
                    }

                    page_img_count++;
                    total_images++;
                }
            }

            stdout.printf("Finito! %d immagini salvate in '%s'.\n", total_images, output_dir);

        } catch (GLib.Error e) {
            stderr.printf("Errore: %s\n", e.message);
            return 1;
        }

        return 0;
    }

    /**
     * Converte manualmente una Cairo.Surface in Gdk.Pixbuf.
     * Necessario perché gdk_pixbuf_get_from_surface non esiste in GTK4.
     */
    private static Gdk.Pixbuf? surface_to_pixbuf(Cairo.Surface surface) {
        // Assicuriamoci che sia una ImageSurface
        var img_surface = (Cairo.ImageSurface) surface;
        if (img_surface == null) return null;

        int w = img_surface.get_width();
        int h = img_surface.get_height();
        var format = img_surface.get_format();
        int stride = img_surface.get_stride();
        unowned uint8[] data = img_surface.get_data();

        // Determina se c'è il canale alpha
        bool has_alpha = (format == Cairo.Format.ARGB32);
        
        // Crea un nuovo Pixbuf vuoto
        var pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB, has_alpha, 8, w, h);
        unowned uint8[] pixels = pixbuf.get_pixels();
        int p_stride = pixbuf.get_rowstride();

        // Itera sui pixel per convertire BGRA (Cairo) in RGBA (Pixbuf)
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                // Indici array
                int src_idx = y * stride + x * 4; // Cairo usa sempre 4 byte per ARGB32/RGB24
                int dst_idx = y * p_stride + x * (has_alpha ? 4 : 3);

                // Lettura (Ordine Cairo Little Endian: B-G-R-A)
                uint8 b = data[src_idx];
                uint8 g = data[src_idx + 1];
                uint8 r = data[src_idx + 2];
                uint8 a = (format == Cairo.Format.ARGB32) ? data[src_idx + 3] : 255;

                // Gestione Alpha Pre-moltiplicato (Cairo) -> Non Pre-moltiplicato (Pixbuf)
                if (has_alpha && a > 0 && a < 255) {
                    r = (uint8)(((int)r * 255) / a);
                    g = (uint8)(((int)g * 255) / a);
                    b = (uint8)(((int)b * 255) / a);
                }

                // Scrittura (Ordine Pixbuf: R-G-B-A)
                pixels[dst_idx] = r;
                pixels[dst_idx + 1] = g;
                pixels[dst_idx + 2] = b;
                if (has_alpha) pixels[dst_idx + 3] = a;
            }
        }
        return pixbuf;
    }
}
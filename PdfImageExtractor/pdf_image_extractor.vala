using GLib;
using Poppler;
using Cairo;
using Archive; // Aggiunto per la gestione degli archivi ZIP
using Gdk; // In GTK4 questo fa riferimento a gdk-pixbuf-2.0 per la classe Pixbuf

/**
 * Applicazione per estrarre immagini da un PDF (Compatibile con GTK4/GdkPixbuf).
 */
public class PdfImageExtractor : Object {

    private static string? output_path = null;
    private static string format = "png";

    private const OptionEntry[] options = {
        { "output", 'o', 0, OptionArg.STRING, ref output_path, "Percorso di output (cartella o file .zip/.rar)", "PERCORSO" },
        { "format", 'f', 0, OptionArg.STRING, ref format, "Formato immagine (png o jpg)", "FORMATO" },
        { null }
    };

    public static int main(string[] args) {
        try {
            var context = new GLib.OptionContext ("<file_input.pdf>");
            context.set_summary ("Estrae tutte le immagini da un file PDF.");
            context.add_main_entries (options, null);
            context.parse (ref args);
        } catch (GLib.OptionError e) {
            stderr.printf ("Errore nel parsing delle opzioni: %s\n", e.message);
            stderr.printf ("Esegui '%s --help' per maggiori informazioni.\n", args[0]);
            return 1;
        }

        if (output_path == null) {
            stderr.printf("Errore: l'opzione --output è obbligatoria.\n");
            stderr.printf("Esegui '%s --help' per maggiori informazioni.\n", args[0]);
            return 1;
        }

        if (args.length < 2) {
            stderr.printf("Errore: specificare un file PDF di input.\n");
            stderr.printf("Esegui '%s --help' per maggiori informazioni.\n", args[0]);
            return 1;
        }
        string input_path = args[1];

        string temp_dir = "";
        format = format.down();
        if (format == "jpeg") format = "jpg";

        if (format != "png" && format != "jpg") {
            stderr.printf("Errore: Formato '%s' non supportato.\n", format);
            return 1;
        }

        if (!FileUtils.test(input_path, GLib.FileTest.EXISTS)) {
            stderr.printf("Errore: Il file '%s' non esiste.\n", input_path);
            return 1;
        }

        bool use_zip = output_path.has_suffix(".zip");
        bool use_rar = output_path.has_suffix(".rar");
        string output_dir = output_path;

        if (use_zip || use_rar) {
            // Creiamo una directory temporanea per i file immagine
            // Il modo moderno e sicuro per creare una directory temporanea
            try {
                FileIOStream tmp_tpl;
                temp_dir = File.new_tmp ("pdf_extractor_XXXXXX", out tmp_tpl).get_uri();
                tmp_tpl.close (); // Chiudiamo il file handle, la directory rimane
                DirUtils.create_with_parents(temp_dir, 0755);
                output_dir = temp_dir;
            } catch (GLib.Error e) {
                stderr.printf("Errore nella creazione della cartella temporanea: %s\n", e.message);
                return 1;
            }
        } else if (!FileUtils.test(output_dir, FileTest.IS_DIR)) {
            DirUtils.create_with_parents(output_dir, 0755);
        }

        try {
            File file = File.new_for_path(input_path);
            string uri = file.get_uri();

            var document = new Poppler.Document.from_file(uri, null);
            int n_pages = document.get_n_pages();
            int total_images = 0;

            if (use_zip) stdout.printf("Creazione archivio ZIP (%s)...\n", format.up());
            else if (use_rar) stdout.printf("Creazione archivio RAR (%s)...\n", format.up());
            else stdout.printf("Estrazione immagini in corso (%s)...\n", format.up());

            Archive.Write? archive_writer = new Archive.Write();
            if (use_zip) {
                archive_writer.set_format_zip();
                archive_writer.open_filename (output_path);
            }

            for (int i = 0; i < n_pages; i++) {
                var page = document.get_page(i);
                var image_mapping = page.get_image_mapping();
                int page_img_count = 0;

                foreach (var mapping in image_mapping) {
                    var image_id = mapping.image_id;
                    var surface = page.get_image(image_id);
                    
                    string entry_name = "page_%d_img_%d.%s".printf(i + 1, page_img_count + 1, format);
                    string filename = GLib.Path.build_filename(output_dir, entry_name);

                    if (format == "png") {
                        if (use_zip) {
                            add_surface_to_archive(archive_writer, surface, entry_name);
                        } else {
                            surface.write_to_png(filename);
                        }
                    } else if (format == "jpg") {
                        // Conversione manuale Surface -> Pixbuf per GTK4/GdkPixbuf
                        var pixbuf = surface_to_pixbuf(surface);
                        if (pixbuf != null) {
                            if (use_zip) {
                                add_pixbuf_to_archive(archive_writer, pixbuf, entry_name);
                            } else {
                                pixbuf.save(filename, "jpeg", "quality", "90", null);
                            }
                        } else {
                            stderr.printf("Warn: Impossibile convertire immagine pagina %d.\n", i + 1);
                        }
                    }

                    page_img_count++;
                    total_images++;
                }
            }

            if (use_zip) {
                if (archive_writer != null) archive_writer.close();
                stdout.printf("Finito! %d immagini salvate in '%s'.\n", total_images, output_path);
            } else if (use_rar) {
                create_rar_archive(output_path, temp_dir);
                // Pulizia della cartella temporanea
                remove_files_and_folders(temp_dir);
                
                stdout.printf("Finito! %d immagini salvate in '%s'.\n", total_images, output_path);
            } else {
                stdout.printf("Finito! %d immagini salvate in '%s'.\n", total_images, output_dir);
            }

        } catch (GLib.Error e) {
            stderr.printf("Errore: %s\n", e.message);
            return 1;
        }

        return 0;
    }

    /*
    Function to remove all files and folders from a given directory.
    Parameters:
    - folder_path: string
        The path of the folder from which all files and folders should be removed.

    Returns:
    - None

    Throws:
    - Error:
        If there is an error while removing the files and folders, an error will be thrown.
    */
    private static void remove_files_and_folders(string folderpath) {
        try {
            var dir = File.new_for_path(folderpath);

            // Cancellazione ricorsiva dei file e della cartella temporanea
            var enumerator = dir.enumerate_children("standard::name", FileQueryInfoFlags.NONE);
            FileInfo? child;
            while ((child = enumerator.next_file()) != null) { 
                // Checking if the current item is a file or a folder
                if (child.get_file_type() == GLib.FileType.REGULAR) {
                    // Removing the file
                    var tmp_file = dir.get_child(child.get_name());
                    tmp_file.delete();
                } else if (child.get_file_type() == GLib.FileType.DIRECTORY) {
                    // Removing the folder recursively
                    var subfolder = dir.get_child(child.get_name());
                    remove_files_and_folders(subfolder.get_path());
                    subfolder.delete();
                }
            }
            
            dir.delete();
        } catch (GLib.Error e) {
            stderr.printf("Warn: Impossibile eliminare la cartella temporanea '%s': %s\n", folderpath, e.message);
        }
    }

    /**
     * Aggiunge una Cairo.Surface (come PNG) a un archivio libarchive.
     */
    private static void add_surface_to_archive(Archive.Write? writer, Cairo.Surface surface, string entry_name) {
        try {
            // Usa un flusso in memoria per ottenere i dati del PNG
            MemoryOutputStream stream = new MemoryOutputStream(null);
            surface.write_to_png_stream((data) => {
                try {
                    stream.write(data);
                    return Cairo.Status.SUCCESS;
                }  catch (GLib.IOError e) {
                    stderr.printf("Errore durante l'aggiunta di '%s' all'archivio: %s\n", entry_name, e.message);
                    return Cairo.Status.WRITE_ERROR;
                }
            });
            stream.close();

            // Converte il flusso in un array di byte
            var bytes = stream.steal_data();
            
            // Aggiunge i dati all'archivio
            var entry = new Archive.Entry();
            entry.set_pathname(entry_name);
            entry.set_size(bytes.length);
            entry.set_filetype(Archive.FileType.IFREG);
            entry.set_perm(0644);

            if (writer.write_header (entry) != Archive.Result.OK) {
                critical ("Error writing '%s'", entry_name);
            }

            // Add the actual content of the file
            writer?.write_data(bytes);
        } catch (GLib.Error e) {
            stderr.printf("Errore durante l'aggiunta di '%s' all'archivio: %s\n", entry_name, e.message);
        }
    }

    /**
     * Aggiunge un Gdk.Pixbuf (come JPG) a un archivio libarchive.
     */
    private static void add_pixbuf_to_archive(Archive.Write? writer, Gdk.Pixbuf pixbuf, string entry_name) {
        try {
            // Salva il pixbuf in un buffer di memoria come JPEG
            uint8[] buffer;
            pixbuf.save_to_buffer(out buffer, "jpeg", "quality", "90");

            // Aggiunge i dati all'archivio
            var entry = new Archive.Entry();
            entry.set_pathname(entry_name);
            entry.set_size(buffer.length);
            entry.set_filetype(Archive.FileType.IFREG);
            entry.set_perm(0644);

            if (writer.write_header (entry) != Archive.Result.OK) {
                critical ("Error writing '%s'", entry_name);
            }

            // Add the actual content of the file
            writer?.write_data(buffer);

        } catch (GLib.Error e) {
            stderr.printf("Errore durante l'aggiunta di '%s' all'archivio: %s\n", entry_name, e.message);
        }
    }

    /**
     * Crea un archivio RAR usando il comando 'rar' esterno.
     */
    private static void create_rar_archive(string archive_path, string source_dir) {
        try {
            string[] argv = {"rar", "a", "-ep1", "-o+", archive_path, source_dir + "/*"};
            string? stdout_str, stderr_str;
            Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_str, out stderr_str);
            
            if (stderr_str != null && stderr_str.length > 0) {
                stdout.printf("%s\n", stderr_str);
            }
        } catch (SpawnError e) {
            stderr.printf("Errore nell'eseguire il comando 'rar'. Assicurati che sia installato e nel PATH.\n");
            stderr.printf("Dettagli: %s\n", e.message);
        }
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
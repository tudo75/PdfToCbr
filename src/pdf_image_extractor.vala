/**
 * pdf_image_extractor.vala
 *
 * Copyright 2025 Nicola tudo75 Tudino
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Poppler;
using Cairo;
using Archive; // Added for ZIP archives handling
using Gdk; // In GTK4 it refers to gdk-pixbuf-2.0 for Pixbuf class

namespace PdfToCbr {
    /**
     * Logic class to extract images from a PDF file.
     * Images extracted can be svaed in a folder or as CBZ/CBR file
     * Emit signals to notify progress, completion or errors,
     * make it usable by GUI or CLI apps.
     */
    public class PdfImageExtractor : Object {

        /**
         * Signal emitted during extraction to notify the progress.
         * @param current_page Current working page.
         * @param total_pages Total pages number in the PDF file.
         * @param message Description message to be displayed.
         * 
         * @since 0.0.1
         */
        public signal void progress(int current_page, int total_pages, string message);

        /**
         * Signal emitted on successfully completion of extraction.
         * @param total_images Total number of extracted images.
         * @param output_path Utput path of the file or of the extraction folder.
         * 
         * @since 0.0.1
         */
        public signal void finished(int total_images, string output_path);

        /**
         * Signal emitted in case of error during extraction.
         * @param message Error message.
         * 
         * @since 0.0.1
         */
        public signal void error(string message);

        /**
         * Signal emitted in case of warning during extraction.
         * @param message Warning message.
         * 
         * @since 0.0.1
         */
        public signal void warning(string message);

        public PdfImageExtractor() {
            Object();
        }

        /**
         * Function to extract images from a PDF file.
         * Images extracted can be svaed in a folder or as CBZ/CBR file
         * @param input_path The path of the PDF file to be extracted.
         * @param output_path The path of the CBZ/CBR file or folder where images must be saved.
         * @param format Iamge format of the extracted images.
         * 
         * @since 0.0.1
         */
        public void extract_images(string input_path, string output_path, string format) {
            try {
                _do_extraction(input_path, output_path, format);
            } catch (GLib.Error e) {
                error(e.message);
            }
        }

        /**
         * Function to extract images from a PDF file.
         * Images extracted can be svaed in a folder or as CBZ/CBR file
         * @param input_path The path of the PDF file to be extracted.
         * @param final_output_path The path of the CBZ/CBR file or folder where images must be saved.
         * @param format Iamge format of the extracted images.
         * 
         * @throws GLib.Error If there is an error while extracting images,an error will be thrown.
         * 
         * @since 0.0.1
         */
        private void _do_extraction(string input_path, string final_output_path, string format) throws GLib.Error {
            bool use_zip = final_output_path.has_suffix(".cbz");
            bool use_rar = final_output_path.has_suffix(".cbr");

            string temp_dir_path = "";
            string work_dir = final_output_path;

            if (use_zip || use_rar) {
                temp_dir_path = GLib.DirUtils.make_tmp("pdf_extractor_XXXXXX");
                work_dir = temp_dir_path;
            } else if (!FileUtils.test(work_dir, FileTest.IS_DIR)) {
                DirUtils.create_with_parents(work_dir, 0755);
            }

            File file = File.new_for_path(input_path);
            var document = new Poppler.Document.from_file(file.get_uri(), null);
            int n_pages = document.get_n_pages();
            int total_images = 0;

            progress(0, n_pages, _("Start extraction..."));

            Archive.Write? archive_writer = null;
            if (use_zip) {
                archive_writer = new Archive.Write();
                archive_writer.set_format_zip();
                archive_writer.open_filename(final_output_path);
            }

            for (int i = 0; i < n_pages; i++) {
                progress(i, n_pages, _("Page %d of %d...").printf(i + 1, n_pages));
                var page = document.get_page(i);
                var image_mapping = page.get_image_mapping();
                int page_img_count = 0;

                foreach (var mapping in image_mapping) {
                    var image_id = mapping.image_id;
                    var surface = page.get_image(image_id);
                    
                    string entry_name = "page_%d_img_%d.%s".printf(i + 1, page_img_count + 1, format);
                    string filename = GLib.Path.build_filename(work_dir, entry_name);

                    if (format == "png") {
                        if (use_zip) {
                            add_surface_to_archive(archive_writer, surface, entry_name);
                        } else {
                            surface.write_to_png(filename);
                        }
                    } else if (format == "jpg") {
                        var pixbuf = surface_to_pixbuf(surface);
                        if (pixbuf != null) {
                            if (use_zip) {
                                add_pixbuf_to_archive(archive_writer, pixbuf, entry_name);
                            } else {
                                pixbuf.save(filename, "jpeg", "quality", "100", null);
                            }
                        } else {
                            warning(_("Impossible conversion of image at page %d.").printf(i + 1));
                        }
                    }

                    page_img_count++;
                    total_images++;
                }
            }

            if (use_zip) {
                if (archive_writer != null) archive_writer.close();
            } else if (use_rar) {
                create_rar_archive(final_output_path, work_dir);
            }

            // Pulizia della cartella temporanea se usata
            if (temp_dir_path != "") {
                remove_files_and_folders(temp_dir_path);
            }

            finished(total_images, final_output_path);
        }

        /**
         * Recursive deletion function for temporary folder and files.
         * @param folderpath The path of the temporary folder.
         * 
         * @since 0.0.1
         */
        private void remove_files_and_folders(string folderpath) {
            try {
                var dir = File.new_for_path(folderpath);

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
                warning(_("Impossible to delete the temporary folder '%s': %s").printf(folderpath, e.message));
            }
        }

        /**
         * Add a Cairo.Surface (as PNG) to a libarchive output file.
         * @param writer The achive file writer.
         * @param surface The Cairo.Surface to be saved as PNG.
         * @param entry_name The PNG file name.
         * 
         * @since 0.0.1
         */
        private void add_surface_to_archive(Archive.Write? writer, Cairo.Surface surface, string entry_name) {
            try {
                // Use memory stream to obtain PNG data
                MemoryOutputStream stream = new MemoryOutputStream(null);
                surface.write_to_png_stream((data) => {
                    try {
                        stream.write(data);
                        return Cairo.Status.SUCCESS;
                    }  catch (GLib.IOError e) {
                        warning(_("I/O error writing '%s' to memory: %s").printf(entry_name, e.message));
                        return Cairo.Status.WRITE_ERROR;
                    }
                });
                stream.close();

                // Convert the stream in a byte array
                var bytes = stream.steal_data();
                
                // Aggiunge i dati all'archivio
                var entry = new Archive.Entry();
                entry.set_pathname(entry_name);
                entry.set_size(bytes.length);
                entry.set_filetype(Archive.FileType.IFREG);
                entry.set_perm(0644);

                if (writer.write_header (entry) != Archive.Result.OK) {
                    error(_("Error writing %s header").printf(entry_name));
                }

                // Add the actual content of the file
                writer?.write_data(bytes);
            } catch (GLib.Error e) {
                warning(_("Error adding '%s' to the archve %s").printf(entry_name, e.message));
            }
        }

        /**
         * Add a Gdk.Pixbuf (as JPG) to a libarchive output file.
         * @param writer The achive file writer.
         * @param pixbuf The Gdk.Pixbuf to be saved as JPG.
         * @param entry_name The JPG file name.
         * 
         * @since 0.0.1
         */
        private void add_pixbuf_to_archive(Archive.Write? writer, Gdk.Pixbuf pixbuf, string entry_name) {
            try {
                // Save pixbuf in a memory buffer as JPG
                uint8[] buffer;
                pixbuf.save_to_buffer(out buffer, "jpeg", "quality", "90");

                // Add data to the archive
                var entry = new Archive.Entry();
                entry.set_pathname(entry_name);
                entry.set_size(buffer.length);
                entry.set_filetype(Archive.FileType.IFREG);
                entry.set_perm(0644);

                if (writer.write_header (entry) != Archive.Result.OK) {
                    error(_("Error writing %s header").printf(entry_name));
                }

                // Add the actual content of the file
                writer?.write_data(buffer);

            } catch (GLib.Error e) {
                warning(_("Error adding '%s' to the archve %s").printf(entry_name, e.message));
            }
        }

        /**
         * Create a CBR archive using the external 'rar' command.
         * @param archive_path The path of the CBR file.
         * @param source_dir The Path of the folder containing the extracted images to be added to the CBR archive.
         * 
         * @since 0.0.1
         */
        private void create_rar_archive(string archive_path, string source_dir) {
            try {
                string[] argv = {"rar", "a", "-ep1", "-o+", archive_path, source_dir + "/*"};
                string? stdout_str, stderr_str;
                Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_str, out stderr_str);
                
                if (stderr_str != null && stderr_str.length > 0 && !stderr_str.contains("Ok")) {
                    GLib.error("%s", stderr_str);
                }
            } catch (SpawnError e) {
                error(_("Error executing the 'rar' command. Check that the rar package is installed and the executable is in PATH.\n Details: %s").printf(e.message));
            }
        }

        /**
         * Convert a Cairo.Surface to a Gdk.Pixbuf.
         * Necessary because gdk_pixbuf_get_from_surface doesn't exist in GTK4.
         * @param surface The Cairo.Surface to be converted.
         * 
         * @since 0.0.1
         */
        private static Gdk.Pixbuf? surface_to_pixbuf(Cairo.Surface surface) {
            var img_surface = (Cairo.ImageSurface) surface;
            if (img_surface == null) return null;

            int w = img_surface.get_width();
            int h = img_surface.get_height();
            var format = img_surface.get_format();
            int stride = img_surface.get_stride();
            unowned uint8[] data = img_surface.get_data();

            // Check if the image has alpha
            bool has_alpha = (format == Cairo.Format.ARGB32);
            
            // Create an empty Pixbuf
            var pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB, has_alpha, 8, w, h);
            unowned uint8[] pixels = pixbuf.get_pixels();
            int p_stride = pixbuf.get_rowstride();

            // Iterate over the pixels to convert BGRA (Cairo) to RGBA (Pixbuf)
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    // Array indexes
                    int src_idx = y * stride + x * 4; // Cairo always use 4 byte for ARGB32/RGB24
                    int dst_idx = y * p_stride + x * (has_alpha ? 4 : 3);

                    // Reading (Cairo Little Endian sequence: B-G-R-A)
                    uint8 b = data[src_idx];
                    uint8 g = data[src_idx + 1];
                    uint8 r = data[src_idx + 2];
                    uint8 a = (format == Cairo.Format.ARGB32) ? data[src_idx + 3] : 255;

                    // Alpha handling Pre-multiplied (Cairo) -> Not Pre-multiplied (Pixbuf)
                    if (has_alpha && a > 0 && a < 255) {
                        r = (uint8)(((int)r * 255) / a);
                        g = (uint8)(((int)g * 255) / a);
                        b = (uint8)(((int)b * 255) / a);
                    }

                    // Writing (Pixbuf sequence: R-G-B-A)
                    pixels[dst_idx] = r;
                    pixels[dst_idx + 1] = g;
                    pixels[dst_idx + 2] = b;
                    if (has_alpha) pixels[dst_idx + 3] = a;
                }
            }
            return pixbuf;
        }
    }
}
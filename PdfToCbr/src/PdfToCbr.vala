using GLib;
using Posix;

class PdfToCbr {
    static void delete_folder_recursively(File folder) {
        try {
            FileEnumerator enumerator = folder.enumerate_children(FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
            FileInfo info;

            while ((info = enumerator.next_file()) != null) {
                File child = folder.get_child(info.get_name());

                if (info.get_file_type() == FileType.DIRECTORY) {
                    delete_folder_recursively(child);
                } else {
                    child.delete();
                }
            }

            folder.delete();
            GLib.print("Deleted folder: %s\n", folder.get_path());
        } catch (Error e) {
            GLib.stderr.printf("Error: failed deleting folder: %s\n", e.message);
        }
    }

    public static int main (string[] args) {
        if (args.length != 2) {
            GLib.stderr.printf ("Usage: %s <input.pdf>\n", args[0]);
            return 1;
        }

        string pdf_file = args[1];

        if (!pdf_file.has_suffix (".pdf")) {
            GLib.stderr.printf ("Error: Input file is not a PDF.\n");
            return 1;
        }

        File file = File.new_for_path (pdf_file);
        
        if (!file.query_exists ()) {
            GLib.stderr.printf ("Error: File does not exist.\n");
            return 1;
        }

        int status = 0;

        try {
            if (Process.spawn_sync (null, { "sh", "-c", "command -v pdfimages" }, null, SpawnFlags.SEARCH_PATH, null, null, null, out status) && status != 0) {
                GLib.stderr.printf ("Error: pdfimages is not installed. Install poppler-utils.\n");
                return 1;
            }
            if (Process.spawn_sync (null, { "sh", "-c", "command -v rar || command -v zip" }, null, SpawnFlags.SEARCH_PATH, null, null, null, out status) && status != 0) {
                GLib.stderr.printf ("Error: Neither rar nor zip is installed. Install one of them to create a CBR file.\n");
                return 1;
            }
        } catch (GLib.SpawnError e) {
            GLib.stderr.printf ("Warning: Failed to check dependencies: %s\n", e.message);
        }

        string pdf_dir = Path.get_dirname (pdf_file);
        string base_name = Path.get_basename (pdf_file).replace (".pdf", "");
        string output_dir = Path.build_filename (pdf_dir, base_name);
        string cbr_file = Path.build_filename (pdf_dir, base_name);

        try {
            GLib.File.new_for_path (output_dir).make_directory_with_parents ();
        } catch (Error e) {
            GLib.stderr.printf ("Error creating output directory: %s\n", e.message);
            return 1;
        }

        if (Posix.system ("pdfimages -all '" + pdf_file + "' '" + output_dir + "/image'") != 0) {
            GLib.stderr.printf ("Error: Failed to extract images from PDF.\n");
            return 1;
        }

        try {
            if (Process.spawn_sync (null, { "sh", "-c", "command -v rar" }, null, SpawnFlags.SEARCH_PATH, null, null, null, out status) && status == 0) {
                string command = "rar a -r '" + cbr_file + ".cbr' '" + output_dir + "/*'";
                Posix.system (command);
            } else {
                string command = "zip -r '" + cbr_file + ".cbz' '" + output_dir + "'";
                Posix.system (command);
            }
        } catch (GLib.SpawnError e) {
            GLib.stderr.printf ("Warning: Failed to create archive: %s\n", e.message);
        }

        File output = File.new_for_path (output_dir);
        delete_folder_recursively (output);

        GLib.stdout.printf ("CBR file created in the same directory as the PDF: %s.cbr\n", cbr_file);
        return 0;
    }
}
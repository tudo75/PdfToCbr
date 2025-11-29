using GLib;

/**
 * Eseguibile da riga di comando per l'applicazione PdfImageExtractor.
 */
public class PdfImageExtractorCli {

    private static string? output_path = null;
    private static string format = "png";
    private const string dest_desc = "Output path (folder or file .cbz/.cbr)";
    private const string dest_placeholder = "PATH";
    private const string format_desc = "Formato immagine (png o jpg)";
    private const string format_placeholder = "IMAGE_FORMAT";

    private const OptionEntry[] options = {
        { "output", 'o', 0, OptionArg.STRING, ref output_path, dest_desc, dest_placeholder },
        { "format", 'f', 0, OptionArg.STRING, ref format, format_desc, format_placeholder },
        { null }
    };

    public static int main(string[] args) {
        try {
            var context = new GLib.OptionContext ("<file_input.pdf>");
            context.set_summary (_("Extraxt all images from a PDF file."));
			context.set_help_enabled (true);
            context.add_main_entries (options, Constants.GETTEXT_PACKAGE);
            context.parse (ref args);
        } catch (GLib.OptionError e) {
            stderr.printf (_("Error during options parsing: %s\n"), e.message);
            stderr.printf (_("For more details ececute '%s --help'.\n"), args[0]);
            return 1;
        }

        if (output_path == null) {
            stderr.printf(_("Error: --output option is mandatory.\n"));
            stderr.printf(_("For more details ececute '%s --help'.\n"), args[0]);
            return 1;
        }

        if (args.length < 2) {
            stderr.printf(_("Error: give a PDF input file.\n"));
            stderr.printf(_("For more details ececute '%s --help'.\n"), args[0]);
            return 1;
        }
        string input_path = args[1];

        format = format.down();
        if (format == "jpeg") format = "jpg";

        if (format != "png" && format != "jpg") {
            stderr.printf(_("Error: not supported '%s' format.\n"), format);
            return 1;
        }

        if (!FileUtils.test(input_path, GLib.FileTest.EXISTS)) {
            stderr.printf(_("Error: '%s' file not found.\n"), input_path);
            return 1;
        }

        var extractor = new PdfImageExtractor();

        // Connessione ai segnali per feedback su console
        extractor.progress.connect((current, total, msg) => {
            stdout.printf("\r%s", msg);
        });

        extractor.finished.connect((total_images, out_path) => {
            stdout.printf(_("\nFinished! %d images saved in '%s'.\n"), total_images, out_path);
        });

        extractor.error.connect((msg) => {
            stderr.printf(_("\nError: %s\n"), msg);
        });

        // Esegui l'estrazione
        extractor.extract_images(input_path, output_path, format);

        return 0;
    }
}
using GLib;

/**
 * Eseguibile da riga di comando per l'applicazione PdfImageExtractor.
 */
public class PdfImageExtractorCli {

    private static string? output_path = null;
    private static string format = "png";
    private const string dest_desc = "Percorso di output (cartella o file .cbz/.cbr)";
    private const string dest_placeholder = "PERCORSO";
    private const string format_desc = "Formato immagine (png o jpg)";
    private const string format_placeholder = "FORMATO";

    private const OptionEntry[] options = {
        { "output", 'o', 0, OptionArg.STRING, ref output_path, dest_desc, dest_placeholder },
        { "format", 'f', 0, OptionArg.STRING, ref format, format_desc, format_placeholder },
        { null }
    };

    public static int main(string[] args) {
        try {
            var context = new GLib.OptionContext ("<file_input.pdf>");
            context.set_summary (_("Estrae tutte le immagini da un file PDF."));
			context.set_help_enabled (true);
            context.add_main_entries (options, Constants.GETTEXT_PACKAGE);
            context.parse (ref args);
        } catch (GLib.OptionError e) {
            stderr.printf (_("Errore nel parsing delle opzioni: %s\n"), e.message);
            stderr.printf (_("Esegui '%s --help' per maggiori informazioni.\n"), args[0]);
            return 1;
        }

        if (output_path == null) {
            stderr.printf(_("Errore: l'opzione --output è obbligatoria.\n"));
            stderr.printf(_("Esegui '%s --help' per maggiori informazioni.\n"), args[0]);
            return 1;
        }

        if (args.length < 2) {
            stderr.printf(_("Errore: specificare un file PDF di input.\n"));
            stderr.printf(_("Esegui '%s --help' per maggiori informazioni.\n"), args[0]);
            return 1;
        }
        string input_path = args[1];

        format = format.down();
        if (format == "jpeg") format = "jpg";

        if (format != "png" && format != "jpg") {
            stderr.printf(_("Errore: Formato '%s' non supportato.\n"), format);
            return 1;
        }

        if (!FileUtils.test(input_path, GLib.FileTest.EXISTS)) {
            stderr.printf(_("Errore: Il file '%s' non esiste.\n"), input_path);
            return 1;
        }

        var extractor = new PdfImageExtractor();

        // Connessione ai segnali per feedback su console
        extractor.progress.connect((current, total, msg) => {
            stdout.printf("\r%s", msg);
        });

        extractor.finished.connect((total_images, out_path) => {
            stdout.printf(_("\nFinito! %d immagini salvate in '%s'.\n"), total_images, out_path);
        });

        extractor.error.connect((msg) => {
            stderr.printf(_("\nErrore: %s\n"), msg);
        });

        // Esegui l'estrazione
        extractor.extract_images(input_path, output_path, format);

        return 0;
    }
}
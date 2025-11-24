using GLib;

/**
 * Eseguibile da riga di comando per l'applicazione PdfImageExtractor.
 */
public class PdfImageExtractorCli {

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

        var extractor = new PdfImageExtractor();

        // Connessione ai segnali per feedback su console
        extractor.progress.connect((current, total, msg) => {
            stdout.printf("\r%s", msg);
        });

        extractor.finished.connect((total_images, out_path) => {
            stdout.printf("\nFinito! %d immagini salvate in '%s'.\n", total_images, out_path);
            MainLoop.current().quit();
        });

        extractor.error.connect((msg) => {
            stderr.printf("\nErrore: %s\n", msg);
            MainLoop.current().quit();
        });

        // Esegui l'estrazione
        try {
            extractor.extract_images(input_path, output_path, format);
        } catch (Error e) {
            // L'errore viene già gestito dal segnale 'error'
        }

        // Avvia un MainLoop per attendere i segnali asincroni (anche se qui sono sincroni)
        var loop = new MainLoop();
        loop.run();

        return 0;
    }
}

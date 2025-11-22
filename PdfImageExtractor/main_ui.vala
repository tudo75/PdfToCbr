using Gtk;
using GLib;

/**
 * Finestra principale dell'applicazione con interfaccia GTK4.
 */
public class PdfExtractorWindow : Gtk.ApplicationWindow {

    private Gtk.FileChooserDialog input_file_chooser;
    private Gtk.FileChooserDialog output_path_chooser;
    private Gtk.DropDown format_chooser;
    private Gtk.Button start_button;
    private Gtk.ProgressBar progress_bar;
    private Gtk.Label status_label;
    private Gtk.Spinner spinner;

    // TODO
    // private PdfImageExtractor extractor;

    public PdfExtractorWindow(Gtk.Application app) {
        Object(application: app, title: "PDF Image Extractor");

        //TODO
        // this.extractor = new PdfImageExtractor();

        // TODO --- Connessione segnali dall'estrattore ---
        // extractor.progress.connect(on_extraction_progress);
        // extractor.finished.connect(on_extraction_finished);
        // extractor.error.connect(on_extraction_error);

        // --- Creazione Widget ---
        var grid = new Gtk.Grid() {
            margin_top = 12, margin_bottom = 12,
            margin_start = 12, margin_end = 12,
            row_spacing = 8, column_spacing = 8
        };

        // Input File
        var pdf_filter = new Gtk.FileFilter();
        pdf_filter.name = "File PDF";
        pdf_filter.add_mime_type("application/pdf");

        input_file_chooser = new Gtk.FileChooserDialog("Seleziona un file PDF...", this, Gtk.FileChooserAction.OPEN);
        input_file_chooser.add_filter(pdf_filter);

        // Output Path
        output_path_chooser = new Gtk.FileChooserDialog("Seleziona cartella o file archivio...", this, Gtk.FileChooserAction.SAVE);
        var zip_filter = new Gtk.FileFilter();
        zip_filter.name = "Archivio ZIP";
        zip_filter.add_pattern("*.zip");
        var rar_filter = new Gtk.FileFilter();
        rar_filter.name = "Archivio RAR";
        rar_filter.add_pattern("*.rar");
        
        output_path_chooser.add_filter(zip_filter);
        output_path_chooser.add_filter(rar_filter);

        // Format
        var formats = new string[]{"PNG", "JPG"};
        format_chooser = new Gtk.DropDown.from_strings(formats);

        // Start Button
        start_button = new Gtk.Button.with_label("Estrai Immagini");
        start_button.clicked.connect(on_start_button_clicked);

        // Status widgets
        progress_bar = new Gtk.ProgressBar() { show_text = true, hexpand = true };
        status_label = new Gtk.Label("Pronto.") { halign = Gtk.Align.START };
        spinner = new Gtk.Spinner() { spinning = false, visible = false };

        // --- Layout ---
        grid.attach(new Gtk.Label("File PDF:"), 0, 0, 1, 1);
        grid.attach(input_file_chooser, 1, 0, 1, 1);
        grid.attach(new Gtk.Label("Salva in:"), 0, 1, 1, 1);
        grid.attach(output_path_chooser, 1, 1, 1, 1);
        grid.attach(new Gtk.Label("Formato:"), 0, 2, 1, 1);
        grid.attach(format_chooser, 1, 2, 1, 1);
        
        var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        hbox.append(start_button);
        hbox.append(spinner);
        grid.attach(hbox, 1, 3, 1, 1);

        grid.attach(status_label, 0, 4, 2, 1);
        grid.attach(progress_bar, 0, 5, 2, 1);

        set_child(grid);
        set_default_size(500, -1);
    }

    private void on_start_button_clicked() {
        var input_file = input_file_chooser.get_file();
        var output_file = output_path_chooser.get_file();

        if (input_file == null) {
            show_error_dialog("Errore", "Per favore, seleziona un file PDF di input.");
            return;
        }
        if (output_file == null) {
            show_error_dialog("Errore", "Per favore, seleziona un percorso di output.");
            return;
        }

        string? input_path = input_file.get_path();
        string? output_path = output_file.get_path();
        string format = format_chooser.selected == 0 ? "png" : "jpg";

        // Aggiungi estensione se l'utente non l'ha fatto
        if (output_path != null && !output_path.contains(".") && (output_path_chooser.get_filter().name ?? "").contains("Archivio")) {
             if ((output_path_chooser.get_filter().name ?? "").contains("ZIP")) {
                 output_path += ".zip";
             } else if (output_path_chooser.get_filter().name.contains("RAR")) {
                 output_path += ".rar";
             }
        }

        set_sensitive(false);
        spinner.set_visible(true);
        spinner.start();
        status_label.set_text("Avvio estrazione...");
        progress_bar.set_fraction(0);

        // Esegui l'estrazione in un thread separato per non bloccare la UI
        new Thread<void*>("extractor", () => {
            try {
                //TODO
                // extractor.extract_images(input_path, output_path, format);
            } catch (Error e) {
                // L'errore viene già gestito dal segnale 'error'
            }
            return null;
        });
    }

    private void on_extraction_progress(int current_page, int total_pages, string message) {
        GLib.Idle.add(() => {
            status_label.set_text(message);
            if (total_pages > 0) {
                progress_bar.set_fraction((double)current_page / total_pages);
            }
            return Source.REMOVE;
        });
    }

    private void on_extraction_finished(int total_images, string output_path) {
        GLib.Idle.add(() => {
            set_sensitive(true);
            spinner.stop();
            spinner.set_visible(false);
            status_label.set_text("Finito! %d immagini salvate.".printf(total_images));
            progress_bar.set_fraction(1.0);

            var dialog = new Gtk.MessageDialog(this,
                DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                MessageType.INFO, ButtonsType.OK,
                "Estrazione Completata");
            dialog.secondary_text = "%d immagini sono state salvate con successo in:\n%s".printf(total_images, output_path);
            dialog.response.connect((_, __) => dialog.destroy());
            dialog.show();
            return Source.REMOVE;
        });
    }

    private void on_extraction_error(string message) {
        GLib.Idle.add(() => {
            set_sensitive(true);
            spinner.stop();
            spinner.set_visible(false);
            status_label.set_text("Errore durante l'estrazione.");
            progress_bar.set_fraction(0);
            show_error_dialog("Errore di Estrazione", message);
            return Source.REMOVE;
        });
    }

    private void show_error_dialog(string title, string message) {
        var dialog = new Gtk.MessageDialog(this,
            DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
            MessageType.ERROR, ButtonsType.CLOSE,
            title);
        dialog.secondary_text = message;
        dialog.response.connect((_, __) => dialog.destroy());
        dialog.show();
    }
}

/**
 * Classe principale dell'applicazione GTK.
 */
public class PdfExtractorApp : Gtk.Application {
    public PdfExtractorApp() {
        Object(
            application_id: "com.github.tudo75.pdfimageextractor",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate() {

        base.activate ();
        var window = new PdfExtractorWindow(this);
        //var window = new Gtk.ApplicationWindow (this);
        //window.set_default_size (APP_WIDTH, APP_HEIGHT);
        window.set_resizable (false);

        window.show ();
        window.present ();
    }

    public static int main(string[] args) {
        var app = new PdfExtractorApp();
        return app.run(args);
    }
}
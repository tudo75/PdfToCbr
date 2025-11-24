using Gtk;
using GLib;

public class PdfExtractorApp : Gtk.Application {
    public PdfExtractorApp () {
        Object (application_id: "com.example.pdfextractor", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate () {
        var window = new ExtractorWindow (this);
        window.present ();
    }
}

public class ExtractorWindow : Gtk.ApplicationWindow {
    private Entry input_entry;
    private Entry output_entry;
    private DropDown format_dropdown;
    private DropDown mode_dropdown;
    private ProgressBar progress_bar;
    private Button extract_button;
    private Button output_browse_button;
    private PdfImageExtractor extractor;

    public ExtractorWindow (Gtk.Application app) {
        Object (application: app, title: "Estrattore Immagini PDF");
        this.set_default_size (500, 350);

        var content_box = new Box (Orientation.VERTICAL, 15);
        content_box.margin_top = 20;
        content_box.margin_bottom = 20;
        content_box.margin_start = 20;
        content_box.margin_end = 20;
        this.set_child (content_box);

        // Titolo
        var title_label = new Label ("<span size='x-large' weight='bold'>Estrattore PDF</span>");
        title_label.use_markup = true;
        content_box.append (title_label);

        // Griglia per i controlli
        var grid = new Grid ();
        grid.row_spacing = 10;
        grid.column_spacing = 10;
        grid.halign = Align.CENTER;
        content_box.append (grid);

        // 1. Input PDF
        grid.attach (new Label ("File PDF:"), 0, 0, 1, 1);
        input_entry = new Entry ();
        input_entry.placeholder_text = "Seleziona un PDF...";
        input_entry.hexpand = true;
        input_entry.width_chars = 30;
        grid.attach (input_entry, 1, 0, 1, 1);
        
        var input_btn = new Button.from_icon_name ("document-open-symbolic");
        input_btn.clicked.connect (on_browse_input);
        grid.attach (input_btn, 2, 0, 1, 1);

        // 2. Modalità Output (Cartella, ZIP, RAR)
        grid.attach (new Label ("Tipo Output:"), 0, 1, 1, 1);
        string[] modes = { "Cartella", "Archivio ZIP (.zip)", "Archivio RAR (.rar)" };
        mode_dropdown = new DropDown.from_strings (modes);
        mode_dropdown.notify["selected"].connect (on_mode_changed);
        grid.attach (mode_dropdown, 1, 1, 2, 1);

        // 3. Output Path
        grid.attach (new Label ("Destinazione:"), 0, 2, 1, 1);
        output_entry = new Entry ();
        output_entry.placeholder_text = "Seleziona destinazione...";
        grid.attach (output_entry, 1, 2, 1, 1);

        output_browse_button = new Button.from_icon_name ("document-open-symbolic");
        output_browse_button.clicked.connect (on_browse_output);
        grid.attach (output_browse_button, 2, 2, 1, 1);

        // 4. Formato Immagine
        grid.attach (new Label ("Formato:"), 0, 3, 1, 1);
        string[] formats = { "PNG", "JPG" };
        format_dropdown = new DropDown.from_strings (formats);
        grid.attach (format_dropdown, 1, 3, 2, 1);

        // Progress Bar
        progress_bar = new ProgressBar ();
        progress_bar.show_text = true;
        progress_bar.text = "Pronto";
        content_box.append (progress_bar);

        // Bottone Estrai
        extract_button = new Button.with_label ("Estrai Immagini");
        extract_button.add_css_class ("suggested-action");
        extract_button.clicked.connect (on_extract_clicked);
        content_box.append (extract_button);

        // Istanzia l'estrattore e collega i segnali
        extractor = new PdfImageExtractor();
        extractor.progress.connect(on_extraction_progress);
        extractor.finished.connect(on_extraction_finished);
        extractor.error.connect(on_extraction_error);
    }

    private async void on_browse_input () {
        var dialog = new FileDialog();
        dialog.title = "Seleziona PDF";
        var filter = new FileFilter ();
        filter.add_pattern ("*.pdf");
        filter.name = "Documenti PDF";
        
        var filters = new GLib.ListStore(typeof(FileFilter));
        filters.append(filter);
        dialog.filters = filters;

        try {
            var file = yield dialog.open(this, null);
            input_entry.text = file.get_path();
        } catch (Error e) {} // L'utente ha annullato
    }

    private void on_mode_changed () {
        // Resetta il percorso se cambia la modalità per evitare confusione
        output_entry.text = "";
    }

    private async void on_browse_output () {
        uint selected_mode = mode_dropdown.selected; // 0=Folder, 1=Zip, 2=Rar
        
        FileChooserAction action = (selected_mode == 0) ? FileChooserAction.SELECT_FOLDER : FileChooserAction.SAVE;
        string title = (selected_mode == 0) ? "Seleziona Cartella" : "Salva Archivio";
        
        var dialog = new FileDialog();
        dialog.title = title;

        if (selected_mode == 1) {
            dialog.initial_name = "immagini.zip";
        } else if (selected_mode == 2) {
            dialog.initial_name = "immagini.rar";
        }

        try {
            if (action == FileChooserAction.SAVE) {
                var file = yield dialog.save(this, null);
                output_entry.text = file.get_path();
            } else { // SELECT_FOLDER
                var folder = yield dialog.select_folder(this, null);
                output_entry.text = folder.get_path();
            }
        } catch (Error e) {
            // L'utente ha annullato
        }
    }

    private async void on_extract_clicked () {
        string input_path = input_entry.text;
        string output_path = output_entry.text;
        
        if (input_path == "" || output_path == "") {
            yield show_alert ("Errore", "Seleziona sia il file di input che la destinazione.");
            return;
        }

        string format = (format_dropdown.selected == 0) ? "png" : "jpg";
        //bool is_zip = (mode_dropdown.selected == 1);
        //bool is_rar = (mode_dropdown.selected == 2);

        // UI Update: Disabilita controlli e avvia animazione
        set_inputs_sensitive (false);
        progress_bar.text = "Estrazione in corso...";
        progress_bar.fraction = 0.0;

        // Esegue l'operazione pesante in un thread separato
        new Thread<void> ("extractor_worker", () => {
            // Chiama il metodo corretto sulla classe già istanziata
            extractor.extract_images(input_path, output_path, format);
        });
    }

    private void on_extraction_progress(int current_page, int total_pages, string message) {
        Idle.add(() => {
            progress_bar.text = message;
            if (total_pages > 0) {
                progress_bar.fraction = (double)current_page / total_pages;
            }
            return Source.REMOVE;
        });
    }

    private async void on_extraction_finished(int total_images, string output_path) {
        set_inputs_sensitive(true);
        progress_bar.fraction = 1.0;
        progress_bar.text = "Completato!";
        yield show_alert ("Successo", "Estrazione di %d immagini completata!".printf(total_images));
        return;
    }

    private async void on_extraction_error(string message) {
        set_inputs_sensitive(true);
        progress_bar.fraction = 0;
        progress_bar.text = "Errore";
        yield show_alert("Errore", message);
        return;
    }

    private void set_inputs_sensitive (bool sensitive) {
        input_entry.sensitive = sensitive;
        output_entry.sensitive = sensitive;
        extract_button.sensitive = sensitive;
        format_dropdown.sensitive = sensitive;
        mode_dropdown.sensitive = sensitive;
    }

    private async void show_alert (string title, string message) {
        var dialog = new AlertDialog(title, message);
        dialog.set_buttons({"OK"});
        try {
            yield dialog.choose(this, null);
        } catch (Error e) {} // L'utente ha chiuso il dialogo
    }
}

public static int main (string[] args) {
    var app = new PdfExtractorApp ();
    return app.run (args);
}
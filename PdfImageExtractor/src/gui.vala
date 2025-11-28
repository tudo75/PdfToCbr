using Gtk;
using GLib;

public class PdfExtractorApp : Gtk.Application {
    public const string APP_NAME = Constants.PROJECT_NAME;
    private const string VERSION = Constants.VERSION;
    private const string APP_ID = Constants.APP_ID;
    private const string APP_LANG_DOMAIN = Constants.GETTEXT_PACKAGE;
    private const string APP_INSTALL_PREFIX = Constants.PREFIX;
        
    private Gtk.HeaderBar headerbar;
    private ExtractorWindow window;

    public PdfExtractorApp () {
        Object (application_id: APP_ID, flags: ApplicationFlags.FLAGS_NONE);

        // congfigure i18n localization
        Intl.setlocale (LocaleCategory.ALL, "");
        string langpack_dir = Path.build_filename (APP_INSTALL_PREFIX, "share", "locale");
        Intl.bindtextdomain (APP_LANG_DOMAIN, langpack_dir);
        Intl.bind_textdomain_codeset (APP_LANG_DOMAIN, "UTF-8");
        Intl.textdomain (APP_LANG_DOMAIN);
    }

    protected override void activate () {
        window = new ExtractorWindow (this);
        this.init_headerbar ();
        window.present ();
    }

    /**
        * init_headerbar:
        *
        * #Gtk.HeaderBar constructor for the Application
        */
    private void init_headerbar () {
        headerbar = new Gtk.HeaderBar ();
        headerbar.set_title_widget (new Gtk.Label (APP_NAME));
        headerbar.set_hexpand (true);

        //Gtk.Image logo = new Gtk.Image.from_icon_name (APP_NAME);
        //headerbar.pack_start (logo);
            
        Gtk.Button btn_about = new Gtk.Button.from_icon_name ("help-about-symbolic");
        btn_about.clicked.connect (on_about_action);
        headerbar.pack_start (btn_about);

        window.set_titlebar (headerbar);
    }

    /**
        * about_dialog:
        *
        * Create and display a #Gtk.AboutDialog window.
        */
    private void on_about_action () {
        // Configure the dialog:
        Gtk.AboutDialog dialog = new Gtk.AboutDialog ();
        dialog.set_destroy_with_parent (true);
        dialog.set_transient_for (this.active_window);
        dialog.set_modal (true);

        dialog.set_logo_icon_name (APP_NAME);

        dialog.authors = {"Nicola \"tudo75\" Tudino"};
        //dialog.artists = {"Nicola \"tudo75\" Tudino"};
        dialog.documenters = {"Nicola \"tudo75\" Tudino"};
        //dialog.translator_credits = ("Nicola \"tudo75\" Tudino");

        dialog.program_name = APP_NAME;
        dialog.comments = _("Applicazione per trasformare PDF in CBR o CBZ");
        dialog.copyright = _("Copyright 2025 Nicola \"tudo75\" Tudino");
        dialog.version = VERSION;

        dialog.set_license_type (Gtk.License.GPL_3_0_ONLY);

        dialog.website = "http://github.com/tudo75/PdfToCbr";
        dialog.website_label = "Repository Github";

        // Show the dialog:
        dialog.present ();
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
    private TextView log_view;
    private TextBuffer log_buffer;
    private const int APP_WIDTH = 400; //default 500
    private const int APP_HEIGHT = 450; //default 450

    public ExtractorWindow (Gtk.Application app) {
        Object (application: app, title: _("PdfToCbr"));
        this.set_default_size (APP_WIDTH, APP_HEIGHT);

        Gtk.CssProvider css_provider = new Gtk.CssProvider();
        string csses = """
            progressbar text {
                font-size: 1.2em;
            }
            .red {
                color: #FF5555; 
            }
            .green {
                color: #55FF55; 
            }
        """;
        css_provider.load_from_string (csses);
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

        Box content_box = new Box (Orientation.VERTICAL, 15);
        content_box.margin_top = 20;
        content_box.margin_bottom = 20;
        content_box.margin_start = 20;
        content_box.margin_end = 20;
        this.set_child (content_box);

        // Titolo
        Gtk.Image logo = new Gtk.Image.from_icon_name (PdfExtractorApp.APP_NAME);
        logo.set_pixel_size (128);
        logo.set_size_request (128, 128);
        logo.set_tooltip_text (PdfExtractorApp.APP_NAME);
        content_box.append (logo);


        // Griglia per i controlli
        Grid grid = new Grid ();
        grid.row_spacing = 10;
        grid.column_spacing = 10;
        grid.halign = Align.CENTER;
        content_box.append (grid);

        // 1. Input PDF
        grid.attach (new Label (_("File PDF:")), 0, 0, 1, 1);
        input_entry = new Entry ();
        input_entry.placeholder_text = _("Seleziona un PDF...");
        input_entry.hexpand = true;
        input_entry.width_chars = 30;
        grid.attach (input_entry, 1, 0, 1, 1);
        
        Button input_btn = new Button.from_icon_name ("document-open-symbolic");
        input_btn.clicked.connect (on_browse_input);
        grid.attach (input_btn, 2, 0, 1, 1);

        // 2. Modalità Output (Cartella, ZIP, RAR)
        grid.attach (new Label (_("Tipo Output:")), 0, 1, 1, 1);
        string[] modes = { _("Cartella"), _("Archivio CBZ (.cbz)"), _("Archivio CBR (.cbr)") };
        mode_dropdown = new DropDown.from_strings (modes);
        mode_dropdown.notify["selected"].connect (on_mode_changed);
        grid.attach (mode_dropdown, 1, 1, 2, 1);

        // 3. Output Path
        grid.attach (new Label (_("Destinazione:")), 0, 2, 1, 1);
        output_entry = new Entry ();
        output_entry.placeholder_text = _("Seleziona destinazione...");
        grid.attach (output_entry, 1, 2, 1, 1);

        output_browse_button = new Button.from_icon_name ("document-open-symbolic");
        output_browse_button.clicked.connect (on_browse_output);
        grid.attach (output_browse_button, 2, 2, 1, 1);

        // 4. Formato Immagine
        grid.attach (new Label (_("Formato:")), 0, 3, 1, 1);
        string[] formats = { "PNG", "JPG" };
        format_dropdown = new DropDown.from_strings (formats);
        grid.attach (format_dropdown, 1, 3, 2, 1);

        // Progress Bar
        progress_bar = new ProgressBar ();
        progress_bar.show_text = true;
        progress_bar.text = _("Pronto");
        content_box.append (progress_bar);

        // Bottone Estrai
        extract_button = new Button.with_label (_("Estrai Immagini"));
        extract_button.add_css_class ("suggested-action");
        extract_button.clicked.connect (on_extract_clicked);
        content_box.append (extract_button);

        // Area per i messaggi di log
        ScrolledWindow scrolled_window = new ScrolledWindow ();
        scrolled_window.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scrolled_window.set_size_request (-1, 100);
        scrolled_window.set_has_frame (true);
        scrolled_window.vexpand = true;
        log_view = new TextView ();
        log_view.editable = false;
        log_view.cursor_visible = false;
        log_buffer = log_view.buffer;
        scrolled_window.set_child (log_view);
        content_box.append (scrolled_window);

        // Istanzia l'estrattore e collega i segnali
        extractor = new PdfImageExtractor();
        extractor.progress.connect(on_extraction_progress);
        extractor.finished.connect(on_extraction_finished);
        extractor.error.connect(on_extraction_error);
        extractor.warning.connect(on_extraction_warning);
    }

    private async void on_browse_input () {
        FileDialog dialog = new FileDialog();
        dialog.title = _("Seleziona PDF");
        FileFilter filter = new FileFilter ();
        filter.add_pattern ("*.pdf");
        filter.name = _("Documenti PDF");
        
        GLib.ListStore filters = new GLib.ListStore(typeof(FileFilter));
        filters.append(filter);
        dialog.filters = filters;

        try {
            GLib.File file = yield dialog.open(this, null);
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
        string title = (selected_mode == 0) ? _("Seleziona Cartella") : _("Salva Archivio");
        
        FileDialog dialog = new FileDialog();
        dialog.title = title;

        if (selected_mode == 1) {
            dialog.initial_name = _("immagini.cbz");
        } else if (selected_mode == 2) {
            dialog.initial_name = _("immagini.cbr");
        }

        try {
            if (action == FileChooserAction.SAVE) {
                GLib.File file = yield dialog.save(this, null);
                output_entry.text = file.get_path();
            } else { // SELECT_FOLDER
                GLib.File folder = yield dialog.select_folder(this, null);
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
            log_message("<span foreground=\"#FF5555\">%s</span>".printf (_("Errore: Seleziona sia il file di input che la destinazione.")));
            return; // No need for yield anymore
        }

        string format = (format_dropdown.selected == 0) ? "png" : "jpg";

        // UI Update: Disabilita controlli e avvia animazione
        set_inputs_sensitive (false);
        progress_bar.text = _("Estrazione in corso...");
        progress_bar.fraction = 0.0;
        log_message(_("Avvio estrazione..."));

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

    private void on_extraction_finished(int total_images, string output_path) {
        set_inputs_sensitive(true);
        progress_bar.fraction = 1.0;
        progress_bar.add_css_class("green");
        progress_bar.text = _("Completato!");
        progress_bar.remove_css_class("green");
        log_message("<span foreground=\"#55FF55\">%s</span>".printf(_("Successo: Estrazione di %d immagini completata!").printf(total_images)));
    }

    private void on_extraction_error(string message) {
        set_inputs_sensitive(true);
        progress_bar.fraction = 0;
        progress_bar.add_css_class("red");
        progress_bar.text = _("Errore");
        progress_bar.remove_css_class("red");
        string error_msg = "<span foreground=\"#FF5555\">%s: %s</span>".printf(_("Errore"), message);
        log_message(error_msg);
        error(message); // Log to console as well for debugging
    }

    private void on_extraction_warning(string message) {
        string warning_msg = "<span foreground=\"#ffff00\">%s: %s</span>".printf(_("Warning"), message);
        log_message(warning_msg);
        warning("%s".printf(message)); // Log to console as well for debugging
    }

    private void set_inputs_sensitive (bool sensitive) {
        input_entry.sensitive = sensitive;
        output_entry.sensitive = sensitive;
        extract_button.sensitive = sensitive;
        format_dropdown.sensitive = sensitive;
        mode_dropdown.sensitive = sensitive;
    }

    private void log_message(string message) {
        Idle.add(() => {
            Gtk.TextIter iter;
            log_buffer.get_end_iter(out iter);
            log_buffer.insert_markup(ref iter, message + "\n", (message + "\n").length);
            log_view.scroll_to_iter(iter, 0.0, true, 0.0, 1.0);
            return Source.REMOVE;
        });
    }
}

public static int main (string[] args) {
    PdfExtractorApp app = new PdfExtractorApp ();
    return app.run (args);
}
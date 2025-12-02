/*
 * Copyright (c) 2024.
 *
 * This file is part of PdfToCbr.
 *
 * PdfToCbr is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PdfToCbr is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PdfToCbr. If not, see <https://www.gnu.org/licenses/>.
 *
 */

/**
 * Represents a single PDF file item in the list.
 * This is a GObject to be used with GListStore.
 */
public class PdfFileItem : GLib.Object {
    public bool converted { get; set; default = false; }
    public string filename { get; private set; }
    public GLib.File file { get; private set; }

    public PdfFileItem (GLib.File file) {
        this.file = file;
        this.filename = file.get_basename ();
    }
}

/**
 * The main window for batch conversion mode.
 */
public class BatchWindow : Gtk.ApplicationWindow {

    private Gtk.ColumnView column_view;
    private Gtk.DropDown format_chooser;
    private Gtk.Button convert_button;
    private Gtk.Button clear_button;
    private GLib.ListStore file_list_model;
    private Gtk.HeaderBar headerbar;

    public BatchWindow (Gtk.Application app) {
        Object (
            application: app,
            title: _("PdfToCbr Batch Converter")
        );
        this.set_default_size (600, 480);
        this.init_headerbar ();

        Gtk.CssProvider css_provider = new Gtk.CssProvider();
        string csses = """
            .progressbar-text-size {
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

        // Main vertical box
        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
        main_box.set_margin_top(20);
        main_box.set_margin_bottom(20);
        main_box.set_margin_start(20);
        main_box.set_margin_end(20);
        set_child (main_box);

        // --- Drag and Drop Area ---
        var drop_frame = new Gtk.Frame ("");
        //drop_frame.set_label_align (0.5f);
        var drop_label = new Gtk.Label (_("Drag & Drop PDF Files Here"));
        //drop_label.height_request = 30;
        drop_label.set_margin_top (30);
        drop_label.set_margin_bottom (50);
        drop_label.set_margin_start (30);
        drop_label.set_margin_end (30);
        drop_frame.set_child (drop_label);
        main_box.append (drop_frame);

        // --- File List View ---
        file_list_model = new GLib.ListStore (typeof (PdfFileItem));
        var selection_model = new Gtk.NoSelection (file_list_model);
        column_view = new Gtk.ColumnView (selection_model);
        column_view.add_css_class("data-table");

        setup_columns ();

        var scrolled_window = new Gtk.ScrolledWindow ();
        scrolled_window.set_child (column_view);
        scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scrolled_window.set_vexpand (true);
        main_box.append (scrolled_window);

        // --- Controls ---
        var controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        main_box.append (controls_box);

        controls_box.append (new Gtk.Label (_("Output Format:")));
        var formats = new string[] {"CBZ", "CBR"};
        format_chooser = new Gtk.DropDown.from_strings (formats);
        format_chooser.set_selected (0); // Default to CBZ
        controls_box.append (format_chooser);

        clear_button = new Gtk.Button.with_label (_("Clear List"));
        clear_button.clicked.connect (() => {
            file_list_model.remove_all();
        });
        controls_box.append (clear_button);

        // Spacer
        var spacer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        spacer.set_hexpand(true);
        controls_box.append(spacer);

        convert_button = new Gtk.Button.with_label (_("Convert All"));
        convert_button.add_css_class ("suggested-action");
        convert_button.clicked.connect (on_convert_clicked);
        controls_box.append (convert_button);

        // --- Setup Drag and Drop ---
        var drop_target = new Gtk.DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
        drop_target.drop.connect (on_drop);
        Gtk.Widget b = this as Gtk.Widget;
        b.add_controller (drop_target);
    }

    /**
     * init_headerbar:
     *
     * #Gtk.HeaderBar constructor for the Application
     */
    private void init_headerbar () {
        headerbar = new Gtk.HeaderBar ();
        headerbar.set_title_widget (new Gtk.Label (_("PdfToCbr Batch Converter")));
        headerbar.set_hexpand (true);
        this.set_titlebar (headerbar);
    }

    private void setup_columns () {
        // --- Converted Checkbox Column ---
        var converted_factory = new Gtk.SignalListItemFactory ();
        converted_factory.setup.connect ((item) => {
            var check = new Gtk.CheckButton ();
            check.set_sensitive(false); // Not user-clickable
            ((Gtk.ListItem) item).set_child (check);
        });
        converted_factory.bind.connect ((item) => {
            var list_item = (Gtk.ListItem) item;
            var pdf_item = (PdfFileItem) list_item.get_item ();
            var check = (Gtk.CheckButton) list_item.get_child ();
            check.set_active (pdf_item.converted);
            pdf_item.bind_property ("converted", check, "active", GLib.BindingFlags.SYNC_CREATE);
        });

        var converted_column = new Gtk.ColumnViewColumn (_("Done"), converted_factory);
        column_view.append_column (converted_column);

        // --- Filename Column ---
        var filename_factory = new Gtk.SignalListItemFactory ();
        filename_factory.setup.connect ((item) => {
            var label = new Gtk.Label ("");
            label.set_xalign (0.0f);
            ((Gtk.ListItem) item).set_child (label);
        });
        filename_factory.bind.connect ((item) => {
            var list_item = (Gtk.ListItem) item;
            var pdf_item = (PdfFileItem) list_item.get_item ();
            var label = (Gtk.Label) list_item.get_child ();
            label.set_text (pdf_item.filename);
        });

        var filename_column = new Gtk.ColumnViewColumn (_("PDF File"), filename_factory);
        filename_column.set_expand(true);
        column_view.append_column (filename_column);
    }

    private bool on_drop (Gtk.DropTarget target, GLib.Value value, double x, double y) {
        var file_list = (Gdk.FileList) value;
        var files = file_list.get_files ();

        foreach (var file in files) {
            if (file.get_uri_scheme () == "file" && file.get_path ().down ().has_suffix (".pdf")) {
                if (!store_contains_id (file_list_model, file)) {
                    file_list_model.append (new PdfFileItem (file));
                }
            }
        }
        return true;
    }

    public bool store_contains_id(GLib.ListStore store, GLib.File file) {
        // Iterate over the ListStore
        for (uint i = 0; i < store.get_n_items(); i++) {
            // Get the item at index i
            var item = store.get_item(i) as PdfFileItem;

            // Check and match
            if (item != null && item.filename == file.get_basename ()) {
                return true; // Found!
            }
        }
        return false; // Not Found
    }

    private void on_convert_clicked () {
        new Thread<void> ("extractor_worker", () => {
            convert_button.set_label(_("Converting..."));
            convert_button.set_sensitive (false);
            clear_button.set_sensitive (false);

            string format = ((Gtk.StringObject)format_chooser.get_selected_item()).get_string().down();
            for (uint i = 0; i < file_list_model.get_n_items (); i++) {
                var item = (PdfFileItem) file_list_model.get_item (i);
                if (!item.converted) {
                        var extractor = new PdfToCbr.PdfImageExtractor ();
                        extractor.finished.connect (() => {                
                            item.converted = true;
                            file_list_model.items_changed (i, 1, 1); // Notify view of change
                        });
                        extractor.extract_images (item.file.get_path (), item.file.get_path () + "." + format, "jpg");
                }
            }
            convert_button.set_label (_("Convert All"));
            convert_button.set_sensitive (true);
            clear_button.set_sensitive (true);
        });
    }

}
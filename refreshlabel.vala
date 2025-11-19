
public class RefreshLabel : Gtk.Application {
        
    private uint[] timeout_id;
    
    private Gtk.Label label;
    
    public RefreshLabel () {
		Object (
		    application_id: "refreh.my.label",
			flags: ApplicationFlags.FLAGS_NONE
		);
	}

	protected override void activate () {
	    Gtk.ApplicationWindow window = new Gtk.ApplicationWindow (this);
	    window.set_default_size (100, 50);
	    window.window_position = Gtk.WindowPosition.CENTER;
	    window.set_border_width(10);	    
	    
	    // create the timeout with your callback that update the label every 1 second
        timeout_id += Timeout.add_seconds_full (GLib.Priority.DEFAULT, 1, update_time);
	    
        label = new Gtk.Label ("");
        var now = new GLib.DateTime.now_local ();
        label.set_markup ("<big>" + now.format ("%x %X") + "</big>");
        
        Gtk.Box vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.pack_start (label, false, false, 0);

        window.add (vbox);
        window.show_all ();
	}

    protected override void shutdown () {
        // On close all instance of the timeout must be closed
        foreach (var id in timeout_id)
            GLib.Source.remove (id);
        base.shutdown ();
    }
    
    public bool update_time () {
        var now = new GLib.DateTime.now_local ();
        label.set_markup ("<big>" + now.format ("%x %X") + "</big>");
        return true;
    }

	public static int main (string[] args) {
		RefreshLabel app = new RefreshLabel ();
		return app.run (args);
	}
}

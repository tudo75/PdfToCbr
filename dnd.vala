using Gtk;

public class MainWindow : Gtk.Window
{
    private Box vboxMain;
    private ScrolledWindow swFiles;
    private TreeView tvFiles;
    private TreeViewColumn colName;
    private Layout layout;
    private Image drop_image;
    
    private const Gtk.TargetEntry[] targets = {
        {"text/uri-list", 0, 0}
    };
    

    public static int main (string[] args) 
    {
        Gtk.init(ref args); 

        var window = new MainWindow (); 
        window.show_all (); 

        Gtk.main();

        return 0;
    }

    public MainWindow () 
    {
        this.title = "Drag files on this window";
        this.window_position = WindowPosition.CENTER;
        this.destroy.connect (Gtk.main_quit);
        set_default_size (550, 450);

        //vboxMain
        vboxMain = new Box (Orientation.VERTICAL, 0);
        vboxMain.margin = 0;
        add (vboxMain);

        //drop_image
        //drop_image = new Image.from_icon_name("folder-download-symbolic", IconSize.DIALOG);
        drop_image = new Image.from_file("/home/nick/dev_projects/Vala examples/drophere.png");

        //layout
        layout = new Layout(null, null);
        layout.set_size_request (550, 150);
        vboxMain.add(layout);
        layout.show();
        layout.put(drop_image, 211, 11);

        //tvFiles
        tvFiles = new TreeView();

        //swFiles
        swFiles = new ScrolledWindow(tvFiles.get_hadjustment (), tvFiles.get_vadjustment ());
        swFiles.set_shadow_type (ShadowType.ETCHED_IN);
        swFiles.set_size_request (550, 300);
        swFiles.add(tvFiles);
        vboxMain.add(swFiles);

        //colName
        colName = new TreeViewColumn();
        colName.title ="Files";
        colName.expand = true;
        CellRendererText cellName = new CellRendererText ();
        colName.pack_start (cellName, false);
        colName.set_attributes(cellName, "text", 0);
        tvFiles.append_column(colName);

        //inputStore
        Gtk.ListStore store = new Gtk.ListStore (1, typeof (string));
        tvFiles.model = store;

        
        //connect drag drop handlers
        Gtk.drag_dest_set (layout, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
        layout.drag_data_received.connect(this.on_drag_data_received);
        
    }

    
    private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, 
                                        Gtk.SelectionData data, uint info, uint time) 
    {
        //loop through list of URIs
        foreach(string uri in data.get_uris ()){
            string file = uri.replace("file://","").replace("file:/","");
            file = Uri.unescape_string (file);

            //add file to tree view
            add_file (file);
        }

        Gtk.drag_finish (drag_context, true, false, time);
    }
    

    private void add_file(string file)
    {
        TreeIter iter;
        Gtk.ListStore store = (Gtk.ListStore) tvFiles.model;
        store.append (out iter);
        store.set (iter, 0, file);
    }
}

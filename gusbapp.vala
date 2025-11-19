// Compilazione (su Linux):
// valac --pkg glib-2.0 --pkg gusb-1.0 gusb_example.vala

using GLib;
using GUsb;

/**
 * Funzione principale dell'applicazione.
 */
public static int main (string[] args) {
    // 1. Inizializza il contesto GUsb
    var context = new Context ();
    stdout.printf ("*** 1. Elenco dei Dispositivi USB ***\n");
    list_devices (context);

    // 2. Tenta di connettersi a un dispositivo specifico
    // NOTA BENE: Sostituisci 0x1234 e 0x5678 con i valori effettivi del
    // tuo dispositivo (Vendor ID e Product ID) per testare la connessione I/O.
    uint16 vendor_id = 0x1234; 
    uint16 product_id = 0x5678;

    stdout.printf ("\n*** 2. Connessione a Dispositivo (VID: 0x%04x, PID: 0x%04x) ***\n", vendor_id, product_id);
    connect_and_io (context, vendor_id, product_id);

    return 0;
}

/**
 * Elenca tutti i dispositivi USB collegati e stampa le informazioni chiave.
 */
private static void list_devices (Context context) {
    // Recupera l'elenco di tutti i dispositivi USB
    var devices = context.list_devices ();

    if (devices.length == 0) {
        stdout.printf ("Nessun dispositivo USB trovato.\n");
        return;
    }

    foreach (var dev in devices) {
        // Estrae le stringhe descrittive (se disponibili)
        string product_name = dev.product != null ? dev.product : "Sconosciuto";
        string vendor_name = dev.manufacturer != null ? dev.manufacturer : "Sconosciuto";

        stdout.printf (
            "  -> Bus %s, Percorso: %s\n", 
            dev.bus_number.to_string (), 
            dev.device_address.to_string ()
        );
        stdout.printf (
            "     ID: 0x%04x:0x%04x | Produttore: %s | Prodotto: %s\n",
            dev.vendor_id, dev.product_id, vendor_name, product_name
        );
        stdout.printf (
            "     Classe: 0x%02x | Configurazione: %d\n",
            dev.device_class, dev.configuration_number
        );
    }
}

/**
 * Tenta di connettersi a un dispositivo specifico, aprire una sessione
 * e richiedere un'interfaccia (claim).
 */
private static void connect_and_io (Context context, uint16 vendor_id, uint16 product_id) {
    Device? target_device = null;

    // Cerca il dispositivo per VID e PID
    foreach (var dev in context.list_devices ()) {
        if (dev.vendor_id == vendor_id && dev.product_id == product_id) {
            target_device = dev;
            break;
        }
    }

    if (target_device == null) {
        stdout.printf ("Dispositivo target (0x%04x:0x%04x) non trovato. Termino la simulazione I/O.\n", vendor_id, product_id);
        stdout.printf ("Assicurati che il dispositivo sia collegato e che i VID/PID siano corretti.\n");
        return;
    }

    stdout.printf ("Dispositivo '%s' trovato. Tentativo di connessione...\n", target_device.product);
    
    // Variabili per l'I/O: l'interfaccia da reclamare e il descrittore aperto
    // CORREZIONE QUI: Usare GUsb.Handle anziché GUsb.DeviceHandle
    Handle? handle = null;
    Interface? interface_claimed = null;
    
    // --- Passaggio 1: Aprire il Dispositivo ---
    try {
        // Tenta di aprire il descrittore del dispositivo (ottiene i permessi di I/O)
        handle = target_device.open ();
        stdout.printf ("  -> Dispositivo aperto con successo.\n");
        
        // --- Passaggio 2: Claim dell'Interfaccia (Preparazione I/O) ---
        // Per l'I/O è necessario reclamare un'interfaccia specifica.
        // Qui si usa l'interfaccia 0 per semplicità, ma potresti dover usare un valore diverso.
        uint8 interface_number = 0; 
        
        // Cerca l'interfaccia e tenta di reclamarla
        var config = target_device.get_configuration_descriptor (target_device.configuration_number);
        if (config == null) {
             stdout.printf ("  ERRORE: Impossibile ottenere il descrittore di configurazione.\n");
             return;
        }
        
        var iface_desc = config.get_interface_descriptor (interface_number);

        if (iface_desc != null) {
            interface_claimed = handle.claim_interface (iface_desc);
            stdout.printf ("  -> Interfaccia %d reclamata (Claim) con successo.\n", interface_number);
            
            // --- Passaggio 3: Esecuzione I/O (Simulato) ---
            stdout.printf ("  -> Interfaccia pronta per operazioni di I/O. (Qui andrebbe il codice per bulk_transfer, etc.).\n");
            
            // Per esempio, per I/O in Bulk:
            // handle.bulk_transfer(endpoint_address, buffer, timeout, out bytes_transferred);

        } else {
            stdout.printf ("  ERRORE: Impossibile trovare l'interfaccia %d.\n", interface_number);
        }

    } catch (Error e) {
        stdout.printf ("  ERRORE nella connessione o I/O: %s\n", e.message);
        return;
    } finally {
        // --- Passaggio 4: Cleanup (Rilascio e Chiusura) ---
        if (interface_claimed != null) {
            try {
                handle.release_interface (interface_claimed);
                stdout.printf ("  -> Interfaccia rilasciata con successo.\n");
            } catch (Error e) {
                stdout.printf ("  ATTENZIONE: Errore nel rilascio dell'interfaccia: %s\n", e.message);
            }
        }
        if (handle != null) {
            handle.close ();
            stdout.printf ("  -> Dispositivo chiuso. Operazione completata.\n");
        }
    }
}

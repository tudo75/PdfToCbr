using LibUSB;

int main () {
    LibUSB.Context ctx;
    LibUSB.Context.init (out ctx);

    var devices = ctx.getDeviceList();

    Device? target_device = null;
    foreach (var dev in devices) {
        var desc = dev.getDeviceDescriptor();
        if (desc.idVendor == 0x04f9) {
            target_device = dev;
            print("Trovato dispositivo Brother QL, PID: 0x%04x\n", desc.idProduct);
            break;
        }
    }

    if (target_device == null) {
        print("Dispositivo Brother QL non trovato\n");
        ctx.exit();
        return 1;
    }

    var handle = target_device.open();
    if (handle == null) {
        print("Impossibile aprire il dispositivo\n");
        ctx.exit();
        return 1;
    }

    int iface = 0;

    try {
        if (handle.isKernelDriverActive(iface))
            handle.detachKernelDriver(iface);
    } catch (GLib.Error e) {
        print("Nessun driver kernel da staccare o errore\n");
    }

    handle.setConfiguration(1);
    handle.claimInterface(iface);

    var config = target_device.getActiveConfiguration();
    var intf = config.getInterface(iface);
    var altsetting = intf.getSettings()[0];

    uint8 ep_in_address = 0;
    uint8 ep_out_address = 0;

    foreach (var ep in altsetting.getEndpoints()) {
        if ((ep.bEndpointAddress & 0x80) != 0)
            ep_in_address = ep.bEndpointAddress;
        else
            ep_out_address = ep.bEndpointAddress;
    }

    if (ep_in_address == 0 || ep_out_address == 0) {
        print("Endpoint IN o OUT non trovati\n");
        handle.releaseInterface(iface);
        handle.close();
        ctx.exit();
        return 1;
    }

    uint8[] data_to_send = { 0x01, 0x02, 0x03 };
    int transferred = 0;
    int res = handle.bulkTransfer(ep_out_address, data_to_send, 5000, out transferred);
    if (res == 0)
        print("Inviati %d bytes\n", transferred);
    else
        print("Errore scrittura: %d\n", res);

    uint8[] data_received = new uint8[64];
    int received = 0;
    res = handle.bulkTransfer(ep_in_address, data_received, 5000, out received);
    if (res == 0)
        print("Ricevuti %d bytes\n", received);
    else
        print("Errore lettura: %d\n", res);

    handle.releaseInterface(iface);
    handle.close();

    ctx.exit();

    return 0;
}


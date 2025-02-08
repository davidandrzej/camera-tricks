from wsdiscovery import WSDiscovery, QName

def discover_onvif_cameras(timeout=10):
    """
    Discovers ONVIF cameras on the local network using WS-Discovery.

    ONVIF cameras typically advertise as devices of type "NetworkVideoTransmitter",
    which is defined in the ONVIF spec with the namespace:
    "http://www.onvif.org/ver10/network/wsdl".
    """
    # Initialize and start the WSDiscovery service.
    wsd = WSDiscovery()
    wsd.start()

    # Define the QName for ONVIF Network Video Transmitter devices
    # in order to to filter down to those only
    #onvif_type = QName("http://www.onvif.org/ver10/network/wsdl", "NetworkVideoTransmitter")
    #print("Searching for ONVIF cameras...")
    #devices = wsd.searchServices(types=[onvif_type], timeout=timeout)

    # OR search for anything WS-Discovery can find
    print("Searching for general devices...")
    devices = wsd.searchServices(timeout=timeout)

    if devices:
        for device in devices:
            print("\nFound device:")
            print("  EPR (Endpoint Reference):", device.getEPR())
            print("  XAddrs (Service Addresses):", ", ".join(device.getXAddrs()))
    else:
        print("No devices found.")
        
    wsd.stop()

if __name__ == "__main__":
    discover_onvif_cameras()

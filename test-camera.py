import cv2
import time
from onvif import ONVIFCamera
from urllib.parse import urlparse, urlunparse
import getpass

def main():
    # Replace these details with your camera’s network details
    camera_host = "10.0.0.153"   # IP address of the camera
    camera_port = 80               # Usually 80, 8080, or 8999 for ONVIF
    camera_user = "thingino"          # ONVIF username
    camera_pass = getpass.getpass("ONVIF+RSTP pw for %s: " % camera_user) 
    # NOTE: assuming the same pw for ONVIF and RSTP ... !

    # Create an ONVIF camera object
    mycam = ONVIFCamera(
        camera_host,
        camera_port,
        camera_user,
        camera_pass
    )

    media_service = mycam.create_media_service()
    
    try:
        profiles = media_service.GetProfiles()
        print("Profiles returned:", profiles)
    except exceptions.ONVIFError as e:
        print("Error retrieving profiles:", e)
        return

    if not profiles:
        print("No profiles found! Check if the camera is online and ONVIF is enabled.")
        return

    profile = profiles[0]
    print("Using profile:", profile.Name)

    # Get the stream URI
    stream_request = media_service.create_type("GetStreamUri")
    stream_request.ProfileToken = profile.token
    stream_request.StreamSetup = {
        "Stream": "RTP_Unicast",
        "Transport": {"Protocol": "RTSP"}
    }

    stream_uri_response = media_service.GetStreamUri(stream_request)
    rtsp_uri = stream_uri_response.Uri

    # FIX:    
    rtsp_uri = stream_uri_response.Uri  # The ONVIF-provided RTSP URI
    parsed = urlparse(rtsp_uri)
    # This breaks down the RTSP URI into (scheme, netloc, path, params, query, fragment)
    # e.g. scheme="rtsp", netloc="192.168.1.100:554", path="/Streaming/Channels/101", etc.

    # Rebuild the netloc to include user:pass
    new_netloc = f"{camera_user}:{camera_pass}@{parsed.hostname}"
    if parsed.port:
        new_netloc += f":{parsed.port}"
        # Put it all back together
    authenticated_uri = urlunparse(parsed._replace(netloc=new_netloc))
    rtsp_uri = authenticated_uri

    print("RTSP URI:", rtsp_uri)

    # Open the RTSP stream using OpenCV
    cap = cv2.VideoCapture(rtsp_uri)

    if not cap.isOpened():
        print("Could not open video stream.")
        return

    # Display frames in a loop
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Failed to grab frame")
                break

            cv2.imshow("ONVIF Camera Feed", frame)

            # Press 'q' to break out of the loop
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    except KeyboardInterrupt:
        print("Stream interrupted by user.")

    finally:
        cap.release()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()

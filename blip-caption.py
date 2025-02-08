import cv2
import torch
from transformers import Blip2Processor, Blip2ForConditionalGeneration
from onvif import ONVIFCamera
import getpass

def main():
    # ------------------------------------------------------------------
    # 1) CONNECT TO ONVIF CAMERA AND GET RTSP URL
    # ------------------------------------------------------------------
    camera_host = "10.0.0.153"   # IP address of the camera
    camera_port = 80               # Usually 80, 8080, or 8999 for ONVIF
    camera_user = "thingino"          # ONVIF username
    camera_pass = getpass.getpass("ONVIF+RSTP pw for %s: " % camera_user) # ONVIF
    # NOTE: assuming the same pw for ONVIF and RSTP ... !

    mycam = ONVIFCamera(camera_host, camera_port, camera_user, camera_pass)#wsdl_dir=wsdl_dir)
    media_service = mycam.create_media_service()
    profiles = media_service.GetProfiles()

    if not profiles:
        print("No ONVIF profiles found; check camera settings.")
        return

    profile = profiles[0]
    stream_request = media_service.create_type("GetStreamUri")
    stream_request.ProfileToken = profile.token
    stream_request.StreamSetup = {"Stream": "RTP_Unicast", "Transport": {"Protocol": "RTSP"}}
    stream_uri_response = media_service.GetStreamUri(stream_request)

    # The camera may not embed credentials in the RTSP URI, so let's parse and inject them:
    from urllib.parse import urlparse, urlunparse

    parsed = urlparse(stream_uri_response.Uri)
    new_netloc = f"{camera_user}:{camera_pass}@{parsed.hostname}"
    if parsed.port:
        new_netloc += f":{parsed.port}"
    authenticated_uri = urlunparse(parsed._replace(netloc=new_netloc))
    print("Authenticated RTSP URI:", authenticated_uri)

    # ------------------------------------------------------------------
    # 2) OPEN THE CAMERA STREAM WITH OPENCV
    # ------------------------------------------------------------------
    cap = cv2.VideoCapture(authenticated_uri)
    if not cap.isOpened():
        print("Could not open video stream.")
        return

    # ------------------------------------------------------------------
    # 3) PREPARE BLIP-2 (OR ANY VISION-LANGUAGE) MODEL FOR CAPTIONING
    # ------------------------------------------------------------------
    # Example: Using SalesForce/blip2-flan-t5-xl
    processor = Blip2Processor.from_pretrained("Salesforce/blip2-flan-t5-xl")
    model = Blip2ForConditionalGeneration.from_pretrained("Salesforce/blip2-flan-t5-xl", device_map="auto")
    
    # or on CPU only (slow):
    # model = Blip2ForConditionalGeneration.from_pretrained("Salesforce/blip2-flan-t5-xl").to("cpu")

    # ------------------------------------------------------------------
    # 4) CAPTION FRAMES IN A LOOP
    # ------------------------------------------------------------------
    while True:
        ret, frame = cap.read()
        if not ret:
            print("Failed to read frame")
            break

        # Convert the OpenCV frame (BGR) to RGB
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Note: The processor expects a PIL image or list of PIL images
        # So let's convert the numpy array to PIL.
        # If you prefer direct numpy -> transforms, you can adapt as well.
        from PIL import Image
        pil_image = Image.fromarray(frame_rgb)

        # Preprocess
        inputs = processor(pil_image, return_tensors="pt").to(model.device)

        # Generate caption
        with torch.no_grad():
            generated_ids = model.generate(**inputs, max_new_tokens=50)
            caption = processor.tokenizer.decode(generated_ids[0], skip_special_tokens=True)

        # Print or display the caption
        print("Frame Caption:", caption)

        # (Optional) Show the camera feed in a window
        cv2.imshow("Camera Feed", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Cleanup
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()

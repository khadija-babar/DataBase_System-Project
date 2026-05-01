import cv2
from ultralytics import YOLO

# -----------------------------------------------
# Load Models
# -----------------------------------------------
detection_model = YOLO("yolov8n.pt")
pose_model      = YOLO("yolov8n-pose.pt")

# -----------------------------------------------
# USER INPUT
# -----------------------------------------------
print("Which result do you want to see?")
print("1. Male (fastbus.MOV)")
print("2. Female (bus2.mp4)")
print("3. Both")

choice = input("\nEnter your choice (1 / 2 / 3): ").strip()

# -----------------------------------------------
# POSTURE DETECTION (ONLY detect standing reliably)
# -----------------------------------------------
def detect_posture(frame, x1, y1, x2, y2):
    crop = frame[y1:y2, x1:x2]

    if crop.size == 0:
        return "unknown"

    results = pose_model(crop, verbose=False)

    if not results or results[0].keypoints is None:
        return "unknown"

    kp   = results[0].keypoints.xy
    conf = results[0].keypoints.conf

    if kp is None or len(kp) == 0:
        return "unknown"

    keypoints = kp[0]
    confidences = conf[0] if conf is not None else None

    if len(keypoints) < 17:
        return "unknown"

    def get_y(i): return float(keypoints[i][1])
    def get_conf(i): return float(confidences[i]) if confidences is not None else 1.0

    CONF = 0.3

    # Only check if clearly standing
    if not (get_conf(11)>CONF and get_conf(13)>CONF and get_conf(15)>CONF):
        return "unknown"

    hip   = get_y(11)
    knee  = get_y(13)
    ankle = get_y(15)

    if knee - hip <= 0:
        return "unknown"

    ratio = (ankle - knee) / (knee - hip)

    # Only confidently label standing
    return "standing" if ratio >= 0.75 else "unknown"

# -----------------------------------------------
# HYBRID PROCESSING
# -----------------------------------------------
def process_video_hybrid(video_path, label, seconds=3):
    print(f"\nProcessing {label} video (HYBRID mode {seconds}s)...")

    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        print("Error opening video")
        return

    fps = cap.get(cv2.CAP_PROP_FPS)
    max_frames = int(fps * seconds)

    frame_count = 0
    unique_ids = set()
    last_frame = None

    print("Tracking passengers (fast)...")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_count += 1
        if frame_count > max_frames:
            break

        if frame_count % 10 != 0:
            continue

        results = detection_model.track(
            frame,
            tracker="bytetrack.yaml",
            persist=True,
            verbose=False
        )

        if results[0].boxes.id is not None:
            for track_id, cls in zip(results[0].boxes.id, results[0].boxes.cls):
                if detection_model.names[int(cls)] == "person":
                    unique_ids.add(int(track_id))

        last_frame = frame.copy()

    cap.release()

    if last_frame is None:
        print("No frame captured")
        return

    print("Running posture analysis on snapshot...")

    # -----------------------------------------------
    # SNAPSHOT ANALYSIS
    # -----------------------------------------------
    results = detection_model(last_frame, verbose=False)

    standing = 0
    annotated = last_frame.copy()

    if results[0].boxes is None:
        print("No persons detected")
        return

    for box, cls in zip(results[0].boxes.xyxy, results[0].boxes.cls):
        if detection_model.names[int(cls)] != "person":
            continue

        x1, y1, x2, y2 = map(int, box)

        posture = detect_posture(last_frame, x1, y1, x2, y2)

        if posture == "standing":
            standing += 1
            color = (0, 0, 255)
        else:
            color = (0, 255, 0)  # assumed seated

        cv2.rectangle(annotated, (x1,y1), (x2,y2), color, 2)

    # -----------------------------------------------
    # FINAL LOGIC CHANGE HERE
    # -----------------------------------------------
    total_unique = len(unique_ids)
    seated = total_unique - standing

    # Safety clamp
    if seated < 0:
        seated = 0

    # Save snapshot
    snapshot_path = f"snapshot_{label}.jpg"
    cv2.imwrite(snapshot_path, annotated)

    print(f"\n===== {label.upper()} HYBRID RESULT =====")
    print(f"Seconds Analysed        : {seconds}")
    print(f"Total Unique Passengers : {total_unique}")
    print(f"Standing                : {standing}")
    print(f"Seated (derived)        : {seated}")
    print(f"Snapshot saved as       : {snapshot_path}")

# -----------------------------------------------
# RUN
# -----------------------------------------------
if choice == "1":
    process_video_hybrid("BusNew.mp4", "Male", seconds=3)

elif choice == "2":
    process_video_hybrid("bus2.mp4", "Female", seconds=3)

elif choice == "3":
    process_video_hybrid("fastbus.MOV", "Male", seconds=3)
    process_video_hybrid("bus2.mp4", "Female", seconds=3)

else:
    print("Invalid choice.")
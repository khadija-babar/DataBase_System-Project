import os
from functools import lru_cache


def _load_dependencies():
    try:
        import cv2  # type: ignore
        from ultralytics import YOLO  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            'Video AI dependencies are missing. Run "pip install -r requirements.txt" and try again.'
        ) from exc
    return cv2, YOLO


@lru_cache(maxsize=1)
def _load_models():
    _cv2, YOLO = _load_dependencies()
    return YOLO('yolov8n.pt'), YOLO('yolov8n-pose.pt')


def detect_posture(frame, x1, y1, x2, y2, pose_model):
    crop = frame[y1:y2, x1:x2]
    if crop.size == 0:
        return 'unknown'

    results = pose_model(crop, verbose=False)
    if not results or results[0].keypoints is None:
        return 'unknown'

    kp = results[0].keypoints.xy
    conf = results[0].keypoints.conf
    if kp is None or len(kp) == 0:
        return 'unknown'

    keypoints = kp[0]
    confidences = conf[0] if conf is not None else None
    if len(keypoints) < 17:
        return 'unknown'

    def get_y(i):
        return float(keypoints[i][1])

    def get_conf(i):
        return float(confidences[i]) if confidences is not None else 1.0

    min_confidence = 0.3
    if not (
        get_conf(11) > min_confidence
        and get_conf(13) > min_confidence
        and get_conf(15) > min_confidence
    ):
        return 'unknown'

    hip = get_y(11)
    knee = get_y(13)
    ankle = get_y(15)
    if knee - hip <= 0:
        return 'unknown'

    ratio = (ankle - knee) / (knee - hip)
    return 'standing' if ratio >= 0.75 else 'unknown'


@lru_cache(maxsize=32)
def analyze_video_capacity(video_path, bus_capacity=80, seconds=3, frame_skip=10):
    """Analyze a selected bus video and return passenger/capacity counts.

    This is the backend-safe version of the provided Bus_Project.py logic. It
    removes terminal input and accepts the video path from Flask when a passenger
    selects a bus in the portal.
    """
    if not video_path or not os.path.exists(video_path):
        raise FileNotFoundError(f'Video file not found: {video_path}')

    cv2, _YOLO = _load_dependencies()
    detection_model, pose_model = _load_models()
    capture = cv2.VideoCapture(video_path)
    if not capture.isOpened():
        raise RuntimeError(f'Could not open video file: {video_path}')

    fps = capture.get(cv2.CAP_PROP_FPS) or 30
    max_frames = int(fps * seconds)
    frame_count = 0
    unique_ids = set()
    last_frame = None

    try:
        while True:
            ret, frame = capture.read()
            if not ret:
                break

            frame_count += 1
            if frame_count > max_frames:
                break

            if frame_count % frame_skip != 0:
                continue

            results = detection_model.track(
                frame,
                tracker='bytetrack.yaml',
                persist=True,
                verbose=False,
            )

            if results and results[0].boxes.id is not None:
                for track_id, cls in zip(results[0].boxes.id, results[0].boxes.cls):
                    if detection_model.names[int(cls)] == 'person':
                        unique_ids.add(int(track_id))

            last_frame = frame.copy()
    finally:
        capture.release()

    if last_frame is None:
        raise RuntimeError('No frame captured from video')

    snapshot_results = detection_model(last_frame, verbose=False)
    standing = 0
    if snapshot_results and snapshot_results[0].boxes is not None:
        for box, cls in zip(snapshot_results[0].boxes.xyxy, snapshot_results[0].boxes.cls):
            if detection_model.names[int(cls)] != 'person':
                continue

            x1, y1, x2, y2 = map(int, box)
            posture = detect_posture(last_frame, x1, y1, x2, y2, pose_model)
            if posture == 'standing':
                standing += 1

    total_unique = len(unique_ids)
    seated = max(total_unique - standing, 0)
    capacity = int(bus_capacity)
    available_seats = max(capacity - total_unique, 0)
    occupancy_percent = round((total_unique * 100.0) / capacity, 1) if capacity else 0

    return {
        'people_count': total_unique,
        'standing': standing,
        'seated': seated,
        'capacity': capacity,
        'available_seats': available_seats,
        'occupancy_percent': occupancy_percent,
        'seconds_analyzed': seconds,
        'sampled_frames': frame_count // frame_skip,
    }


def analyze_bus_video(video_path, bus_capacity=80):
    return analyze_video_capacity(video_path, bus_capacity=bus_capacity)

import os
from functools import lru_cache


def _load_cv2():
    try:
        import cv2  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            'OpenCV is not installed. Run "pip install -r requirements.txt" and try again.'
        ) from exc
    return cv2


@lru_cache(maxsize=32)
def analyze_video_capacity(video_path, bus_capacity=80, frame_step=30, max_frames=90):
    """Count people in a bus video using OpenCV HOG person detection.

    Returns the highest detected people count across sampled frames. The result is
    cached so repeated passenger clicks do not re-process the same video.
    """
    if not video_path or not os.path.exists(video_path):
        raise FileNotFoundError(f'Video file not found: {video_path}')

    cv2 = _load_cv2()
    detector = cv2.HOGDescriptor()
    detector.setSVMDetector(cv2.HOGDescriptor_getDefaultPeopleDetector())

    capture = cv2.VideoCapture(video_path)
    if not capture.isOpened():
        raise RuntimeError(f'Could not open video file: {video_path}')

    max_people = 0
    sampled_frames = 0
    frame_index = 0

    try:
        while sampled_frames < max_frames:
            ok, frame = capture.read()
            if not ok:
                break

            if frame_index % frame_step == 0:
                frame = cv2.resize(frame, (640, 360))
                boxes, _weights = detector.detectMultiScale(
                    frame,
                    winStride=(8, 8),
                    padding=(8, 8),
                    scale=1.05,
                )
                max_people = max(max_people, len(boxes))
                sampled_frames += 1

            frame_index += 1
    finally:
        capture.release()

    available_seats = max(int(bus_capacity) - max_people, 0)
    occupancy_percent = round((max_people * 100.0) / int(bus_capacity), 1) if bus_capacity else 0

    return {
        'people_count': max_people,
        'capacity': int(bus_capacity),
        'available_seats': available_seats,
        'occupancy_percent': occupancy_percent,
        'sampled_frames': sampled_frames,
    }


def analyze_bus_video(video_path, bus_capacity=80):
    """Compatibility entry point used by the Flask backend.

    Replace the internals of analyze_video_capacity with your final model code
    later; keep this function name so app.py can keep calling it.
    """
    return analyze_video_capacity(video_path, bus_capacity=bus_capacity)

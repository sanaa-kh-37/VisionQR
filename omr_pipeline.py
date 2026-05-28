"""
omr_pipeline.py — Final tuned version for your mysheet.jpeg
"""

import cv2
import numpy as np

NUM_QUESTIONS = 8
NUM_CHOICES = 4
FILL_THRESHOLD = 0.22  # Very low for your pen

MIN_BUBBLE_AREA = 30
MAX_BUBBLE_AREA = 2500
MIN_ASPECT_R = 0.4
MAX_ASPECT_R = 2.2
ROW_TOLERANCE = 50


def process_omr_sheet(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    kernel = np.ones((2, 2), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)

    # Use original (no perspective for now)
    warped = image.copy()
    perspective_ok = False

    gray2 = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    blurred2 = cv2.GaussianBlur(gray2, (5, 5), 0)
    _, thresh2 = cv2.threshold(
        blurred2, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
    )

    h, w = warped.shape[:2]
    mid = w // 2

    thresh_part1 = thresh2[:, :mid]
    thresh_part2 = thresh2[:, mid:]

    part1_answers, b1 = _read_answers(thresh_part1, "Part-I")
    part2_answers, b2 = _read_answers(thresh_part2, "Part-II")

    return {
        "success": True,
        "part1": part1_answers,
        "part2": part2_answers,
        "debug_info": {
            "perspective_corrected": perspective_ok,
            "bubbles_found_part1": b1,
            "bubbles_found_part2": b2,
            "image_size": f"{w}x{h}",
        },
    }


def _read_answers(thresh_half, part_name):
    contours, _ = cv2.findContours(
        thresh_half, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    bubbles = []
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        area = cv2.contourArea(c)
        if area < MIN_BUBBLE_AREA or area > MAX_BUBBLE_AREA:
            continue
        ar = w / h
        if ar < MIN_ASPECT_R or ar > MAX_ASPECT_R:
            continue
        if w < 8 or h < 8:
            continue
        bubbles.append((x, y, w, h, c))

    bubbles_sorted = sorted(bubbles, key=lambda b: (b[1] // ROW_TOLERANCE, b[0]))

    rows = []
    current = []
    last_y = -999
    for b in bubbles_sorted:
        if abs(b[1] - last_y) > ROW_TOLERANCE and current:
            rows.append(current)
            current = []
        current.append(b)
        last_y = b[1]
    if current:
        rows.append(current)

    choices = ["A", "B", "C", "D"]
    answers = {}

    for q_idx, row in enumerate(rows):
        if q_idx >= NUM_QUESTIONS:
            break
        qkey = f"Q{str(q_idx+1).zfill(2)}"
        row = sorted(row, key=lambda b: b[0])[:4]

        if len(row) < 4:
            answers[qkey] = None
            continue

        filled = []
        for i, (_, _, _, _, cnt) in enumerate(row):
            ratio = _measure_fill_ratio(thresh_half, cnt)
            if ratio > FILL_THRESHOLD:
                filled.append(i)

        if len(filled) == 0:
            answers[qkey] = None
        elif len(filled) == 1:
            answers[qkey] = choices[filled[0]]
        else:
            answers[qkey] = "INVALID"

    for i in range(NUM_QUESTIONS):
        k = f"Q{str(i+1).zfill(2)}"
        if k not in answers:
            answers[k] = None

    # Debug
    debug = cv2.cvtColor(thresh_half, cv2.COLOR_GRAY2BGR)
    for x, y, w, h, _ in bubbles:
        cv2.rectangle(debug, (x, y), (x + w, y + h), (0, 255, 0), 2)
    cv2.imwrite(f"debug_bubbles_{part_name}.jpg", debug)
    print(f"Debug saved: debug_bubbles_{part_name}.jpg")

    return answers, len(bubbles)


def _measure_fill_ratio(thresh, contour):
    mask = np.zeros(thresh.shape, np.uint8)
    cv2.drawContours(mask, [contour], -1, 255, -1)
    total = cv2.countNonZero(mask)
    if total == 0:
        return 0.0
    inter = cv2.bitwise_and(thresh, thresh, mask=mask)
    filled = cv2.countNonZero(inter)
    return filled / total

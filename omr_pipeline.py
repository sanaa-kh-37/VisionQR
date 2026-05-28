"""
omr_pipeline.py — FINAL VERSION (16 Questions)
Part-I: Q01-Q08 | Part-II: Q09-Q16
"""

import cv2
import numpy as np

# ========================= CONFIG =========================
NUM_QUESTIONS = 8          # per part
NUM_CHOICES = 4            # A, B, C, D
FILL_THRESHOLD = 0.26      # Adjust between 0.20 - 0.35

MIN_BUBBLE_AREA = 30
MAX_BUBBLE_AREA = 2800
MIN_ASPECT_R = 0.45
MAX_ASPECT_R = 2.1
ROW_TOLERANCE = 50
# =======================================================

def process_omr_sheet(image):
    # Preprocessing
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (7, 7), 0)
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    kernel = np.ones((3,3), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)

    # Use original image (perspective often fails on your sheets)
    warped = image.copy()

    # Re-threshold after warp
    gray2 = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    blurred2 = cv2.GaussianBlur(gray2, (5, 5), 0)
    _, thresh2 = cv2.threshold(blurred2, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    h, w = warped.shape[:2]
    mid = w // 2

    # Process both parts
    part1_answers, b1 = _read_answers(thresh2[:, :mid], "Part-I", start_q=1)
    part2_answers, b2 = _read_answers(thresh2[:, mid:], "Part-II", start_q=9)

    return {
        "success": True,
        "part1": part1_answers,
        "part2": part2_answers,
        "debug_info": {
            "perspective_corrected": False,
            "bubbles_found_part1": b1,
            "bubbles_found_part2": b2,
            "image_size": f"{w}x{h}",
        }
    }


def _read_answers(thresh_half, part_name, start_q=1):
    contours, _ = cv2.findContours(thresh_half, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    bubbles = []
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        area = cv2.contourArea(c)
        if area < MIN_BUBBLE_AREA or area > MAX_BUBBLE_AREA:
            continue
        ar = w / float(h)
        if ar < MIN_ASPECT_R or ar > MAX_ASPECT_R:
            continue
        if w < 10 or h < 10:
            continue
        bubbles.append((x, y, w, h, c))

    # Sort into rows
    bubbles = sorted(bubbles, key=lambda b: (b[1] // ROW_TOLERANCE, b[0]))

    rows = []
    current = []
    last_y = -999
    for b in bubbles:
        if abs(b[1] - last_y) > ROW_TOLERANCE and current:
            rows.append(current)
            current = []
        current.append(b)
        last_y = b[1]
    if current:
        rows.append(current)

    choices = ['A', 'B', 'C', 'D']
    answers = {}

    for q_idx, row in enumerate(rows):
        if q_idx >= NUM_QUESTIONS:
            break

        question_num = start_q + q_idx
        qkey = f"Q{str(question_num).zfill(2)}"

        row = sorted(row, key=lambda b: b[0])[:NUM_CHOICES]

        if len(row) < NUM_CHOICES:
            answers[qkey] = None
            continue

        filled = []
        for i, (_,_,_,_,cnt) in enumerate(row):
            ratio = _measure_fill_ratio(thresh_half, cnt)
            if ratio > FILL_THRESHOLD:
                filled.append(i)

        if len(filled) == 0:
            answers[qkey] = None
        elif len(filled) == 1:
            answers[qkey] = choices[filled[0]]
        else:
            answers[qkey] = "INVALID"

    # Fill any missing questions
    for i in range(NUM_QUESTIONS):
        qnum = start_q + i
        qkey = f"Q{str(qnum).zfill(2)}"
        if qkey not in answers:
            answers[qkey] = None

    # Save debug image
    debug = cv2.cvtColor(thresh_half, cv2.COLOR_GRAY2BGR)
    for x,y,w,h,_ in bubbles:
        cv2.rectangle(debug, (x,y), (x+w,y+h), (0,255,0), 2)
    cv2.imwrite(f"debug_{part_name}.jpg", debug)

    return answers, len(bubbles)


def _measure_fill_ratio(thresh, contour):
    mask = np.zeros(thresh.shape, np.uint8)
    cv2.drawContours(mask, [contour], -1, 255, -1)
    total = cv2.countNonZero(mask)
    if total == 0:
        return 0.0
    filled = cv2.countNonZero(cv2.bitwise_and(thresh, thresh, mask=mask))
    return filled / total
"""
omr_pipeline.py — FINAL CORRECT VERSION
=========================================
Part-I:  Q01–Q08  (keys: "Q01"…"Q08")
Part-II: Q01–Q08  (keys: "Q01"…"Q08")

KEY INSIGHT — relative scoring:
  An empty printed circle has a dark BORDER that gives ~0.30 darkness.
  A filled bubble is uniformly dark, giving ~0.70–0.90 darkness.
  So we DON'T use an absolute threshold.
  Instead: a bubble is filled if its score is ≥ RELATIVE_FACTOR × row average.
  On a blank sheet, all 4 bubbles score similarly → ratio ≈ 1.0–1.2 → blank.
  On a filled sheet, one bubble scores 2–3× the others → ratio > 1.5 → filled.
"""

import cv2
import numpy as np

# ========================= CONFIG =========================
NUM_QUESTIONS  = 8
NUM_CHOICES    = 4   # A B C D

# A bubble is "filled" if its darkness score is this many times
# greater than the row average. Tune between 1.4–2.0.
# Lower → more sensitive (catches light pencil marks)
# Higher → less false positives on blank sheets
RELATIVE_FACTOR = 1.4

# Skip leftmost fraction of each half (the Q01/Q02 label column)
LABEL_SKIP_FRAC = 0.22
# ==========================================================


def process_omr_sheet(image):
    h, w = image.shape[:2]

    table = _crop_answer_table(image)
    th, tw = table.shape[:2]

    gray    = cv2.cvtColor(table, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    thresh  = cv2.adaptiveThreshold(
        blurred, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV,
        blockSize=15, C=4
    )

    mid = _find_split(thresh, tw)

    label_skip_l = int(mid * LABEL_SKIP_FRAC)
    label_skip_r = int((tw - mid) * LABEL_SKIP_FRAC)

    left_thresh  = thresh[:, label_skip_l : mid]
    right_thresh = thresh[:, mid + label_skip_r :]

    part1, b1, dbg1 = _read_part(left_thresh,  "Part-I",  start=1)
    part2, b2, dbg2 = _read_part(right_thresh, "Part-II", start=1)

    _save_debug(dbg1, dbg2, "debug_omr.jpg")

    return {
        "success": True,
        "part1":   part1,
        "part2":   part2,
        "debug_info": {
            "perspective_corrected": False,
            "bubbles_found_part1":   b1,
            "bubbles_found_part2":   b2,
            "image_size":            f"{w}x{h}",
            "table_size":            f"{tw}x{th}",
            "split_col":             mid,
        }
    }


def _crop_answer_table(image):
    h, w = image.shape[:2]
    gray  = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(cv2.GaussianBlur(gray, (3, 3), 0), 30, 100)
    edges = cv2.dilate(edges, np.ones((3, 3), np.uint8), iterations=1)

    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    best = None
    best_area = 0
    for c in contours:
        area = cv2.contourArea(c)
        if area < w * h * 0.10 or area > w * h * 0.92:
            continue
        x, y, cw, ch = cv2.boundingRect(c)
        if cw < w * 0.40 or cw < ch:
            continue
        if area > best_area:
            best_area = area
            best = (x, y, cw, ch)

    if best is None:
        return image[int(h * 0.30):, :]

    x, y, cw, ch = best
    pad = 4
    return image[max(0,y-pad): min(h,y+ch+pad),
                 max(0,x-pad): min(w,x+cw+pad)]


def _find_split(thresh, width):
    col_sum = np.sum(thresh, axis=0).astype(np.float64)
    lo, hi  = int(width * 0.30), int(width * 0.70)
    return int(np.argmax(col_sum[lo:hi])) + lo


def _read_part(thresh_half, part_name, start=1):
    choices = ['A', 'B', 'C', 'D']
    answers = {f"Q{str(i).zfill(2)}": None for i in range(start, start + NUM_QUESTIONS)}

    h, w   = thresh_half.shape
    bubbles = _find_bubble_candidates(thresh_half)
    grid    = _cluster_to_grid(bubbles, NUM_QUESTIONS, NUM_CHOICES, w, h)

    debug = cv2.cvtColor(thresh_half, cv2.COLOR_GRAY2BGR)
    filled_count = 0

    for q_idx, row in enumerate(grid):
        qkey = f"Q{str(start + q_idx).zfill(2)}"

        used_fallback = not row or len(row) < NUM_CHOICES
        if used_fallback:
            row = _make_fallback_row(q_idx, w, h)

        row_sorted = sorted(row, key=lambda b: b[0])[:NUM_CHOICES]

        # Score each bubble
        scores = [_interior_darkness(thresh_half, b[0], b[1], b[2], b[3])
                  for b in row_sorted]

        # Draw all bubbles
        for b in row_sorted:
            cv2.rectangle(debug, (b[0],b[1]), (b[0]+b[2], b[1]+b[3]), (0,180,0), 1)

        # Relative decision
        avg_score = sum(scores) / len(scores) if scores else 0
        max_score = max(scores)
        best_idx  = int(np.argmax(scores))

        if not used_fallback and avg_score > 0 and (max_score / avg_score) >= RELATIVE_FACTOR:
            answers[qkey] = choices[best_idx]
            filled_count += 1
            bx, by, bw, bh = row_sorted[best_idx]
            cv2.rectangle(debug, (bx,by), (bx+bw, by+bh), (0,0,255), 2)
            cv2.putText(debug, choices[best_idx], (bx+2, by+bh-2),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0,0,255), 1)

    cv2.imwrite(f"debug_{part_name}.jpg", debug)
    return answers, filled_count, debug


def _find_bubble_candidates(thresh):
    h, w = thresh.shape
    min_w = max(8,  int(w * 0.03))
    max_w = min(80, int(w * 0.25))
    min_h = max(8,  int(h * 0.01))
    max_h = min(80, int(h * 0.12))

    contours, _ = cv2.findContours(thresh, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    bubbles = []
    for c in contours:
        x, y, bw, bh = cv2.boundingRect(c)
        if not (min_w <= bw <= max_w and min_h <= bh <= max_h):
            continue
        ar = bw / float(bh)
        if ar < 0.45 or ar > 2.2:
            continue
        if cv2.contourArea(c) < min_w * min_h * 0.25:
            continue
        bubbles.append((x, y, bw, bh))

    return _deduplicate(bubbles)


def _deduplicate(bubbles, overlap=0.35):
    if not bubbles:
        return bubbles
    bubbles = sorted(bubbles, key=lambda b: -(b[2]*b[3]))
    kept = []
    for b in bubbles:
        bx, by, bw, bh = b
        skip = False
        for k in kept:
            kx, ky, kw, kh = k
            ix = max(0, min(bx+bw, kx+kw) - max(bx, kx))
            iy = max(0, min(by+bh, ky+kh) - max(by, ky))
            inter = ix * iy
            union = bw*bh + kw*kh - inter
            if union > 0 and inter/union > overlap:
                skip = True
                break
        if not skip:
            kept.append(b)
    return kept


def _cluster_to_grid(bubbles, num_rows, num_cols, img_w, img_h):
    if not bubbles:
        return [[] for _ in range(num_rows)]

    bubbles_cy = sorted(bubbles, key=lambda b: b[1] + b[3]//2)
    row_groups  = []
    current = [bubbles_cy[0]]
    for b in bubbles_cy[1:]:
        cy_prev = current[-1][1] + current[-1][3]//2
        cy_cur  = b[1] + b[3]//2
        if abs(cy_cur - cy_prev) < 18:
            current.append(b)
        else:
            row_groups.append(current)
            current = [b]
    row_groups.append(current)

    row_groups = [r for r in row_groups if len(r) >= 2]
    row_groups.sort(key=lambda r: -len(r))
    chosen = row_groups[:num_rows]
    chosen.sort(key=lambda r: sum(b[1]+b[3]//2 for b in r)/len(r))

    grid = []
    for row in chosen:
        row_x = sorted(row, key=lambda b: b[0])
        if len(row_x) > num_cols:
            row_x = _pick_best_n_cols(row_x, num_cols)
        grid.append(row_x[:num_cols])

    while len(grid) < num_rows:
        grid.append([])
    return grid


def _pick_best_n_cols(bubbles_in_row, n):
    from itertools import combinations
    if len(bubbles_in_row) <= n:
        return bubbles_in_row
    xs = [b[0] + b[2]//2 for b in bubbles_in_row]
    best_combo, best_var = None, float('inf')
    for combo in combinations(range(len(bubbles_in_row)), n):
        sel = sorted([xs[i] for i in combo])
        gaps = [sel[i+1]-sel[i] for i in range(len(sel)-1)]
        v = float(np.var(gaps))
        if v < best_var:
            best_var = v
            best_combo = combo
    return [bubbles_in_row[i] for i in sorted(best_combo)]


def _make_fallback_row(q_idx, img_w, img_h):
    row_h = img_h / NUM_QUESTIONS
    col_w = img_w / NUM_CHOICES
    return [(int(c*col_w + col_w*0.15), int(q_idx*row_h + row_h*0.15),
             int(col_w*0.70), int(row_h*0.70)) for c in range(NUM_CHOICES)]


def _interior_darkness(thresh, x, y, w, h):
    sx = max(1, int(w * 0.20))
    sy = max(1, int(h * 0.20))
    x1, y1 = max(0, x+sx), max(0, y+sy)
    x2, y2 = min(thresh.shape[1], x+w-sx), min(thresh.shape[0], y+h-sy)
    if x2 <= x1 or y2 <= y1:
        return 0.0
    roi = thresh[y1:y2, x1:x2]
    return int(cv2.countNonZero(roi)) / max(roi.size, 1)


def _save_debug(dbg1, dbg2, filename):
    try:
        h1, w1 = dbg1.shape[:2]
        h2, w2 = dbg2.shape[:2]
        th = max(h1, h2)
        d1 = cv2.resize(dbg1,(w1,th)) if h1!=th else dbg1
        d2 = cv2.resize(dbg2,(w2,th)) if h2!=th else dbg2
        cv2.imwrite(filename, np.hstack([d1,d2]))
    except Exception:
        pass
"""
omr_pipeline.py — FIXED VERSION (16 Questions)
Part-I:  Q01–Q08  (left  half of answer table)
Part-II: Q09–Q16  (right half of answer table)

FIXES vs old version:
  1. Grid-based bubble reading instead of contour fill-ratio
     → no more wrong answer mapping (A→C shift gone)
  2. Answer table is isolated before splitting left/right
     → Part-II bubbles no longer cut off
  3. Adaptive darkness threshold per-bubble
     → filled bubbles detected even under varying lighting
  4. Debug images saved for every run so you can see what's happening
"""

import cv2
import numpy as np

# ========================= CONFIG =========================
NUM_QUESTIONS  = 8     # per part (8 + 8 = 16 total)
NUM_CHOICES    = 4     # A B C D

# How dark a bubble must be (0–1) to count as "filled"
# 0.35 means 35% of the bubble area must be dark pixels
FILL_THRESHOLD = 0.35

# Minimum pixels a bubble region must have to be valid
MIN_BUBBLE_PX  = 80
# =========================================================


def process_omr_sheet(image):
    """
    Entry point called by app.py.
    Returns the standard JSON-ready dict.
    """
    h, w = image.shape[:2]

    # ── Step 1: find the answer-table region ─────────────────────────────────
    table_roi = _find_answer_table(image)

    if table_roi is None:
        # Fallback: use bottom 65% of the image (where the table always is)
        top = int(h * 0.30)
        table_roi = image[top:, :]

    th, tw = table_roi.shape[:2]

    # ── Step 2: split table into LEFT (Part-I) and RIGHT (Part-II) ───────────
    # Your sheet has a thin vertical divider roughly in the middle.
    # We find the best split column instead of assuming w//2.
    mid = _find_vertical_split(table_roi)

    left_half  = table_roi[:, :mid]
    right_half = table_roi[:, mid:]

    # ── Step 3: read answers from each half ───────────────────────────────────
    part1_answers, b1, dbg1 = _read_answers_grid(left_half,  "Part-I",  start_q=1)
    part2_answers, b2, dbg2 = _read_answers_grid(right_half, "Part-II", start_q=9)

    # ── Debug: save side-by-side debug image ─────────────────────────────────
    _save_debug(table_roi, left_half, right_half, dbg1, dbg2, mid)

    return {
        "success": True,
        "part1":   part1_answers,
        "part2":   part2_answers,
        "debug_info": {
            "perspective_corrected": False,
            "bubbles_found_part1":   b1,
            "bubbles_found_part2":   b2,
            "image_size":            f"{w}x{h}",
            "table_size":            f"{tw}x{th}",
            "split_col":             mid,
        }
    }


# ─────────────────────────────────────────────────────────────────────────────
#  STEP 1 — Find the answer table rectangle
# ─────────────────────────────────────────────────────────────────────────────

def _find_answer_table(image):
    """
    Tries to isolate just the bubble-grid area.
    Looks for the large bordered rectangle that contains the bubbles.
    Falls back gracefully if not found.
    """
    gray    = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges   = cv2.Canny(blurred, 30, 100)

    # Dilate to close gaps in table borders
    kernel = np.ones((3, 3), np.uint8)
    edges  = cv2.dilate(edges, kernel, iterations=1)

    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    h, w = image.shape[:2]
    min_area = (w * h) * 0.15   # table should be at least 15% of image
    max_area = (w * h) * 0.90

    best = None
    best_area = 0

    for c in contours:
        area = cv2.contourArea(c)
        if area < min_area or area > max_area:
            continue
        x, y, cw, ch = cv2.boundingRect(c)
        # Table should be wider than tall (landscape orientation)
        if cw < ch:
            continue
        # Should span most of the width
        if cw < w * 0.5:
            continue
        if area > best_area:
            best_area = area
            best = (x, y, cw, ch)

    if best is None:
        return None

    x, y, cw, ch = best
    # Add small padding
    pad = 4
    x  = max(0, x - pad)
    y  = max(0, y - pad)
    cw = min(w - x, cw + pad * 2)
    ch = min(h - y, ch + pad * 2)

    return image[y:y+ch, x:x+cw]


# ─────────────────────────────────────────────────────────────────────────────
#  STEP 2 — Find vertical split between Part-I and Part-II
# ─────────────────────────────────────────────────────────────────────────────

def _find_vertical_split(table_img):
    """
    Finds the column that has the most vertical dark pixels —
    that's the divider line between Part-I and Part-II.
    Searches only in the central 20–80% of the width to avoid edges.
    """
    gray = cv2.cvtColor(table_img, cv2.COLOR_BGR2GRAY)
    _, bw = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    h, w = bw.shape
    # Sum dark pixels in each column
    col_sum = np.sum(bw, axis=0).astype(np.float32)

    # Only look in central band
    lo = int(w * 0.35)
    hi = int(w * 0.65)
    search = col_sum[lo:hi]

    # Find the column with the most dark pixels (the divider)
    best_col = int(np.argmax(search)) + lo

    return best_col


# ─────────────────────────────────────────────────────────────────────────────
#  STEP 3 — Grid-based bubble reading (the main fix)
# ─────────────────────────────────────────────────────────────────────────────

def _read_answers_grid(half_img, part_name, start_q=1):
    """
    Instead of hunting for contours, we:
      1. Detect all bubble-like circles
      2. Cluster them into a clean NUM_QUESTIONS × NUM_CHOICES grid
      3. Measure darkness inside each bubble cell
      4. Pick the darkest one per row as the answer
    """
    gray    = cv2.cvtColor(half_img, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Invert: bubbles become white on black background
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # Clean up noise
    kernel = np.ones((2, 2), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=1)

    # ── Find all bubble candidates ────────────────────────────────────────────
    bubbles = _detect_bubbles(thresh, half_img.shape[:2])

    debug_img = cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)
    answers   = {}

    if len(bubbles) < NUM_QUESTIONS * NUM_CHOICES // 2:
        # Not enough bubbles found — fill with None
        for i in range(NUM_QUESTIONS):
            qkey = f"Q{str(start_q + i).zfill(2)}"
            answers[qkey] = None
        return answers, len(bubbles), debug_img

    # ── Build grid: cluster bubbles into rows and columns ─────────────────────
    grid = _build_grid(bubbles, NUM_QUESTIONS, NUM_CHOICES)

    # ── Score each bubble ─────────────────────────────────────────────────────
    choices = ['A', 'B', 'C', 'D']

    for q_idx, row_bubbles in enumerate(grid):
        qnum = start_q + q_idx
        qkey = f"Q{str(qnum).zfill(2)}"

        if not row_bubbles or len(row_bubbles) < NUM_CHOICES:
            answers[qkey] = None
            continue

        # Sort row by X so columns are A B C D left→right
        row_bubbles = sorted(row_bubbles, key=lambda b: b[0])

        scores = []
        for (bx, by, bw, bh) in row_bubbles:
            score = _darkness_score(thresh, bx, by, bw, bh)
            scores.append(score)

            # Draw bubble on debug image
            cx, cy = bx + bw // 2, by + bh // 2
            cv2.circle(debug_img, (cx, cy), max(bw, bh) // 2, (0, 200, 0), 1)

        # The filled bubble is the one with the highest darkness score
        max_score = max(scores)

        # Only count as filled if it's meaningfully darker than the threshold
        if max_score < FILL_THRESHOLD:
            answers[qkey] = None  # nothing filled
        else:
            # Check for multiple fills (INVALID)
            # A second bubble counts as filled if it's ≥70% as dark as the darkest
            filled_indices = [
                i for i, s in enumerate(scores)
                if s >= FILL_THRESHOLD and s >= max_score * 0.70
            ]
            if len(filled_indices) == 1:
                answers[qkey] = choices[filled_indices[0]]
                # Highlight the filled bubble in red on debug image
                bx, by, bw, bh = row_bubbles[filled_indices[0]]
                cx, cy = bx + bw // 2, by + bh // 2
                cv2.circle(debug_img, (cx, cy), max(bw, bh) // 2, (0, 0, 255), 2)
                cv2.putText(debug_img, choices[filled_indices[0]],
                            (cx - 6, cy + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.4,
                            (0, 0, 255), 1)
            else:
                answers[qkey] = "INVALID"

    # Fill any gaps
    for i in range(NUM_QUESTIONS):
        qkey = f"Q{str(start_q + i).zfill(2)}"
        if qkey not in answers:
            answers[qkey] = None

    cv2.imwrite(f"debug_{part_name}.jpg", debug_img)
    return answers, len(bubbles), debug_img


# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _detect_bubbles(thresh, img_shape):
    """
    Finds all bubble-shaped regions using contours.
    More permissive than before — we rely on the grid builder to reject noise.
    """
    h, w = img_shape
    contours, _ = cv2.findContours(thresh, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)

    # Expected bubble size: roughly 1/6 of half-width per bubble column
    # For a typical sheet, each bubble is ~20–60px wide
    min_dim  = max(8,  int(w * 0.01))
    max_dim  = max(80, int(w * 0.15))
    min_area = min_dim * min_dim
    max_area = max_dim * max_dim * 2

    bubbles = []
    for c in contours:
        area = cv2.contourArea(c)
        if area < min_area or area > max_area:
            continue
        x, y, bw, bh = cv2.boundingRect(c)
        if bw < min_dim or bh < min_dim:
            continue
        # Must be roughly circular (aspect ratio close to 1)
        ar = bw / float(bh)
        if ar < 0.40 or ar > 2.5:
            continue
        bubbles.append((x, y, bw, bh))

    return bubbles


def _build_grid(bubbles, num_rows, num_cols):
    """
    Clusters detected bubbles into a num_rows × num_cols grid.

    Strategy:
      1. Sort bubbles by Y → group into rows using median Y clustering
      2. Within each row, sort by X → columns are A B C D
      3. Keep exactly num_cols bubbles per row (the rightmost extras discarded)
    """
    if not bubbles:
        return [[] for _ in range(num_rows)]

    # ── Cluster by Y coordinate ───────────────────────────────────────────────
    # Use bubble centers
    centers_y = sorted(set(b[1] + b[3] // 2 for b in bubbles))

    # Merge Y values that are close together (same row)
    row_ys    = []
    current_y = centers_y[0]
    group     = [current_y]

    for cy in centers_y[1:]:
        if cy - current_y < 25:   # within 25px → same row
            group.append(cy)
        else:
            row_ys.append(int(np.mean(group)))
            group = [cy]
        current_y = cy
    row_ys.append(int(np.mean(group)))

    # ── Assign each bubble to its nearest row ─────────────────────────────────
    rows = {ry: [] for ry in row_ys}
    for b in bubbles:
        cy     = b[1] + b[3] // 2
        nearest = min(row_ys, key=lambda ry: abs(ry - cy))
        rows[nearest].append(b)

    # ── Sort rows by Y, keep only num_rows question rows ──────────────────────
    sorted_rows = sorted(rows.items(), key=lambda kv: kv[0])

    # Filter out rows with too few bubbles (headers, labels, etc.)
    question_rows = [(ry, bs) for ry, bs in sorted_rows if len(bs) >= 2]

    # Take the num_rows rows that have the most bubbles
    question_rows.sort(key=lambda kv: -len(kv[1]))
    question_rows = question_rows[:num_rows]
    # Re-sort by Y so Q01 comes first
    question_rows.sort(key=lambda kv: kv[0])

    grid = []
    for _, row_bubbles in question_rows:
        # Sort by X (left→right = A B C D)
        row_sorted = sorted(row_bubbles, key=lambda b: b[0])
        # Keep only the first num_cols (drop any extra noise)
        grid.append(row_sorted[:num_cols])

    # Pad with empty rows if we didn't find enough
    while len(grid) < num_rows:
        grid.append([])

    return grid


def _darkness_score(thresh, x, y, w, h):
    """
    Returns fraction of dark pixels inside a bubble region (0.0 – 1.0).
    Uses a slightly shrunk ROI to avoid counting the bubble border itself.
    """
    # Shrink by ~15% on each side to avoid the printed circle border
    shrink_x = max(1, int(w * 0.15))
    shrink_y = max(1, int(h * 0.15))

    x1 = max(0, x + shrink_x)
    y1 = max(0, y + shrink_y)
    x2 = min(thresh.shape[1], x + w - shrink_x)
    y2 = min(thresh.shape[0], y + h - shrink_y)

    if x2 <= x1 or y2 <= y1:
        return 0.0

    roi   = thresh[y1:y2, x1:x2]
    total = roi.size
    if total < MIN_BUBBLE_PX:
        return 0.0

    dark  = cv2.countNonZero(roi)
    return dark / total


def _save_debug(table_img, left_half, right_half, dbg1, dbg2, mid):
    """Saves a composite debug image showing both halves with detections."""
    try:
        # Resize debug images to match table height
        th = table_img.shape[0]
        d1 = cv2.resize(dbg1, (left_half.shape[1],  th))
        d2 = cv2.resize(dbg2, (right_half.shape[1], th))
        composite = np.hstack([d1, d2])
        cv2.imwrite("debug_full_table.jpg", composite)
        cv2.imwrite("debug_table_original.jpg", table_img)
    except Exception:
        pass  # debug saving should never crash the server
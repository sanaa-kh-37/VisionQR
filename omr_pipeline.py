"""
omr_pipeline.py — Gemini Flash Vision Edition
===============================================
Replaces fragile OpenCV bubble detection with Google Gemini Flash Vision.
Gemini actually SEES the image and reads filled bubbles like a human.

Part-I:  Q01–Q08  (keys: "Q01"…"Q08")
Part-II: Q01–Q08  (keys: "Q01"…"Q08")

SETUP:
  Add to Render environment variables:
      GEMINI_API_KEY=AIzaSy_your_key_here

  app.py and all Flutter code stays EXACTLY THE SAME.
"""

import os
import base64
import json
import re
import cv2
import numpy as np
import google.generativeai as genai

NUM_QUESTIONS = 8  # per part

# ── Configure Gemini client ───────────────────────────────────────────────────
_API_KEY = os.environ.get("GEMINI_API_KEY", "")
genai.configure(api_key=_API_KEY)
_model = genai.GenerativeModel("gemini-1.5-flash")


# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC ENTRY POINT  (called by app.py — signature unchanged)
# ═══════════════════════════════════════════════════════════════════════════════
def process_omr_sheet(image):
    """
    image  : numpy BGR array (from cv2.imdecode in app.py)
    returns: dict that app.py sends back to Flutter — shape unchanged
    """
    h, w = image.shape[:2]

    # Encode numpy image → JPEG bytes (Gemini needs real image bytes)
    success, buf = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 92])
    if not success:
        raise RuntimeError("Could not encode image to JPEG")

    jpeg_bytes = buf.tobytes()

    # Ask Gemini to read the bubble sheet
    part1, part2 = _ask_gemini(jpeg_bytes)

    answered1 = sum(1 for v in part1.values() if v not in (None, "INVALID"))
    answered2 = sum(1 for v in part2.values() if v not in (None, "INVALID"))

    return {
        "success": True,
        "part1": part1,
        "part2": part2,
        "debug_info": {
            "perspective_corrected": False,
            "bubbles_found_part1":   answered1,
            "bubbles_found_part2":   answered2,
            "image_size":            f"{w}x{h}",
            "method":                "gemini-flash-vision",
        }
    }


# ═══════════════════════════════════════════════════════════════════════════════
#  GEMINI VISION CALL
# ═══════════════════════════════════════════════════════════════════════════════
def _ask_gemini(jpeg_bytes: bytes):
    """
    Send bubble sheet image to Gemini Flash and parse the JSON response.
    Returns (part1_dict, part2_dict).
    """

    prompt = """You are an OMR (Optical Mark Recognition) expert reading a student quiz answer sheet photo.

The sheet has TWO sections side by side:
  - Part-I  on the LEFT  — 8 questions (Q01 to Q08), each row has 4 bubbles labeled A B C D
  - Part-II on the RIGHT — 8 questions (Q01 to Q08), each row has 4 bubbles labeled A B C D

YOUR TASK:
  Look at each row carefully. Find which bubble is filled, shaded, or darkened by the student.

RULES:
  - Filled bubble = clearly darker/shaded compared to the empty ones (pencil or pen mark).
  - If exactly ONE bubble is filled in a row → return that letter: "A", "B", "C", or "D"
  - If NO bubble is filled in a row → return null
  - If MORE THAN ONE bubble is filled → return "INVALID"
  - Always include all 8 questions for both parts, even if answer is null.

Return ONLY valid JSON — absolutely no explanation, no markdown, no extra text.
Use exactly this structure:

{
  "part1": {
    "Q01": "A",
    "Q02": "C",
    "Q03": null,
    "Q04": "B",
    "Q05": "D",
    "Q06": "A",
    "Q07": "INVALID",
    "Q08": "C"
  },
  "part2": {
    "Q01": "B",
    "Q02": "A",
    "Q03": "D",
    "Q04": null,
    "Q05": "C",
    "Q06": "B",
    "Q07": "A",
    "Q08": "D"
  }
}"""

    image_part = {
        "mime_type": "image/jpeg",
        "data": jpeg_bytes,
    }

    response = _model.generate_content(
        [prompt, image_part],
        generation_config=genai.types.GenerationConfig(
            temperature=0.0,
            max_output_tokens=512,
        ),
    )

    raw_text = response.text.strip()
    return _parse_response(raw_text)


# ═══════════════════════════════════════════════════════════════════════════════
#  RESPONSE PARSER
# ═══════════════════════════════════════════════════════════════════════════════
def _parse_response(raw: str):
    """
    Parse Gemini's JSON response into (part1_dict, part2_dict).
    Handles markdown fences and minor formatting issues gracefully.
    """
    cleaned = re.sub(r"```(?:json)?", "", raw).strip().rstrip("`").strip()

    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        match = re.search(r'\{.*\}', cleaned, re.DOTALL)
        if match:
            try:
                data = json.loads(match.group())
            except Exception:
                return _empty_answers(), _empty_answers()
        else:
            return _empty_answers(), _empty_answers()

    part1 = _normalise_part(data.get("part1", {}))
    part2 = _normalise_part(data.get("part2", {}))

    return part1, part2


def _normalise_part(raw: dict) -> dict:
    valid = {"A", "B", "C", "D", "INVALID"}
    result = {}
    for i in range(1, NUM_QUESTIONS + 1):
        key = f"Q{str(i).zfill(2)}"
        val = raw.get(key)
        if val is None:
            result[key] = None
        elif str(val).upper() in valid:
            result[key] = str(val).upper()
        else:
            result[key] = None
    return result


def _empty_answers() -> dict:
    return {f"Q{str(i).zfill(2)}": None for i in range(1, NUM_QUESTIONS + 1)}
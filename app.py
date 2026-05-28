"""
app.py  —  VisionQR OMR Server
=====================================
Run this on your PC or any free server.
Command:  python app.py

What this file does:
  - Starts a web server on port 5000
  - Listens for POST requests at /scan-omr
  - Receives a base64 image from Flutter
  - Calls the OMR pipeline and returns JSON answers
"""

from flask import Flask, request, jsonify
import base64
import numpy as np
import cv2
from omr_pipeline import process_omr_sheet

app = Flask(__name__)


# ─── Health check ────────────────────────────────────────────────────────────
# Flutter can call GET /ping to check if server is alive before scanning
@app.route('/ping', methods=['GET'])
def ping():
    return jsonify({"status": "ok", "message": "OMR server is running"})


# ─── Main OMR endpoint ────────────────────────────────────────────────────────
@app.route('/scan-omr', methods=['POST'])
def scan_omr():
    """
    Expects JSON body:
        { "image": "<base64 string of the photo>" }

    Returns JSON:
        {
            "success": true,
            "part1": { "Q01": "A", "Q02": null, "Q03": "INVALID", ... },
            "part2": { "Q01": "B", "Q02": "C", ... },
            "debug_info": { "bubbles_found": 64, "perspective_corrected": true }
        }
    """
    # 1. Parse incoming request
    data = request.get_json()
    if not data or 'image' not in data:
        return jsonify({"success": False, "error": "No image provided"}), 400

    # 2. Decode base64 → numpy image array (same format as cv2.imread)
    try:
        image_bytes = base64.b64decode(data['image'])
        np_array    = np.frombuffer(image_bytes, dtype=np.uint8)
        image       = cv2.imdecode(np_array, cv2.IMREAD_COLOR)

        if image is None:
            return jsonify({"success": False, "error": "Could not decode image"}), 400

    except Exception as e:
        return jsonify({"success": False, "error": f"Image decode failed: {str(e)}"}), 400

    # 3. Run the OMR pipeline (all the OpenCV work happens in omr_pipeline.py)
    try:
        result = process_omr_sheet(image)
        return jsonify(result)

    except Exception as e:
        return jsonify({"success": False, "error": f"OMR processing failed: {str(e)}"}), 500


# ─── Start server ─────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print("=" * 50)
    print("  VisionQR OMR Server starting...")
    print("  URL: http://0.0.0.0:5000")
    print("=" * 50)
    import os
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port, debug=False)

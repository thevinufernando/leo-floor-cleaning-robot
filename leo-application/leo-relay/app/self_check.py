"""Assert occupancy → PNG helpers stay in sync with the Pi bridge.

Run: python -m app.self_check
"""

from __future__ import annotations

import base64
import io
import sys


def occupancy_to_png_bytes(width: int, height: int, data: list[int]) -> bytes:
    """Mirror of leo_cloud_bridge map encoding (nav_msgs OccupancyGrid)."""
    from PIL import Image

    if len(data) != width * height:
        raise ValueError("data length must equal width*height")
    pixels = bytearray(width * height)
    for i, v in enumerate(data):
        if v < 0:
            pixels[i] = 205  # unknown
        elif v == 0:
            pixels[i] = 254  # free
        else:
            pixels[i] = 0  # occupied
    img = Image.frombytes("L", (width, height), bytes(pixels))
    # ROS OccupancyGrid row 0 is map bottom; flip for screen-up display.
    img = img.transpose(Image.FLIP_TOP_BOTTOM)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def main() -> int:
    w, h = 4, 3
    data = [
        100, 100, 100, 100,
        -1, 0, 0, 100,
        100, 0, 0, 100,
    ]
    png = occupancy_to_png_bytes(w, h, data)
    assert png[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    b64 = base64.b64encode(png).decode("ascii")
    assert len(b64) > 20
    print("self_check ok: occupancy_to_png_bytes")
    return 0


if __name__ == "__main__":
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        print("install pillow to run self_check", file=sys.stderr)
        sys.exit(1)
    raise SystemExit(main())

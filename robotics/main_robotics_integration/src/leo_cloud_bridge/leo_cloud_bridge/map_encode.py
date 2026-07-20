"""Encode nav_msgs/OccupancyGrid into a PNG for phone display."""

from __future__ import annotations

import base64
import io

from PIL import Image


def occupancy_grid_to_png_b64(width: int, height: int, data) -> str:
    """
    Convert occupancy values (-1 unknown, 0 free, 1..100 occupied) to PNG.

    Flips vertically so row 0 (map bottom in ROS) appears at the bottom
    of the image on screen.
    """
    if width <= 0 or height <= 0:
        raise ValueError('invalid grid size')
    if len(data) != width * height:
        raise ValueError(
            f'data length {len(data)} != width*height {width * height}')

    pixels = bytearray(width * height)
    for i, v in enumerate(data):
        if v < 0:
            pixels[i] = 205
        elif v == 0:
            pixels[i] = 254
        else:
            # occupied / likely occupied
            pixels[i] = 0

    img = Image.frombytes('L', (width, height), bytes(pixels))
    img = img.transpose(Image.FLIP_TOP_BOTTOM)
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    return base64.b64encode(buf.getvalue()).decode('ascii')

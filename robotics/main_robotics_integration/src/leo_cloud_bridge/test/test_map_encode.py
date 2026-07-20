"""Unit check for occupancy PNG encoding (no ROS required)."""

from leo_cloud_bridge.map_encode import occupancy_grid_to_png_b64


def test_occupancy_encode_roundtrip_png_header():
    w, h = 4, 3
    data = [
        100, 100, 100, 100,
        -1, 0, 0, 100,
        100, 0, 0, 100,
    ]
    b64 = occupancy_grid_to_png_b64(w, h, data)
    import base64
    raw = base64.b64decode(b64)
    assert raw[:8] == b'\x89PNG\r\n\x1a\n'

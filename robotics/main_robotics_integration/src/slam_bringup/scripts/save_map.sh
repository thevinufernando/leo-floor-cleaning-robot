#!/usr/bin/env bash
# Save the current slam_toolbox occupancy grid to disk.
#
# Usage:
#   ./save_map.sh [map_name] [output_dir]
#
# Defaults: map_name=map, output_dir=~/maps
# Produces <output_dir>/<map_name>.pgm + <output_dir>/<map_name>.yaml via
# nav2_map_server's map_saver_cli (subscribes to /map).
#
# Run this on the Pi WHILE mapping.launch.py (slam_toolbox) is still running.
set -euo pipefail

MAP_NAME="${1:-map}"
OUT_DIR="${2:-$HOME/maps}"

mkdir -p "$OUT_DIR"

echo "Saving /map to ${OUT_DIR}/${MAP_NAME}.{pgm,yaml} ..."
ros2 run nav2_map_server map_saver_cli \
  -f "${OUT_DIR}/${MAP_NAME}" \
  --ros-args -p save_map_timeout:=10.0

echo "Done. Map written to ${OUT_DIR}/${MAP_NAME}.pgm and .yaml"

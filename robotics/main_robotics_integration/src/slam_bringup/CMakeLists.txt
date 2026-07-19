cmake_minimum_required(VERSION 3.8)
project(slam_bringup)

find_package(ament_cmake REQUIRED)

install(DIRECTORY launch config rviz
  DESTINATION share/${PROJECT_NAME}
)

install(PROGRAMS scripts/save_map.sh
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()

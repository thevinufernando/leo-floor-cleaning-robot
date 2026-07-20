"""setup.py for leo_cloud_bridge."""

from glob import glob
import os

from setuptools import find_packages, setup

package_name = 'leo_cloud_bridge'

setup(
    name=package_name,
    version='0.1.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'),
         glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools', 'Pillow', 'websockets'],
    zip_safe=True,
    maintainer='thevinufpi',
    maintainer_email='thevinuworks1@gmail.com',
    description='Outbound WebSocket bridge for Leo live map + soft arm',
    license='Apache-2.0',
    extras_require={'test': ['pytest']},
    entry_points={
        'console_scripts': [
            'cloud_bridge_node = leo_cloud_bridge.cloud_bridge_node:main',
        ],
    },
)

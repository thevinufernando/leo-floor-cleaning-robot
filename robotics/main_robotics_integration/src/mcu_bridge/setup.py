"""setup.py for the mcu_bridge ament_python package."""

from glob import glob
import os

from setuptools import find_packages, setup

package_name = 'mcu_bridge'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools', 'pyserial'],
    zip_safe=True,
    maintainer='thevinufpi',
    maintainer_email='thevinuworks1@gmail.com',
    description='Serial bridge between Raspberry Pi and STM32F722RET6 FreeRTOS MCU over USB CDC',
    license='Apache-2.0',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'bridge_node = mcu_bridge.bridge_node:main'
        ],
    },
)

from mcu_bridge.imu_text_parser import DEG_TO_RAD, G_TO_MPS2, parse_imu_line


def test_parses_valid_line():
    line = 'ACC[g]: 0.012 -0.003 0.998  GYRO[dps]: 0.10 -0.05 0.02  T[C]: 27.31'
    result = parse_imu_line(line)
    assert result is not None
    ax, ay, az, gx, gy, gz, temp_c = result
    assert ax == 0.012 * G_TO_MPS2
    assert ay == -0.003 * G_TO_MPS2
    assert az == 0.998 * G_TO_MPS2
    assert gx == 0.10 * DEG_TO_RAD
    assert gy == -0.05 * DEG_TO_RAD
    assert gz == 0.02 * DEG_TO_RAD
    assert temp_c == 27.31


def test_parses_line_with_trailing_mag_field():
    line = ('ACC[g]: 0.0 0.0 1.0  GYRO[dps]: 0.0 0.0 0.0  T[C]: 25.00'
            '  MAG[G]: 0.123 -0.045 0.210')
    result = parse_imu_line(line)
    assert result is not None


def test_rejects_non_matching_line():
    assert parse_imu_line('ICM42688 init FAILED (WHO_AM_I mismatch)') is None
    assert parse_imu_line('') is None
    assert parse_imu_line('garbage\r\n') is None

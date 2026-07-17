/*
 * Reference implementation of the Pi <-> MCU serial protocol for the
 * STM32F722RET6 FreeRTOS firmware. Must stay byte-for-byte in sync
 * with mcu_bridge/protocol.py on the ROS 2 side.
 *
 * Frame layout (little-endian multi-byte fields):
 *
 *   [START][MSG_ID][LEN][PAYLOAD...][CRC8][END]
 *
 *   START   1 byte   0xAA
 *   MSG_ID  1 byte   message type, see mcu_bridge_msg_id_t
 *   LEN     1 byte   number of payload bytes (0-255)
 *   PAYLOAD LEN bytes
 *   CRC8    1 byte   CRC-8/SMBUS (poly 0x07, init 0x00) over MSG_ID+LEN+PAYLOAD
 *   END     1 byte   0x55
 */

#ifndef MCU_BRIDGE_PROTOCOL_H
#define MCU_BRIDGE_PROTOCOL_H

#include <stdint.h>
#include <stddef.h>

#define MCU_BRIDGE_START_BYTE 0xAAu
#define MCU_BRIDGE_END_BYTE   0x55u

#define MCU_BRIDGE_CRC8_POLY 0x07u
#define MCU_BRIDGE_CRC8_INIT 0x00u

#define MCU_BRIDGE_MAX_PAYLOAD 255u

typedef enum {
    MCU_BRIDGE_MSG_CMD_VELOCITY = 0x01,
} mcu_bridge_msg_id_t;

/* CMD_VELOCITY payload: two little-endian float32s. The MCU is expected to
 * apply diff-drive kinematics itself (using its own wheel_separation) to
 * derive left/right wheel setpoints from these. */
typedef struct {
    float linear_x;   /* m/s */
    float angular_z;  /* rad/s */
} mcu_bridge_cmd_velocity_t;

static inline uint8_t mcu_bridge_crc8(const uint8_t *data, size_t len)
{
    uint8_t crc = MCU_BRIDGE_CRC8_INIT;
    for (size_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int b = 0; b < 8; b++) {
            if (crc & 0x80u) {
                crc = (uint8_t)((crc << 1) ^ MCU_BRIDGE_CRC8_POLY);
            } else {
                crc = (uint8_t)(crc << 1);
            }
        }
    }
    return crc;
}

/*
 * Byte-at-a-time frame parser, meant to be fed one incoming UART/USB-CDC
 * byte at a time from an ISR or a reader task. On a complete, CRC-valid
 * frame it returns 1 and fills msg_id/payload/payload_len; otherwise 0.
 * Not thread-safe: use one instance per receiving task.
 */
typedef enum {
    MCU_BRIDGE_WAIT_START,
    MCU_BRIDGE_WAIT_MSG_ID,
    MCU_BRIDGE_WAIT_LEN,
    MCU_BRIDGE_WAIT_PAYLOAD,
    MCU_BRIDGE_WAIT_CRC,
    MCU_BRIDGE_WAIT_END,
} mcu_bridge_parse_state_t;

typedef struct {
    mcu_bridge_parse_state_t state;
    uint8_t msg_id;
    uint8_t len;
    uint8_t payload[MCU_BRIDGE_MAX_PAYLOAD];
    uint8_t payload_idx;
    uint8_t crc;
} mcu_bridge_parser_t;

static inline void mcu_bridge_parser_init(mcu_bridge_parser_t *p)
{
    p->state = MCU_BRIDGE_WAIT_START;
}

/* Returns 1 when a complete valid frame has just been parsed into `p`. */
static inline int mcu_bridge_parser_feed(mcu_bridge_parser_t *p, uint8_t byte)
{
    switch (p->state) {
    case MCU_BRIDGE_WAIT_START:
        if (byte == MCU_BRIDGE_START_BYTE) {
            p->state = MCU_BRIDGE_WAIT_MSG_ID;
        }
        return 0;

    case MCU_BRIDGE_WAIT_MSG_ID:
        p->msg_id = byte;
        p->state = MCU_BRIDGE_WAIT_LEN;
        return 0;

    case MCU_BRIDGE_WAIT_LEN:
        p->len = byte;
        p->payload_idx = 0;
        p->state = (p->len == 0) ? MCU_BRIDGE_WAIT_CRC : MCU_BRIDGE_WAIT_PAYLOAD;
        return 0;

    case MCU_BRIDGE_WAIT_PAYLOAD:
        p->payload[p->payload_idx++] = byte;
        if (p->payload_idx >= p->len) {
            p->state = MCU_BRIDGE_WAIT_CRC;
        }
        return 0;

    case MCU_BRIDGE_WAIT_CRC: {
        uint8_t header[2 + MCU_BRIDGE_MAX_PAYLOAD];
        header[0] = p->msg_id;
        header[1] = p->len;
        for (uint8_t i = 0; i < p->len; i++) {
            header[2 + i] = p->payload[i];
        }
        uint8_t expected_crc = mcu_bridge_crc8(header, (size_t)(2 + p->len));
        p->state = MCU_BRIDGE_WAIT_END;
        if (byte != expected_crc) {
            p->state = MCU_BRIDGE_WAIT_START;
            return 0;
        }
        p->crc = byte;
        return 0;
    }

    case MCU_BRIDGE_WAIT_END:
        p->state = MCU_BRIDGE_WAIT_START;
        return (byte == MCU_BRIDGE_END_BYTE) ? 1 : 0;

    default:
        p->state = MCU_BRIDGE_WAIT_START;
        return 0;
    }
}

/* Example decode helper for CMD_VELOCITY once mcu_bridge_parser_feed()
 * returns 1 and p->msg_id == MCU_BRIDGE_MSG_CMD_VELOCITY. Assumes the MCU
 * is little-endian (true for Cortex-M7/F722 in its default configuration).
 */
static inline float mcu_bridge_decode_f32_le(const uint8_t *bytes)
{
    uint32_t bits =
        (uint32_t)bytes[0] |
        ((uint32_t)bytes[1] << 8) |
        ((uint32_t)bytes[2] << 16) |
        ((uint32_t)bytes[3] << 24);
    float out;
    __builtin_memcpy(&out, &bits, sizeof(out));
    return out;
}

static inline void mcu_bridge_decode_cmd_velocity(
    const mcu_bridge_parser_t *p, mcu_bridge_cmd_velocity_t *out)
{
    out->linear_x = mcu_bridge_decode_f32_le(&p->payload[0]);
    out->angular_z = mcu_bridge_decode_f32_le(&p->payload[4]);
}

#endif /* MCU_BRIDGE_PROTOCOL_H */

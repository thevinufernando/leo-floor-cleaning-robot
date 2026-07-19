/*
 * Reference of the Pi <-> MCU serial protocol for the STM32F722 FreeRTOS
 * firmware. The authoritative definition lives in the firmware's own
 * protocol.h (documented in PROTOCOL.md); this file mirrors it so the ROS 2
 * side (mcu_bridge/protocol.py) has a byte-for-byte C reference to check
 * against. Keep all three in sync.
 *
 * Frame layout (little-endian multi-byte fields):
 *
 *   +-------+-------+------+------+============+--------+--------+
 *   | SYNC0 | SYNC1 | TYPE | LEN  |  PAYLOAD   | CRC_LO | CRC_HI |
 *   | 0xAA  | 0x55  | 1 B  | 1 B  |  LEN bytes | 1 B    | 1 B    |
 *   +-------+-------+------+------+============+--------+--------+
 *
 *   SYNC0   1 byte   0xAA  frame start marker
 *   SYNC1   1 byte   0x55  frame start marker
 *   TYPE    1 byte   message type, see mcu_bridge_msg_type_t
 *   LEN     1 byte   payload length in bytes (0..32)
 *   PAYLOAD LEN bytes
 *   CRC16   2 bytes  CRC-16/CCITT-FALSE over TYPE+LEN+PAYLOAD, sent LE
 *
 * CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection, xor-out 0.
 */

#ifndef MCU_BRIDGE_PROTOCOL_H
#define MCU_BRIDGE_PROTOCOL_H

#include <stdint.h>
#include <stddef.h>

#define MCU_BRIDGE_SYNC0 0xAAu
#define MCU_BRIDGE_SYNC1 0x55u

#define MCU_BRIDGE_CRC16_POLY 0x1021u
#define MCU_BRIDGE_CRC16_INIT 0xFFFFu

#define MCU_BRIDGE_MAX_PAYLOAD 32u

typedef enum {
    MCU_BRIDGE_MSG_ODOMETRY = 0x01, /* MCU -> Pi, 20 B payload */
    MCU_BRIDGE_MSG_CMD_VEL  = 0x02, /* Pi -> MCU,  8 B payload */
} mcu_bridge_msg_type_t;

/* MSG_ODOMETRY payload: pose in odom frame + body twist, all float32 SI. */
typedef struct {
    float x;      /* m */
    float y;      /* m */
    float theta;  /* rad, wrapped to (-pi, pi] */
    float v;      /* m/s */
    float omega;  /* rad/s */
} mcu_bridge_odometry_t;

/* MSG_CMD_VEL payload: commanded body twist, float32 SI. The MCU applies
 * diff-drive inverse kinematics itself to derive per-wheel speeds. */
typedef struct {
    float v;      /* m/s,   + = forward */
    float omega;  /* rad/s, + = CCW / left turn */
} mcu_bridge_cmd_vel_t;

static inline uint16_t mcu_bridge_crc16(const uint8_t *data, size_t len)
{
    uint16_t crc = MCU_BRIDGE_CRC16_INIT;
    for (size_t i = 0; i < len; i++) {
        crc ^= (uint16_t)((uint16_t)data[i] << 8);
        for (int b = 0; b < 8; b++) {
            if (crc & 0x8000u) {
                crc = (uint16_t)((crc << 1) ^ MCU_BRIDGE_CRC16_POLY);
            } else {
                crc = (uint16_t)(crc << 1);
            }
        }
    }
    return crc;
}

/*
 * Byte-at-a-time frame parser, meant to be fed one incoming USB-CDC byte at
 * a time from an ISR or a reader task. On a complete, CRC-valid frame it
 * returns 1 and fills type/payload/len; otherwise 0. Not thread-safe: use
 * one instance per receiving task.
 */
typedef enum {
    MCU_BRIDGE_WAIT_SYNC0,
    MCU_BRIDGE_WAIT_SYNC1,
    MCU_BRIDGE_WAIT_TYPE,
    MCU_BRIDGE_WAIT_LEN,
    MCU_BRIDGE_WAIT_PAYLOAD,
    MCU_BRIDGE_WAIT_CRC_LO,
    MCU_BRIDGE_WAIT_CRC_HI,
} mcu_bridge_parse_state_t;

typedef struct {
    mcu_bridge_parse_state_t state;
    uint8_t type;
    uint8_t len;
    uint8_t payload[MCU_BRIDGE_MAX_PAYLOAD];
    uint8_t payload_idx;
    uint16_t crc_rx;
} mcu_bridge_parser_t;

static inline void mcu_bridge_parser_init(mcu_bridge_parser_t *p)
{
    p->state = MCU_BRIDGE_WAIT_SYNC0;
}

/* Returns 1 when a complete valid frame has just been parsed into `p`. */
static inline int mcu_bridge_parser_feed(mcu_bridge_parser_t *p, uint8_t byte)
{
    switch (p->state) {
    case MCU_BRIDGE_WAIT_SYNC0:
        if (byte == MCU_BRIDGE_SYNC0) {
            p->state = MCU_BRIDGE_WAIT_SYNC1;
        }
        return 0;

    case MCU_BRIDGE_WAIT_SYNC1:
        /* Allow a run of 0xAA before 0x55; only 0x55 advances. */
        if (byte == MCU_BRIDGE_SYNC1) {
            p->state = MCU_BRIDGE_WAIT_TYPE;
        } else if (byte != MCU_BRIDGE_SYNC0) {
            p->state = MCU_BRIDGE_WAIT_SYNC0;
        }
        return 0;

    case MCU_BRIDGE_WAIT_TYPE:
        p->type = byte;
        p->state = MCU_BRIDGE_WAIT_LEN;
        return 0;

    case MCU_BRIDGE_WAIT_LEN:
        p->len = byte;
        p->payload_idx = 0;
        if (p->len > MCU_BRIDGE_MAX_PAYLOAD) {
            p->state = MCU_BRIDGE_WAIT_SYNC0;   /* impossible length, resync */
        } else {
            p->state = (p->len == 0) ? MCU_BRIDGE_WAIT_CRC_LO
                                     : MCU_BRIDGE_WAIT_PAYLOAD;
        }
        return 0;

    case MCU_BRIDGE_WAIT_PAYLOAD:
        p->payload[p->payload_idx++] = byte;
        if (p->payload_idx >= p->len) {
            p->state = MCU_BRIDGE_WAIT_CRC_LO;
        }
        return 0;

    case MCU_BRIDGE_WAIT_CRC_LO:
        p->crc_rx = byte;
        p->state = MCU_BRIDGE_WAIT_CRC_HI;
        return 0;

    case MCU_BRIDGE_WAIT_CRC_HI: {
        p->crc_rx |= (uint16_t)((uint16_t)byte << 8);
        p->state = MCU_BRIDGE_WAIT_SYNC0;
        uint8_t body[2 + MCU_BRIDGE_MAX_PAYLOAD];
        body[0] = p->type;
        body[1] = p->len;
        for (uint8_t i = 0; i < p->len; i++) {
            body[2 + i] = p->payload[i];
        }
        return (mcu_bridge_crc16(body, (size_t)(2 + p->len)) == p->crc_rx)
               ? 1 : 0;
    }

    default:
        p->state = MCU_BRIDGE_WAIT_SYNC0;
        return 0;
    }
}

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

static inline void mcu_bridge_decode_cmd_vel(
    const mcu_bridge_parser_t *p, mcu_bridge_cmd_vel_t *out)
{
    out->v = mcu_bridge_decode_f32_le(&p->payload[0]);
    out->omega = mcu_bridge_decode_f32_le(&p->payload[4]);
}

#endif /* MCU_BRIDGE_PROTOCOL_H */

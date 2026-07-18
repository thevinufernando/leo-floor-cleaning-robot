#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <stdint.h>
#include <stddef.h>

/*
 * ============================================================================
 *  MCU <-> Raspberry Pi USB-serial (CDC) protocol
 * ============================================================================
 *
 *  Binary, little-endian, CRC16-checked frames. This header is the single
 *  source of truth for the wire format and is mirrored by the Python decoder
 *  on the Pi side (see the protocol notes shipped with the firmware).
 *
 *  Frame layout (on the wire):
 *
 *    +--------+--------+--------+--------+========+--------+--------+
 *    | SYNC0  | SYNC1  |  TYPE  |  LEN   | PAYLOAD| CRC_LO | CRC_HI |
 *    | 0xAA   | 0x55   | 1 byte | 1 byte | LEN B  | 1 byte | 1 byte |
 *    +--------+--------+--------+--------+========+--------+--------+
 *
 *    SYNC0/SYNC1 : fixed frame start marker (0xAA, 0x55)
 *    TYPE        : message type (see ProtocolMsgType)
 *    LEN         : payload length in bytes (0..PROTOCOL_MAX_PAYLOAD)
 *    PAYLOAD     : LEN bytes, little-endian packed struct for TYPE
 *    CRC16       : CRC-16/CCITT-FALSE over [TYPE, LEN, PAYLOAD], LE on wire
 *
 *  Direction:
 *    MSG_ODOMETRY : MCU  -> Pi   (pose + twist, 50 Hz)
 *    MSG_CMD_VEL  : Pi   -> MCU  (body twist command, cmd_vel)
 * ============================================================================
 */

/* Frame markers. */
#define PROTOCOL_SYNC0            0xAAu
#define PROTOCOL_SYNC1            0x55u

/* Largest payload we ever encode/decode. */
#define PROTOCOL_MAX_PAYLOAD      32u

/* Bytes of framing overhead: SYNC0 SYNC1 TYPE LEN + CRC_LO CRC_HI. */
#define PROTOCOL_OVERHEAD         6u

/* Maximum full frame size (used to size buffers). */
#define PROTOCOL_MAX_FRAME        (PROTOCOL_OVERHEAD + PROTOCOL_MAX_PAYLOAD)

/* Message type identifiers. */
typedef enum {
    MSG_ODOMETRY = 0x01,   /* MCU -> Pi : OdometryPayload */
    MSG_CMD_VEL  = 0x02,   /* Pi -> MCU : CmdVelPayload   */
} ProtocolMsgType;

/*
 * Payload structs. Packed so their memory layout equals the wire layout
 * (little-endian on this Cortex-M7). Field order/units are the contract.
 */
#pragma pack(push, 1)

/* MSG_ODOMETRY : robot pose in the odom frame + body twist. SI units. */
typedef struct {
    float x;        /* [m]     */
    float y;        /* [m]     */
    float theta;    /* [rad]   */
    float v;        /* [m/s]   */
    float omega;    /* [rad/s] */
} OdometryPayload;   /* 20 bytes */

/* MSG_CMD_VEL : commanded body twist (ROS cmd_vel). SI units. */
typedef struct {
    float v;        /* linear  [m/s]   */
    float omega;    /* angular [rad/s] */
} CmdVelPayload;     /* 8 bytes */

#pragma pack(pop)

/* CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF, no reflection, xorout 0). */
uint16_t Protocol_CRC16(const uint8_t *data, size_t len);

/*
 * Encode a frame into 'out' (must hold at least PROTOCOL_MAX_FRAME bytes).
 * Returns the total number of bytes written, or 0 on error (bad args / payload
 * too large).
 */
size_t Protocol_EncodeFrame(uint8_t type,
                            const void *payload, uint8_t payload_len,
                            uint8_t *out, size_t out_cap);

/*
 * Incremental byte-wise frame parser. Feed received bytes one at a time; when
 * a complete, CRC-valid frame is assembled the parser fills 'type' and copies
 * the payload into 'payload_out' (capacity payload_cap) and returns the
 * payload length via 'payload_len'.
 */
typedef struct {
    uint8_t  state;
    uint8_t  type;
    uint8_t  len;
    uint8_t  index;
    uint8_t  buf[PROTOCOL_MAX_PAYLOAD];
    uint16_t crc_rx;
} ProtocolParser;

void Protocol_ParserInit(ProtocolParser *p);

/*
 * Feed one received byte. Returns 1 when a valid frame has just completed (and
 * fills the outputs), 0 otherwise. Frames failing CRC are silently dropped.
 */
int Protocol_ParseByte(ProtocolParser *p, uint8_t byte,
                       uint8_t *type,
                       void *payload_out, uint8_t payload_cap,
                       uint8_t *payload_len);

#endif /* PROTOCOL_H */

#include "protocol.h"

#include <string.h>

/* CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no input/output reflection. */
uint16_t Protocol_CRC16(const uint8_t *data, size_t len)
{
    uint16_t crc = 0xFFFFu;

    for (size_t i = 0; i < len; i++)
    {
        crc ^= (uint16_t)data[i] << 8;
        for (int b = 0; b < 8; b++)
        {
            if (crc & 0x8000u)
                crc = (uint16_t)((crc << 1) ^ 0x1021u);
            else
                crc = (uint16_t)(crc << 1);
        }
    }
    return crc;
}

size_t Protocol_EncodeFrame(uint8_t type,
                            const void *payload, uint8_t payload_len,
                            uint8_t *out, size_t out_cap)
{
    if (out == NULL || payload_len > PROTOCOL_MAX_PAYLOAD)
        return 0;
    if ((payload_len > 0) && (payload == NULL))
        return 0;

    const size_t frame_len = (size_t)PROTOCOL_OVERHEAD + payload_len;
    if (out_cap < frame_len)
        return 0;

    out[0] = PROTOCOL_SYNC0;
    out[1] = PROTOCOL_SYNC1;
    out[2] = type;
    out[3] = payload_len;

    if (payload_len > 0)
        memcpy(&out[4], payload, payload_len);

    /* CRC covers TYPE, LEN and PAYLOAD (i.e. out[2 .. 3+payload_len]). */
    const uint16_t crc = Protocol_CRC16(&out[2], (size_t)payload_len + 2u);

    out[4 + payload_len] = (uint8_t)(crc & 0xFFu);        /* CRC_LO */
    out[5 + payload_len] = (uint8_t)((crc >> 8) & 0xFFu); /* CRC_HI */

    return frame_len;
}

/* Parser states. */
enum {
    ST_SYNC0 = 0,
    ST_SYNC1,
    ST_TYPE,
    ST_LEN,
    ST_PAYLOAD,
    ST_CRC_LO,
    ST_CRC_HI,
};

void Protocol_ParserInit(ProtocolParser *p)
{
    if (p == NULL)
        return;
    memset(p, 0, sizeof(*p));
    p->state = ST_SYNC0;
}

int Protocol_ParseByte(ProtocolParser *p, uint8_t byte,
                       uint8_t *type,
                       void *payload_out, uint8_t payload_cap,
                       uint8_t *payload_len)
{
    if (p == NULL)
        return 0;

    switch (p->state)
    {
    case ST_SYNC0:
        if (byte == PROTOCOL_SYNC0)
            p->state = ST_SYNC1;
        break;

    case ST_SYNC1:
        /* Allow a repeated 0xAA to still count as the start marker. */
        if (byte == PROTOCOL_SYNC1)
            p->state = ST_TYPE;
        else if (byte != PROTOCOL_SYNC0)
            p->state = ST_SYNC0;
        break;

    case ST_TYPE:
        p->type = byte;
        p->state = ST_LEN;
        break;

    case ST_LEN:
        p->len = byte;
        if (p->len > PROTOCOL_MAX_PAYLOAD)
        {
            /* Malformed length: resync. */
            p->state = ST_SYNC0;
        }
        else
        {
            p->index = 0;
            p->state = (p->len == 0) ? ST_CRC_LO : ST_PAYLOAD;
        }
        break;

    case ST_PAYLOAD:
        p->buf[p->index++] = byte;
        if (p->index >= p->len)
            p->state = ST_CRC_LO;
        break;

    case ST_CRC_LO:
        p->crc_rx = byte;
        p->state = ST_CRC_HI;
        break;

    case ST_CRC_HI:
    {
        p->crc_rx |= (uint16_t)byte << 8;
        p->state = ST_SYNC0;

        /* Recompute CRC over [TYPE, LEN, PAYLOAD] in one contiguous buffer. */
        uint8_t chk[2 + PROTOCOL_MAX_PAYLOAD];
        chk[0] = p->type;
        chk[1] = p->len;
        memcpy(&chk[2], p->buf, p->len);
        const uint16_t crc = Protocol_CRC16(chk, (size_t)p->len + 2u);

        if (crc == p->crc_rx)
        {
            if (type)        *type = p->type;
            if (payload_len) *payload_len = p->len;
            if (payload_out && p->len <= payload_cap)
                memcpy(payload_out, p->buf, p->len);
            return 1;
        }
        /* CRC mismatch: drop frame. */
        break;
    }

    default:
        p->state = ST_SYNC0;
        break;
    }

    return 0;
}

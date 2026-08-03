#include "usb_bridge.h"
#include "usbd_cdc_if.h"

#include "cmsis_os.h"

#include <string.h>

/*
 * Single-producer (USB IRQ) / single-consumer (USBBridge task) byte ring.
 * Power-of-two size so head/tail wrap with a mask. head is written only by the
 * producer, tail only by the consumer, so no lock is needed on either side as
 * long as the indices are read/written atomically (32-bit aligned on M7).
 */
#define RX_RING_SIZE   512u
#define RX_RING_MASK   (RX_RING_SIZE - 1u)

static volatile uint8_t  rx_ring[RX_RING_SIZE];
static volatile uint32_t rx_head;   /* next write index (producer) */
static volatile uint32_t rx_tail;   /* next read index  (consumer) */

void USBBridge_RxPush(const uint8_t *data, uint32_t len)
{
    if (data == NULL)
        return;

    uint32_t head = rx_head;

    for (uint32_t i = 0; i < len; i++)
    {
        uint32_t next = (head + 1u) & RX_RING_MASK;
        if (next == rx_tail)
            break;                 /* ring full: drop the rest */
        rx_ring[head] = data[i];
        head = next;
    }

    rx_head = head;
}

int USBBridge_RxPop(uint8_t *out)
{
    uint32_t tail = rx_tail;

    if (tail == rx_head)
        return 0;                  /* empty */

    if (out)
        *out = rx_ring[tail];
    rx_tail = (tail + 1u) & RX_RING_MASK;
    return 1;
}

int USBBridge_SendFrame(uint8_t type, const void *payload, uint8_t payload_len)
{
    uint8_t frame[PROTOCOL_MAX_FRAME];

    size_t n = Protocol_EncodeFrame(type, payload, payload_len,
                                    frame, sizeof(frame));
    if (n == 0)
        return 0;

    /* CDC_Transmit_FS returns USBD_BUSY while a previous packet is in flight.
       Retry a few times, yielding to let it drain, before giving up. */
    for (int attempt = 0; attempt < 5; attempt++)
    {
        if (CDC_Transmit_FS(frame, (uint16_t)n) == USBD_OK)
            return 1;
        osDelay(1);
    }
    return 0;
}

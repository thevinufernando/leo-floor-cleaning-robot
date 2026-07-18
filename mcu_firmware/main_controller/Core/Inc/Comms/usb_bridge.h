#ifndef USB_BRIDGE_H
#define USB_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#include "protocol.h"

/*
 * USB-serial bridge glue between the CDC driver and the USBBridge task.
 *
 *  RX: CDC_Receive_FS() (USB IRQ context) pushes raw bytes into a lock-free
 *      single-producer/single-consumer ring buffer via USBBridge_RxPush().
 *      The USBBridge task drains it with USBBridge_RxPop().
 *
 *  TX: USBBridge_SendFrame() encodes a protocol frame and hands it to
 *      CDC_Transmit_FS(), retrying briefly while the endpoint is busy.
 */

/* Called from CDC_Receive_FS (ISR context) to enqueue received bytes. */
void USBBridge_RxPush(const uint8_t *data, uint32_t len);

/* Drain one byte from the RX ring. Returns 1 if a byte was read, else 0. */
int USBBridge_RxPop(uint8_t *out);

/*
 * Encode and transmit a protocol frame over USB CDC. Returns 1 on success,
 * 0 if the payload is too large or the endpoint stayed busy.
 */
int USBBridge_SendFrame(uint8_t type, const void *payload, uint8_t payload_len);

#endif /* USB_BRIDGE_H */

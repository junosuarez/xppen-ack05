# XP-Pen ACK05-B Protocol Documentation

This document describes the HID protocol and physical layout of the XP-Pen ACK05-B Wireless Shortcut Remote, reverse-engineered through HID report analysis on macOS.

## Device Identification
- **Vendor ID**: `10429` (0x28BD)
- **Product ID**: `514` (0x0202)
- **Interface**: Composite HID Device (Keyboard, Mouse, Digitizer)

---

## Physical Layout

The device consists of 10 primary buttons and a rotary "scroll assembly" with a center button.

```text
    [ DIAL ]      [ K1 ] [ K2 ] [ K3 ] [ K7 ]
 (with Center ●)  [ K4 ] [ K5 ] [ K6 ] [ K7 ] (K7 is tall)
                  [ K8 ] [    K9    ] [ K10] (K9 is wide)
```

---

## HID Report Structure (Report ID 0x06)

Most interactions (K1-K10 and Dial rotation) are sent via **Report ID 06**. This report emulates a standard USB HID Keyboard.

### Report Format (8 Bytes)
| Byte | Description | Notes |
| :--- | :--- | :--- |
| 0 | Report ID | Always `06` |
| 1 | Modifiers | Bitmask (0x01: Ctrl, 0x02: Shift, 0x04: Alt) |
| 2 | Scancode | USB HID Keyboard Scancode |
| 3-7 | Reserved | Usually `00` |

### Key Mapping Table
| Physical Key | Modifier (B1) | Scancode (B2) | Emulated Shortcut |
| :--- | :--- | :--- | :--- |
| **K1** | `0x01` | `0x12` | Ctrl + O |
| **K2** | `0x01` | `0x11` | Ctrl + N |
| **K3** | `0x00` | `0x3E` | F5 |
| **K4** | `0x02` | `0x00` | Shift |
| **K5** | `0x01` | `0x00` | Ctrl |
| **K6** | `0x04` | `0x00` | Alt |
| **K7** | `0x01` | `0x16` | Ctrl + S |
| **K8** | `0x01` | `0x1D` | Ctrl + Z |
| **K9** | `0x00` | `0x2C` | Space |
| **K10** | `0x03` | `0x1D` | Ctrl + Shift + Z |

---

## Dial & Center Button

### Rotary Encoder (Scroll Wheel)
The dial rotation is sent as momentary keyboard shortcuts on Report ID 6.
- **Clockwise (CW)**: `06 01 57` (Ctrl + Keypad `+`)
- **Counter-Clockwise (CCW)**: `06 01 56` (Ctrl + Keypad `-`)

### Center Button (●)
The center button behavior varies by firmware but generally follows one of two patterns:

1. **The Heuristic Trigger**: In default mode, the center button often sends a **Null Report** (`06 00 00...`) on the keyboard interface without a preceding key-down.
   - **Detection Logic**: If an `ID 06` report arrives where all data bytes are `00`, and no other keys were previously held, it represents a Center Button pulse.
   
2. **The Control Signature**: Some firmware versions send a specific signature on **Report ID 01**.
   - **Signature**: `01 71 00`

---

## Advanced: Raw/Vendor Mode ("The Magic Knock")

The device can be switched from "Keyboard Emulation" mode to "Bitmask" mode (where every button is a unique bit) by sending an output report to the Vendor interface.

- **Interface**: Usage Page `0xFF0A`, Usage `0x01`
- **Command**: `02 B0 04 00 00 00 00 00 00 00` (Sent as Output Report ID 0x02)

*Note: This mode is primarily used by the official XP-Pen driver and may require USB connection or specific Bluetooth stack permissions to activate.*

---

## Implementation Notes
- **Ghosting/Overlap**: Because the device sends shortcuts like `Ctrl+S`, a naive bitmask decoder will flicker between "Ctrl" and "K7". Always use **Value-Based Decoding** (matching the whole report) or **Subset Suppression** (prioritize the mapping with the most active bits).
- **Redraw Latency**: Dial rotations are extremely fast. Visualizers should use a pulse-timer (e.g., 100ms) to ensure the highlight is visible to the human eye.

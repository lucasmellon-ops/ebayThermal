# UART protocol

Serial settings: **115200 baud, 8 data bits, no parity, 1 stop bit, no flow control**, 3.3 V logic.

At power-up the camera transmits six ASCII `1` bytes (`31 31 31 31 31 31`). It is otherwise silent until asked.

## Request (host to camera), 23 bytes

```
55 43 49   12 00   <16-byte body>   <CRC lo> <CRC hi>
"U C I"    length   command          CRC-16/XMODEM of the 16-byte body
           (18 = body + CRC, little-endian)
```

Body layout (offsets are zero-based; unused bytes are `00`):

| Offset | Meaning |
|---|---|
| 0 | Class |
| 1 | Module |
| 2 | Command. `0x8x` = read, `0x4x` = write |
| 4 | Argument (which item to read, or the value for some writes) |
| 5 | Value for some writes (zoom, palette) |
| 12 | Number of data bytes wanted back. `0` for writes |

## Reply (camera to host)

```
BE AA   <len lo> <len hi>   <status>   <data ...>   <CRC lo> <CRC hi>   EB AA
```

- `len` counts the status byte plus the data bytes. Total reply size is `len + 8`.
- The CRC is CRC-16/XMODEM over everything from `BE AA` up to the last data byte.
- `status` `00` = OK. A request the camera doesn't understand gets `BE AA 01 00 FF 8B 4A EB AA` (status `FF`).

CRC-16/XMODEM: polynomial `0x1021`, initial value `0`, no reflection, sent low byte first.

## Commands used by ThermalCam.ps1

Reads marked "confirmed" returned a valid checksum and a sensible value on the real camera.

### Reads

| Item | Class | Module | Cmd | Arg (offset 4) | Size | Result | Confirmed |
|---|---|---|---|---|---|---|---|
| Device name | 01 | 01 | 81 | 1 | 0x1E | Text, null-terminated | Yes (`TIF384`) |
| Firmware | 01 | 01 | 81 | 2 | 0x0C | Text | Yes (`00.00.00.03`) |
| Part number | 01 | 01 | 81 | 6 | 0x40 | Text | Yes (`TIFS384`) |
| Serial number | 01 | 01 | 81 | 7 | 0x40 | Text | Yes |
| Sensor type | 01 | 01 | 81 | 14 | 0x40 | Text | Yes (`B33W`) |
| Sensor ID | 01 | 01 | 81 | 15 | 0x40 | Binary | Yes, meaning unknown |
| Preview width | 10 | 03 | 81 | 2 | 2 | 16-bit little-endian | Yes (780) |
| Preview height | 10 | 03 | 81 | 3 | 2 | 16-bit little-endian | Yes (576) |
| Zoom | 01 | 31 | 82 | 0 | 1 | Value / 10 = zoom factor | Yes |
| Palette index | 10 | 03 | 85 | 0 | 1 | Index | Yes |
| Palette name | 01 | 32 | 83 | index | 10 | Text | Only index 0 answers (`white_hot`) |
| Brightness | 10 | 04 | 87 | 1 | 1 | 0 to 100 | Yes (50) |
| Contrast | 10 | 04 | 88 | 1 | 1 | 0 to 100 | Yes (50) |
| Mirror/flip | 10 | 10 | 83 | 0 | 1 | 0 to 3 | Yes (0) |

Text fields can have leftover bytes after the first null. Stop reading at the first `00`.

### Writes

| Item | Class | Module | Cmd | Value goes in | Range | Confirmed |
|---|---|---|---|---|---|---|
| Zoom | 01 | 31 | 42 | offset 5 = floor((zoom + 0.05) x 10) | 1.0 to 8.0 | Yes, picture zooms |
| Palette index | 10 | 03 | 45 | offset 5 | 0 to 11 | Yes. Replies status `01` but the value is stored. Only 0 and 10 change the picture |
| Brightness | 10 | 04 | 47 | offset 4 | 0 to 100 | From the library only, not yet tried |
| Contrast | 10 | 04 | 48 | offset 4 | 0 to 100 | From the library only, not yet tried |
| Mirror/flip | 10 | 10 | 43 | offset 4 | 0 none, 1 mirror, 2 flip, 3 both | From the library only, not yet tried |

The library has a second set of mirror/flip commands (modules `01 2C` and `01 35`) for other camera families. Because this camera answers the `10 10 83` read, the matching `10 10 43` write is the one used here.

### Example frames

All of these have been sent to the real camera except the brightness, contrast and mirror writes, which are built by the same rule.

| Action | Bytes |
|---|---|
| Read device name | `55 43 49 12 00 01 01 81 00 01 00 00 00 00 00 00 00 1E 00 00 00 4F 90` |
| Read zoom | `55 43 49 12 00 01 31 82 00 00 00 00 00 00 00 00 00 01 00 00 00 4E 02` |
| Set zoom 2.0x | `55 43 49 12 00 01 31 42 00 00 14 00 00 00 00 00 00 00 00 00 00 41 0C` |
| Read palette | `55 43 49 12 00 10 03 85 00 00 00 00 00 00 00 00 00 01 00 00 00 21 67` |
| Set palette 10 | `55 43 49 12 00 10 03 45 00 00 0A 00 00 00 00 00 00 00 00 00 00 69 6F` |
| Read brightness | `55 43 49 12 00 10 04 87 00 01 00 00 00 00 00 00 00 01 00 00 00 01 EA` |
| Set brightness 60 | `55 43 49 12 00 10 04 47 00 3C 00 00 00 00 00 00 00 00 00 00 00 8D AC` |
| Read contrast | `55 43 49 12 00 10 04 88 00 01 00 00 00 00 00 00 00 01 00 00 00 6C 71` |
| Set contrast 60 | `55 43 49 12 00 10 04 48 00 3C 00 00 00 00 00 00 00 00 00 00 00 E0 37` |
| Read mirror/flip | `55 43 49 12 00 10 10 83 00 00 00 00 00 00 00 00 00 01 00 00 00 E9 C1` |
| Set mirror/flip 1 | `55 43 49 12 00 10 10 43 00 01 00 00 00 00 00 00 00 00 00 00 00 E9 C8` |

## Palettes

The palette index accepts 0 to 11 and reads back whatever was written, but on this firmware only two change the image:

| Index | Result |
|---|---|
| 0 | White hot |
| 10 | Black hot |
| 1 to 9, 11 | Stored, no visible change |

Colour palettes have to be applied after the camera, for example on a PC from a composite capture device.

## Open questions

- **Status `01` on palette writes.** The write takes effect anyway. Meaning unknown.
- **Palette count query** (`01 32 83`, arg `FF`) returns status `0A`.
- **"Info line" query** (`10 03 82`) returns `3F 01 18 31` for both index 0 and 1. Undecoded. It is not the resolution in any obvious encoding.
- **Sensor ID.** The stable part looks like `8A 2F 17 04 05 00` followed by space padding. Undecoded.
- **Native sensor resolution** is not exposed by any command found so far.

## Commands deliberately not used

The same library contains commands that write to flash, wipe settings or recalibrate the sensor. They share command bytes with harmless ones in other modules, so never "try a nearby value". Known ones to avoid:

| What | Class / module / cmd |
|---|---|
| Save settings (several kinds) | `10 04 4B`, `10 04 51`, `10 10 49`, `10 10 51`, `10 11 43/54/63/73/78` |
| Restore defaults (several kinds) | `10 06 42`, `10 04 4D`, `10 04 52`, `10 11 45/56/65/75/7A` |
| Shutter / flat-field update | `10 02 43` |
| Also in the library | K-value, dead-pixel and lens-cover calibration, firmware download, reboot mode |

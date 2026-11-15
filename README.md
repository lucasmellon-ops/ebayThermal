# thermal-cam-uart

Notes and a PowerShell tool for talking to an analog (CVBS) thermal camera module
over its UART. The module was sold on eBay as a "Partizan 640 thermal imaging
camera 640x512", but it identifies itself as **TIF384 / TIFS384**.

Everything here was worked out on one unit. Treat it as a lab notebook, not a datasheet.

## What's in here

| File | What it is |
|---|---|
| [`ThermalCam.ps1`](ThermalCam.ps1) | PowerShell commands to read the camera's identity and change zoom, palette, brightness, contrast and mirror |
| [`docs/protocol.md`](docs/protocol.md) | The UART packet format, every command used, and the commands deliberately left out |
| [`docs/wiring-ft232h.md`](docs/wiring-ft232h.md) | Connecting the camera's UART to an FT232H (or any 3.3 V USB-UART adapter) |
| [`docs/lens-identification.md`](docs/lens-identification.md) | How to work out which lens and sensor size you have with a tape measure |

## Quick start (Windows)

1. Wire the camera's UART to a 3.3 V USB-UART adapter such as an FT232H. See [wiring](docs/wiring-ft232h.md).

   | Camera pin | Function |
   |---|---|
   | 1 | Power in (+) |
   | 2 | Common (ground) |
   | 3 | CVBS video out |
   | 4 | UART RX (commands in) |
   | 5 | UART TX (replies out) |
2. Open PowerShell in this folder and load the tool:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   . .\ThermalCam.ps1
   ```

   Pasting the whole file into a PowerShell window works too.
3. Pick the port and read the camera:

   ```powershell
   Cam-Ports          # see which COM ports exist
   Cam-Port COM10     # choose yours
   Cam-Info
   ```

Example `Cam-Info` output from the tested unit (serial partly masked):

```
Device name     TIF384
Part number     TIFS384
Firmware        00.00.00.03
Serial number   TFS38040XG0211xxxxx
Sensor type     B33W
Sensor ID       8A 2F 17 04 05 00 20 20 20 20 00 00 ...
Preview         780 x 576
Zoom            1.0x
Palette         0 (white hot)
Brightness      50
Contrast        50
Mirror/flip     0
```

## Commands

| Command | Effect | Status on the tested camera |
|---|---|---|
| `Cam-Info` | Read and print everything | Works |
| `Cam-Zoom 2.0` | Digital zoom, 1.0 to 8.0 in 0.1 steps | Works, picture zooms |
| `Cam-WhiteHot` / `Cam-BlackHot` | Palette 0 / palette 10 | Works, picture inverts |
| `Cam-Palette n` | Palette by number, 0 to 11 | Only 0 and 10 change the picture |
| `Cam-Brightness n` | 0 to 100 | Read works; write not yet tried |
| `Cam-Contrast n` | 0 to 100 | Read works; write not yet tried |
| `Cam-Mirror n` | 0 none, 1 mirror, 2 flip, 3 both | Read works; write not yet tried |

Each setter reads the value first, writes, then reads it back and prints
`before -> after`. If the first read fails, nothing is written.

The tool never sends save, restore-defaults, calibration, shutter or firmware
commands. Settings are expected to return to defaults after a power cycle, but
that has not been confirmed on this firmware.

## What the camera is

| Question | Answer | How sure |
|---|---|---|
| Serial settings | 115200 baud, 8N1, no flow control | Confirmed |
| Protocol | "UCI" framing as used by the Mini2 Android library | Confirmed by working commands |
| Video output | Analog PAL; camera reports a 780 x 576 preview | Confirmed (this is the output size, not the sensor size) |
| Palettes | White hot and black hot only | Confirmed by trying 0 to 11 |
| Sensor resolution | Probably 384 x 288 | Not proven. See [lens identification](docs/lens-identification.md) |
| Product | Probably a Partizan Pilotix T384 with a 4 mm lens | Inferred from the names and the field of view |

## Where the commands came from

The packet framing and command bytes were found by disassembling `libircmd.so`
and `libiruart.so` from the public
[Kodrea/MINI2-IR-Android-App](https://github.com/Kodrea/MINI2-IR-Android-App)
project, checked in both the arm64 and x86_64 builds, and then confirmed against
replies from the real camera. Credit for the underlying command set goes to that
project and the camera vendor's library it ships; check its licence before
reusing anything taken from it.

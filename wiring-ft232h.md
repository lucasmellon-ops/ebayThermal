# Wiring the camera UART to an FT232H

Any 3.3 V USB-UART adapter works the same way (the camera was first tested with a Flipper Zero's USB-UART bridge, which is 3.3 V). This page uses the FT232H because its pins are labelled differently from most adapters.

## The three wires

| FT232H pin | Direction | Camera |
|---|---|---|
| **D0** (ADBUS0, TXD) | adapter sends | camera **pin 4**, RX |
| **D1** (ADBUS1, RXD) | adapter receives | camera **pin 5**, TX |
| **GND** | shared ground | camera **pin 2**, common |

TX goes to RX and RX goes to TX. The ground wire is required even if the camera has its own power supply.

## Camera connector (5 pins)

| Pin | Function | Connects to |
|---|---|---|
| 1 | Power in (+) | Camera power supply (+) |
| 2 | Common (ground) | Power supply (-), video ground, and FT232H GND |
| 3 | CVBS analog video out | Centre pin of the video input |
| 4 | UART RX, receives commands | FT232H D0 (TXD) |
| 5 | UART TX, sends startup data and replies | FT232H D1 (RXD) |

Pin 2 is the single ground for power, video and serial, so all three grounds meet there.

Two things were not recorded and are worth checking on your own unit:

- **Which end is pin 1.** The camera's TX pin (5) idles at about 3.3 V and sends `31 31 31 31 31 31` (six ASCII `1`s) at power-up. Connect it to D1, open the port at 115200, power-cycle the camera, and you should see `111111`.
- **The supply voltage for pin 1.** Use the voltage the camera was sold for. Partizan's Pilotix T384 v1.1, which this camera most likely is, is listed at 5 to 12 V and up to 0.8 W.

If `Cam-Info` gets "no reply", swap the two data wires. That is the most common mistake and does no harm at 3.3 V.

## Rules that protect the camera and the adapter

- **Do not connect the FT232H's 3V3 pin to the camera.** It is an output and it cannot power the camera.
- **Power the camera from its own supply** at the voltage it was sold for. Connect only D0, D1 and GND to the adapter.
- **Keep the logic at 3.3 V.** The FT232H drives its pins at 3.3 V, which is what the camera was tested with, and its inputs are 5 V tolerant, so it is safe on the receiving side either way. Avoid adapters that drive 5 V into the camera's RX pin.
- **Wire with the power off**, then plug in USB, then power the camera.

## FT232H setup on Windows

1. Plug in the FT232H. Windows should install FTDI's driver and it appears as a COM port. Find it with:

   ```powershell
   . .\ThermalCam.ps1
   Cam-Ports
   ```

   Unplug it and run `Cam-Ports` again to see which number disappears.
2. Select it and test:

   ```powershell
   Cam-Port COM5      # use your number
   Cam-Info
   ```

If no COM port appears:

- **The driver was replaced.** Tools for using the FT232H as an I2C/SPI/GPIO adapter (Zadig, libusb, CircuitPython "Blinka") swap out the serial driver. In Device Manager, uninstall the device with "delete the driver software" ticked, then replug so the FTDI serial driver returns.
- **Adafruit boards with an "I2C mode" switch:** leave it off. When on, it joins D1 to D2, which interferes with receiving.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `no reply` on every line | Camera unpowered, cable unplugged, RX/TX swapped, or wrong COM port |
| `Access to the port is denied` | Another program or PowerShell window has the port open |
| `unexpected packet` or `checksum mismatch` | Wrong baud rate, missing ground, or something else is talking on the port |
| Reads work, picture doesn't change | The value was stored but that setting has no effect on this firmware (see palettes in [protocol](protocol.md)) |

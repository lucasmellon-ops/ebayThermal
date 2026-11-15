# Which lens and sensor do I have?

Lens focal lengths are given in millimetres. Small FPV thermal cameras of this type are sold with lenses of about 4, 6.8, 9.1, 13.5 and 18 mm, and sensors of 256 x 192, 384 x 288 or 640 x 512 pixels at a 12 µm pixel pitch.

The camera's UART does not report the lens or the sensor size, so they have to be worked out from the outside.

## Step 1: read the lens

Look for a marking on the lens ring such as `9.1mm` or `F1.0`. If there is one, skip to step 3.

## Step 2: estimate from the front glass

These lenses are all about F1.0, which means the clear opening is roughly as wide as the focal length. Measure the glass itself, not the metal ring. This is a rule of thumb, good for telling a 4 mm from a 9 mm, not a 6.8 from a 9.1.

| Clear glass diameter | Lens is roughly |
|---|---|
| about 4 mm (just over 1/8 in) | 4 mm |
| about 7 mm (about 1/4 in) | 6.8 mm |
| about 9 mm (about 3/8 in) | 9.1 mm |
| about 13 mm (about 1/2 in) | 13.5 mm |

## Step 3: measure the field of view

This works no matter what screen you view the picture on.

1. Set zoom to 1.0 (`Cam-Zoom 1.0`).
2. Point the camera square at a wall from a measured distance. 6 ft (72 in) is convenient. Measure from the lens.
3. Move a warm hand along the wall until it just appears at the left edge of the picture. Mark the spot. Repeat at the right edge.
4. Measure the width between the marks.

Then:

```
sensor width (mm) = lens focal length (mm) x (width / distance)
```

Width and distance can be in any unit as long as both are the same.

| Sensor | Width at 12 µm pitch |
|---|---|
| 256 x 192 | 3.1 mm |
| 384 x 288 | 4.6 mm |
| 640 x 512 | 7.7 mm |

### Expected width at 6 ft

| Lens | 384 x 288 sees | 640 x 512 sees |
|---|---|---|
| 4 mm | 83 in (60° wide) | 138 in (88°) |
| 6.8 mm | 49 in (37°) | 81 in (59°) |
| 9.1 mm | 36 in (28°) | 61 in (46°) |
| 13.5 mm | 25 in (19°) | 41 in (32°) |

Things that shift the result:

- **Wide lenses see more than the formula says.** A 4 mm lens bends the picture outward at the edges, so the measured width comes out larger than the table.
- **Monitors crop.** Many analog screens hide the outer few percent of the picture, which makes the measured width smaller.
- **Two rows can look alike.** A 384 sensor with a 4 mm lens and a 640 sensor with a 6.8 mm lens both see about 80 in at 6 ft. Step 1 or 2 is what separates them.

## The tested camera

| Measurement | Result |
|---|---|
| Width seen at 72 in | 92 in, about 65° |
| Lens marking | Not recorded yet |
| Front glass diameter | Not recorded yet |

What that shows:

- **It is not a Partizan T640 as listed.** That model has a fixed 9.1 mm lens and would see about 61 in.
- **It fits a 384 x 288 sensor with a 4 mm lens** (83 in predicted, more with edge distortion). Partizan sells that combination as the Pilotix T384 4 mm, and the camera names itself `TIF384`.
- **Not yet excluded:** a 640 x 512 sensor with a lens of about 6 mm. Measuring the front glass settles it.

## Why zoom photos don't work

Counting blocky pixels at 8x digital zoom was tried and failed. The camera smooths the zoomed picture, so there are no hard pixel edges to count, and a small analog monitor cannot show 640 columns of detail in the first place.

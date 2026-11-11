# The `.cone` track file

A `.cone` file holds one autocross track designed in Conestructor: where every cone goes, in order, in metres, plus
everything Conestructor needs to edit the track again (its design and the lot photo). It is plain UTF-8 JSON, so any
JSON parser reads it. The JSON Schema is [`cone-format.schema.json`](cone-format.schema.json).

## Reading the cones

```python
import json

with open("Duck pond autocross.cone", encoding="utf-8") as f:
    track = json.load(f)

for cone in track["cones"]:
    print(cone["index"], cone["type"], cone["x"], cone["y"], cone["heading"])
```

## The frame

All positions are in metres, measured from the **Origin** target on the lot:

- **x** points from Origin toward the **Direction** target;
- **y** points 90° to the left of x, seen from above;
- **heading** is in degrees, counter-clockwise from +x.

To put the cones on the lot, find Origin and Direction there (they are two marks the track designer chose, such as a
light pole and a drain) and measure from them.

## Example

```json
{
  "format": "conestructor-track",
  "version": 1,
  "name": "Duck pond autocross",
  "app": "Conestructor 0.3.0",
  "saved": "2026-11-10T14:03:00Z",
  "units": "m",
  "axes": "x toward Direction target, y to the left, heading degrees counter-clockwise from +x",
  "targets": { "origin": { "x": 0, "y": 0 }, "direction": { "x": 41.2, "y": 0 }, "distance": 41.2 },
  "cones": [
    { "index": 0, "type": "standing", "x": 1.77, "y": 7.76, "heading": 0, "element": "e1" },
    { "index": 1, "type": "standing", "x": 1.77, "y": 3.76, "heading": 0, "element": "e1" }
  ],
  "design": { "...": "Conestructor's own data" },
  "photo": { "mediaType": "image/jpeg", "width": 4032, "height": 3024, "data": "/9j/4AAQSkZJRg..." }
}
```

The fields always come in this order, and the photo is always last, so the readable part is at the top of the file.

## Fields

| Field | Meaning |
|---|---|
| `format` | Always `"conestructor-track"`. |
| `version` | Whole number, `1` for this structure. It changes only when the structure changes. |
| `name` | The track's name (the file name when it was saved). |
| `app` | The app and version that saved it. |
| `saved` | When it was saved, ISO 8601 UTC. |
| `units`, `axes` | Fixed: metres, and the frame in words. |
| `targets` | `origin` (always `{ "x": 0, "y": 0 }`), `direction` (always on +x) and the `distance` between them in metres. `origin` is `null` until Origin is placed; `direction` and `distance` are `null` until Origin, Direction and the scale are all set. |
| `cones` | Every cone in driving order. `index` counts from 0; `type` is `standing` or `leaning`; `x`, `y` in metres (to the millimetre); `heading` is where a leaning cone points (0 for standing cones); `element` is the id of the track element that made it (`null` for a cone added by hand). Empty when the track cannot be processed yet. |
| `design` | Conestructor's own editable track (element settings, joins, the ruler, positions on the photo). It may change between app versions; other apps should read `cones` instead. |
| `photo` | The lot photo: `mediaType` (`image/png` or `image/jpeg`), `width` and `height` in pixels, and `data`, the original file's bytes in base64. `null` when the track has no photo. |

## Rules for readers

- Ignore fields you do not know. New optional fields do not change `version`; only a change of structure does.
- `cones` is always the final list, including any cones someone changed by hand in Conestructor. Such a cone may carry
  `"edited": true`.
- Positions are rounded to the millimetre and headings to a hundredth of a degree.

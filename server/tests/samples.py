"""Upload samples shared by the route tests and the smoke test's tests."""
import json

# Starts like a JPEG (FF D8 FF); the server checks no more than that and the size.
PICTURE = b"\xff\xd8\xff\xe0" + b"sample-thumbnail" * 8 + b"\xff\xd9"


def coneFile(name="Duck pond", cones=3):
    """A small .cone the server accepts: `cones` standing cones in a row, no photo."""
    return json.dumps({
        "format": "conestructor-track", "version": 1, "name": name, "app": "Conestructor 0.6.0",
        "saved": "2026-11-12T14:02:00Z", "units": "m", "axes": "x toward Direction target",
        "targets": {"origin": {"x": 0, "y": 0}, "direction": {"x": 40, "y": 0}, "distance": 40},
        "cones": [{"index": i, "type": "standing", "x": i * 2.0, "y": 0, "heading": 0, "element": "e1"}
                  for i in range(cones)],
        "design": {}, "photo": None}, ensure_ascii=False, indent=2).encode("utf-8")

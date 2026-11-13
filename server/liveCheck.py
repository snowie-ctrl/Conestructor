"""
The rollout's live check (server/README.md, "Rollout" step 7): every route the app calls, against the real server,
from this PC. Never deployed. It reads the team code from CONE_CHECK_CODE and checks each address the code carries (the
LAN first, then the public one). The sample track it uploads on each is deleted at the end through the LAN-only admin
API, with the admin token from CONE_ADMIN_TOKEN (and the LAN base from CONE_ADMIN_URL when the code has none). Neither
the code, the key nor the token is ever printed. Prints PASS or FAIL per step and stops at the first failure.
Standard library and coneRules only.

    set CONE_CHECK_CODE=<the team code>
    set CONE_ADMIN_TOKEN=<the admin token>
    py -3 server\\liveCheck.py
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime

import coneRules as rules

AGENT = "ConestructorLiveCheck/1.0"
PICTURE = b"\xff\xd8\xff\xe0" + b"live-check" * 10 + b"\xff\xd9"


class CheckFailed(Exception):
    pass


def check(condition, message):
    if not condition:
        raise CheckFailed(message)


def multipart(parts):
    """A multipart/form-data body from (field, filename, contentType, bytes) parts: (body, Content-Type)."""
    boundary = "----conestructor-" + uuid.uuid4().hex
    chunks = []
    for field, filename, kind, data in parts:
        chunks.append((f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field}\"; filename=\"{filename}\"\r\n"
                       f"Content-Type: {kind}\r\n\r\n").encode("utf-8") + data + b"\r\n")
    return b"".join(chunks) + f"--{boundary}--\r\n".encode("utf-8"), f"multipart/form-data; boundary={boundary}"


def fetch(url, method="GET", headers=None, data=None):
    """(status, body bytes); CheckFailed when nothing answers."""
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("User-Agent", AGENT)
    for name, value in (headers or {}).items():
        request.add_header(name, value)
    try:
        with urllib.request.urlopen(request, timeout=60) as answer:
            return answer.status, answer.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except (urllib.error.URLError, OSError) as e:
        raise CheckFailed(f"{method} {url.split('/api/')[-1]} reached nothing: {getattr(e, 'reason', e)}")


def sample(label):
    return json.dumps({"format": "conestructor-track", "version": 1, "name": f"Live check ({label})",
                       "cones": [{"index": 0, "type": "standing", "x": 0, "y": 0, "heading": 0, "element": None}],
                       "photo": None}).encode("utf-8")


def baseSteps(label, base, code, uploaded):
    key = {"X-Team-Key": code["key"]}
    api = base + "/api/cone"

    def ping():
        status, data = fetch(api + "/ping")
        check(status == 200 and json.loads(data) == {"status": "ok"}, f"ping gave {status}")
        return "ok"

    def team():
        status, data = fetch(api + "/team", headers=key)
        check(status == 200 and json.loads(data)["name"] == code["team"], f"team gave {status}")
        return code["team"]

    def upload():
        body, kind = multipart([("file", "track.cone", "application/json", sample(label)),
                                ("thumbnail", "thumbnail.jpg", "image/jpeg", PICTURE)])
        status, data = fetch(api + "/tracks", "POST", dict(key, **{"Content-Type": kind}), body)
        check(status == 201, f"upload gave {status}: {data[:200]!r}")
        uploaded.append(json.loads(data)["id"])
        return f"track {uploaded[-1]}"

    def listed():
        status, data = fetch(api + "/tracks", headers=key)
        check(status == 200 and any(t["id"] == uploaded[-1] for t in json.loads(data)["tracks"]), "not listed")
        return "listed"

    def files():
        status, data = fetch(f"{api}/tracks/{uploaded[-1]}/file", headers=key)
        check(status == 200 and data == sample(label), f"file gave {status}, changed or not")
        status, data = fetch(f"{api}/tracks/{uploaded[-1]}/thumbnail", headers=key)
        check(status == 200 and data == PICTURE, f"thumbnail gave {status}, changed or not")
        return "file and thumbnail byte for byte"

    def wrongKey():
        status, _ = fetch(api + "/team", headers={"X-Team-Key": "not-a-key"})
        check(status == 401, f"a wrong key gave {status}")
        return "401"

    return [(f"{label} ping", ping), (f"{label} team", team), (f"{label} upload", upload), (f"{label} list", listed),
            (f"{label} files", files), (f"{label} wrong key", wrongKey)]


def outsideSteps(base):
    def adminHidden():
        status, _ = fetch(base + "/api/cone-admin/teams")
        check(status == 404, f"/api/cone-admin/ gave {status} from outside")
        status, _ = fetch(base + "/")
        check(status == 404, f"/ gave {status} from outside")
        return "/api/cone-admin/ and / answer 404"
    return [("public admin hidden", adminHidden)]


def main(argv=None, environ=os.environ):
    try:
        code = rules.readTeamCode(environ.get("CONE_CHECK_CODE", ""))
    except ValueError:
        print("liveCheck: set CONE_CHECK_CODE to the team code (and CONE_ADMIN_TOKEN to the admin token)", file=sys.stderr)
        return 2
    token = environ.get("CONE_ADMIN_TOKEN")
    adminBase = (code["lan"] or environ.get("CONE_ADMIN_URL") or "").rstrip("/")
    if not token or not adminBase:
        print("liveCheck: set CONE_ADMIN_TOKEN (and CONE_ADMIN_URL when the code has no LAN address)", file=sys.stderr)
        return 2
    uploaded = []
    plan = []
    if code["lan"]:
        plan += baseSteps("LAN", code["lan"].rstrip("/"), code, uploaded)
    if code["public"]:
        plan += baseSteps("public", code["public"].rstrip("/"), code, uploaded) + outsideSteps(code["public"].rstrip("/"))
    failed = 0
    for name, step in plan:
        try:
            print(f"PASS  {name}: {step()}")
        except CheckFailed as e:
            print(f"FAIL  {name}: {e}")
            failed = 1
            break
    for trackId in uploaded:
        try:
            status, _ = fetch(f"{adminBase}/api/cone-admin/tracks/{trackId}", "DELETE", {"X-Admin-Token": token})
            print(f"{'PASS' if status == 200 else 'FAIL'}  cleanup: track {trackId} deleted ({status})")
            failed = failed or int(status != 200)
        except CheckFailed as e:
            print(f"FAIL  cleanup: track {trackId}: {e}")
            failed = 1
    print(f"{datetime.now():%H:%M} {'all passed' if not failed else 'stopped at a failure'}")
    return failed


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="backslashreplace")
    sys.exit(main())

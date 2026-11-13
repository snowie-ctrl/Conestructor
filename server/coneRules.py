"""
Conestructor's team server: the checks, the keys and the team codes, with no Flask and no database, so the routes stay
thin. Shared by coneRoutes.py (the team API), coneAdminRoutes.py (the LAN-only admin API), the smoke test and the live
check. Repo: Code-Development/Conestructor server/.
"""
import base64
import binascii
import hashlib
import json
import secrets
from datetime import datetime, timezone
from pathlib import Path

# Where the teams' files live: <TEAMS_ROOT>/<teamId>/<trackId>.cone and .jpg. Paths come from ids only, never from a
# request or the database.
TEAMS_ROOT = Path("/pool/appFiles/conestructor/teams")

MAX_FILE = 40 * 1024 * 1024               # one .cone, its photo included
MAX_THUMBNAIL = 200 * 1024
MAX_REQUEST = MAX_FILE + 1024 * 1024      # a whole upload: the file, the thumbnail and the form's own lines
MAX_TRACK_NAME = 200
MAX_TEAM_NAME = 100
CODE_PREFIX = "CONE1."
FORMAT = "conestructor-track"
JPEG_START = b"\xff\xd8\xff"


class Refused(Exception):
    """An upload or a name the server will not take; the message is said to the person."""


def readTrack(data):
    """{"name", "cones"} read from an uploaded .cone's bytes. Refused when it is not a track file this server takes."""
    try:
        doc = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise Refused("not a track file")
    if not isinstance(doc, dict) or doc.get("format") != FORMAT:
        raise Refused("not a track file")
    version = doc.get("version")
    if isinstance(version, bool) or version != 1:
        raise Refused("this track file's version is not supported")
    name = doc.get("name")
    if not isinstance(name, str) or not name.strip():
        raise Refused("the track has no name")
    if not isinstance(doc.get("cones"), list):
        raise Refused("the track has no cone list")
    return {"name": name.strip()[:MAX_TRACK_NAME], "cones": len(doc["cones"])}


def checkThumbnail(data):
    """Refused unless `data` starts like a JPEG and is at most MAX_THUMBNAIL bytes."""
    if not data.startswith(JPEG_START):
        raise Refused("the thumbnail is not a JPEG")
    if len(data) > MAX_THUMBNAIL:
        raise Refused("the thumbnail is too large")


def teamName(value):
    """A team's name without surrounding spaces; Refused when blank or too long."""
    if not isinstance(value, str) or not value.strip():
        raise Refused("a team needs a name")
    name = value.strip()
    if len(name) > MAX_TEAM_NAME:
        raise Refused(f"a team name is at most {MAX_TEAM_NAME} characters")
    return name


def newKey():
    """A team key: 32 random bytes, base64url (43 characters)."""
    return secrets.token_urlsafe(32)


def keyHash(key):
    """What the teams table keeps of a key: its SHA-256, in hex."""
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def teamCode(team, key, lanBase, publicBase):
    """The one line a teammate pastes into Preferences › Team: CONE1. and base64url (no padding) of the team's name,
    the addresses it may use (LAN first) and its key. ValueError when there is no address at all."""
    if not lanBase and not publicBase:
        raise ValueError("a team code needs the LAN address or the public address")
    fields = {"v": 1, "team": team}
    if lanBase:
        fields["lan"] = lanBase.rstrip("/")
    if publicBase:
        fields["public"] = publicBase.rstrip("/")
    fields["key"] = key
    text = json.dumps(fields, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return CODE_PREFIX + base64.urlsafe_b64encode(text).decode("ascii").rstrip("=")


def readTeamCode(code):
    """{"team", "lan", "public", "key"} from a team code (a missing address is None); ValueError when it is not one."""
    code = (code or "").strip()
    if not code.startswith(CODE_PREFIX):
        raise ValueError("not a team code")
    body = code[len(CODE_PREFIX):]
    try:
        raw = base64.b64decode(body + "=" * (-len(body) % 4), altchars=b"-_", validate=True)
        fields = json.loads(raw.decode("utf-8"))
    except (binascii.Error, ValueError, UnicodeDecodeError):
        raise ValueError("not a team code")
    if not isinstance(fields, dict) or fields.get("v") != 1 or isinstance(fields.get("v"), bool):
        raise ValueError("not a team code")
    key, lan, public = fields.get("key"), fields.get("lan"), fields.get("public")
    lan = lan if isinstance(lan, str) and lan else None
    public = public if isinstance(public, str) and public else None
    if not isinstance(key, str) or not key or (lan is None and public is None):
        raise ValueError("not a team code")
    team = fields.get("team")
    return {"team": team if isinstance(team, str) else "", "lan": lan, "public": public, "key": key}


def utcNow():
    """Now in UTC to the second, as the tables keep times (DATETIME, no zone)."""
    return datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)


def isoUtc(moment):
    """A table's UTC time as ISO 8601: 2026-11-12T14:02:00Z."""
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def trackFiles(teamId, trackId):
    """The track's two files: (<TEAMS_ROOT>/<teamId>/<trackId>.cone, .../<trackId>.jpg)."""
    folder = TEAMS_ROOT / str(int(teamId))
    return folder / f"{int(trackId)}.cone", folder / f"{int(trackId)}.jpg"

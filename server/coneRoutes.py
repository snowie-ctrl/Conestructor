"""
Conestructor's team API on the server, at /api/cone (Caduceus registers coneBP there). The only prefix nginx passes
from the public subdomain; the LAN reaches it on the API's own port. Every request but ping needs X-Team-Key, and a
team sees only its own tracks: another team's track answers 404, as one that does not exist. Checks live in coneRules,
so the routes stay thin. Repo: Code-Development/Conestructor server/ (README.md there says what goes where).
"""
import uuid
from contextlib import contextmanager

from flask import Blueprint, g, jsonify, request, send_file

from . import DBUtils, coneRules as rules

coneBP = Blueprint("cone", __name__)

DB_NAME = "cone"


def error(message, code=400):
    return jsonify({"status": "error", "message": message}), code


@contextmanager
def database():
    conn = DBUtils.initConnection(DB_NAME)
    try:
        yield conn
    finally:
        conn.close()


@coneBP.errorhandler(413)
def tooLarge(_):
    return error("too large", 413)


@coneBP.before_request
def requireTeamKey():
    """Finds the team whose key this is (by the key's hash) and keeps it in g.team; 401 when none."""
    if request.endpoint == "cone.ping":
        return None
    key = request.headers.get("X-Team-Key", "")
    if not key:
        return error("unauthorized", 401)
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT id, name FROM teams WHERE keyHash = %s", (rules.keyHash(key),))
            team = cur.fetchone()
            cur.close()
    except Exception as e:
        print(f"[cone] looking up a team key failed: {e}")
        return error("database error", 500)
    if team is None:
        return error("unauthorized", 401)
    g.team = team
    return None


@coneBP.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"})


@coneBP.route("/team", methods=["GET"])
def team():
    return jsonify({"status": "ok", "name": g.team["name"]})


@coneBP.route("/tracks", methods=["GET"])
def tracks():
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT id, name, cones, uploaded, bytes FROM tracks WHERE teamId = %s "
                        "ORDER BY uploaded DESC, id DESC", (g.team["id"],))
            rows = cur.fetchall()
            cur.close()
    except Exception as e:
        print(f"[cone] listing tracks failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "tracks": [
        {"id": r["id"], "name": r["name"], "cones": r["cones"], "uploaded": rules.isoUtc(r["uploaded"]),
         "bytes": r["bytes"]} for r in rows]})


def ownTrack(trackId):
    """Whether track `trackId` is this team's."""
    with database() as conn:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT id FROM tracks WHERE id = %s AND teamId = %s", (trackId, g.team["id"]))
        row = cur.fetchone()
        cur.close()
    return row is not None


def sendTrackFile(trackId, which, mimetype):
    """One of the track's two files (0: the .cone, 1: the thumbnail), never cached by anything in between."""
    try:
        if not ownTrack(trackId):
            return error("no such track", 404)
    except Exception as e:
        print(f"[cone] finding track {trackId} failed: {e}")
        return error("database error", 500)
    path = rules.trackFiles(g.team["id"], trackId)[which]
    if not path.is_file():
        return error("the track's file is missing", 404)
    answer = send_file(path, mimetype=mimetype, max_age=0)
    answer.headers["Cache-Control"] = "private, no-cache"
    return answer


@coneBP.route("/tracks/<int:trackId>/file", methods=["GET"])
def trackFile(trackId):
    return sendTrackFile(trackId, 0, "application/json")


@coneBP.route("/tracks/<int:trackId>/thumbnail", methods=["GET"])
def thumbnail(trackId):
    return sendTrackFile(trackId, 1, "image/jpeg")


@coneBP.route("/tracks", methods=["POST"])
def upload():
    """A multipart form: `file` (the .cone) and `thumbnail` (a JPEG). The name and cone count are read from the file."""
    if request.content_length is not None and request.content_length > rules.MAX_REQUEST:
        return error("too large", 413)
    request.max_content_length = rules.MAX_REQUEST     # Flask 3.1: also caps a body sent without a length
    file = request.files.get("file")
    picture = request.files.get("thumbnail")
    if file is None or picture is None:
        return error("the upload needs a file and a thumbnail")
    data = file.read(rules.MAX_FILE + 1)
    if len(data) > rules.MAX_FILE:
        return error("too large", 413)
    thumbnailData = picture.read(rules.MAX_THUMBNAIL + 1)
    try:
        info = rules.readTrack(data)
        rules.checkThumbnail(thumbnailData)
    except rules.Refused as e:
        return error(str(e))
    return store(info, data, thumbnailData)


def store(info, data, thumbnailData):
    """Writes both files under temporary names, inserts the row, renames the files to the row's id and commits. Any
    failure rolls the row back and removes every file it wrote, so a failed upload leaves nothing behind."""
    teamId = g.team["id"]
    folder = rules.TEAMS_ROOT / str(int(teamId))
    temporary = uuid.uuid4().hex
    written = [folder / f".upload-{temporary}.cone", folder / f".upload-{temporary}.jpg"]
    placed = []
    conn = None
    try:
        folder.mkdir(parents=True, exist_ok=True)
        written[0].write_bytes(data)
        written[1].write_bytes(thumbnailData)
        conn = DBUtils.initConnection(DB_NAME)
        cur = conn.cursor()
        cur.execute("INSERT INTO tracks (teamId, name, cones, uploaded, bytes) VALUES (%s, %s, %s, %s, %s)",
                    (teamId, info["name"], info["cones"], rules.utcNow(), len(data)))
        trackId = cur.lastrowid
        cur.close()
        for temporaryPath, final in zip(written, rules.trackFiles(teamId, trackId)):
            temporaryPath.replace(final)
            placed.append(final)
        conn.commit()
    except Exception as e:
        print(f"[cone] storing an upload failed: {e}")
        if conn is not None:
            try:
                conn.rollback()
            except Exception:
                pass
        for path in written + placed:
            try:
                path.unlink(missing_ok=True)
            except OSError:
                pass
        return error("could not store the track", 500)
    finally:
        if conn is not None:
            conn.close()
    return jsonify({"status": "ok", "id": trackId}), 201

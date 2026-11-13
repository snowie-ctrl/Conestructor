"""
Conestructor's admin API on the server, at /api/cone-admin (Caduceus registers coneAdminBP there). LAN only: nginx never
passes this prefix from the public subdomain. Every request needs X-Admin-Token matching coneAdminConfig.json beside
this file (chmod 600, never committed), which also holds the two addresses team codes carry, so they live only on the
server and inside codes. server/coneAdmin.py on the owner's PC calls these routes.
"""
import hmac
import json
from contextlib import contextmanager
from pathlib import Path

from flask import Blueprint, jsonify, request

from . import DBUtils, coneRules as rules

coneAdminBP = Blueprint("coneAdmin", __name__)

CONFIG_FILE = Path(__file__).resolve().parent / "coneAdminConfig.json"
DB_NAME = "cone"
NO_ADDRESS = "coneAdminConfig.json has neither lanBase nor publicBase"
_configCache = {"mtime": None, "config": {}}


def config():
    """coneAdminConfig.json as a dict ({} when it is missing or unreadable), read again whenever the file changes."""
    try:
        mtime = CONFIG_FILE.stat().st_mtime
    except (OSError, AttributeError, TypeError):
        return {}
    if _configCache["mtime"] != mtime:
        try:
            loaded = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            _configCache["config"] = loaded if isinstance(loaded, dict) else {}
        except (OSError, ValueError):
            _configCache["config"] = {}
        _configCache["mtime"] = mtime
    return _configCache["config"]


def error(message, code=400):
    return jsonify({"status": "error", "message": message}), code


@contextmanager
def database():
    conn = DBUtils.initConnection(DB_NAME)
    try:
        yield conn
    finally:
        conn.close()


@coneAdminBP.before_request
def requireAdminToken():
    expected = config().get("token")
    given = request.headers.get("X-Admin-Token", "")
    if not isinstance(expected, str) or not expected or not hmac.compare_digest(given.encode(), expected.encode()):
        return error("unauthorized", 401)
    return None


def body():
    """The JSON body as a dict, or {} (never Flask 3's automatic 415)."""
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


def codeFor(name, key):
    settings = config()
    return rules.teamCode(name, key, settings.get("lanBase"), settings.get("publicBase"))


@coneAdminBP.route("/teams", methods=["POST"])
def makeTeam():
    try:
        name = rules.teamName(body().get("name"))
    except rules.Refused as e:
        return error(str(e))
    key = rules.newKey()
    try:
        code = codeFor(name, key)
    except ValueError:
        return error(NO_ADDRESS, 500)
    try:
        with database() as conn:
            cur = conn.cursor()
            cur.execute("INSERT INTO teams (name, keyHash, created) VALUES (%s, %s, %s)",
                        (name, rules.keyHash(key), rules.utcNow()))
            teamId = cur.lastrowid
            cur.close()
            conn.commit()
    except Exception as e:
        print(f"[cone-admin] making a team failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "id": teamId, "name": name, "key": key, "code": code}), 201


@coneAdminBP.route("/teams/<int:teamId>/key", methods=["POST"])
def replaceKey(teamId):
    key = rules.newKey()
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT name FROM teams WHERE id = %s", (teamId,))
            row = cur.fetchone()
            if row is None:
                cur.close()
                return error("no such team", 404)
            code = codeFor(row["name"], key)
            cur.execute("UPDATE teams SET keyHash = %s WHERE id = %s", (rules.keyHash(key), teamId))
            cur.close()
            conn.commit()
    except ValueError:
        return error(NO_ADDRESS, 500)
    except Exception as e:
        print(f"[cone-admin] replacing team {teamId}'s key failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "id": teamId, "name": row["name"], "key": key, "code": code})


@coneAdminBP.route("/teams", methods=["GET"])
def teams():
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT t.id, t.name, t.created, COUNT(k.id) AS tracks FROM teams t "
                        "LEFT JOIN tracks k ON k.teamId = t.id GROUP BY t.id, t.name, t.created ORDER BY t.id")
            rows = cur.fetchall()
            cur.close()
    except Exception as e:
        print(f"[cone-admin] listing teams failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "teams": [
        {"id": r["id"], "name": r["name"], "tracks": int(r["tracks"]), "created": rules.isoUtc(r["created"])}
        for r in rows]})


@coneAdminBP.route("/tracks", methods=["GET"])
def tracks():
    team = request.args.get("team")
    if team is not None and not team.isdigit():
        return error("team must be a number")
    sql = ("SELECT k.id, k.teamId, t.name AS team, k.name, k.cones, k.uploaded, k.bytes FROM tracks k "
           "JOIN teams t ON t.id = k.teamId")
    params = ()
    if team is not None:
        sql += " WHERE k.teamId = %s"
        params = (int(team),)
    sql += " ORDER BY k.uploaded DESC, k.id DESC"
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute(sql, params)
            rows = cur.fetchall()
            cur.close()
    except Exception as e:
        print(f"[cone-admin] listing tracks failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "tracks": [
        {"id": r["id"], "teamId": r["teamId"], "team": r["team"], "name": r["name"], "cones": r["cones"],
         "uploaded": rules.isoUtc(r["uploaded"]), "bytes": r["bytes"]} for r in rows]})


@coneAdminBP.route("/tracks/<int:trackId>", methods=["DELETE"])
def deleteTrack(trackId):
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT teamId FROM tracks WHERE id = %s", (trackId,))
            row = cur.fetchone()
            if row is None:
                cur.close()
                return error("no such track", 404)
            cur.execute("DELETE FROM tracks WHERE id = %s", (trackId,))
            cur.close()
            conn.commit()
    except Exception as e:
        print(f"[cone-admin] deleting track {trackId} failed: {e}")
        return error("database error", 500)
    for path in rules.trackFiles(row["teamId"], trackId):
        try:
            path.unlink(missing_ok=True)
        except OSError as e:
            print(f"[cone-admin] track {trackId}'s file {path.name} stayed: {e}")
    return jsonify({"status": "ok", "id": trackId})

"""
The real-MySQL smoke test, run on the server against a scratch database before cut-over (the route tests only ever meet
a fake connection):

    cd /database/API && /database/venv/bin/python -m util.coneSmoke --database cone_smoke

Every connection is switched to the scratch database, and track files go to a temporary folder, so nothing touches
coneDB or /pool. Prints PASS or FAIL per step and stops at the first failure. The scratch database must be empty, with
schema.sql loaded (server/README.md, "The smoke test").
"""
import argparse
import io
import json
import re
import sys
import tempfile
from pathlib import Path

import flask

from . import DBUtils, coneAdminRoutes as admin, coneRoutes as team, coneRules as rules

A, T = "/api/cone-admin", "/api/cone"
TOKEN = "smoke-admin-token"
PICTURE = b"\xff\xd8\xff\xe0" + b"smoke" * 20 + b"\xff\xd9"


class SmokeFailed(Exception):
    pass


def scratchConnections(database, connect):
    """Wraps connect so every connection switches to `database`. Only a name containing "smoke" is accepted, so coneDB
    and every other real database are refused."""
    if not re.fullmatch(r"[A-Za-z0-9_]+", database or "") or "smoke" not in database.lower():
        raise ValueError("the smoke test only runs on a scratch database whose name contains smoke, never coneDB")

    def switched(name):
        try:
            conn = connect(name)
            cur = conn.cursor()
            cur.execute(f"USE `{database}`")
            cur.close()
        except Exception as e:
            print(f"smoke: could not open the scratch database: {type(e).__name__}: {e}", file=sys.stderr)
            raise
        return conn
    return switched


def check(condition, message):
    if not condition:
        raise SmokeFailed(message)


def sampleTrack():
    return json.dumps({"format": "conestructor-track", "version": 1, "name": "Smoke track", "cones": [
        {"index": 0, "type": "standing", "x": 1, "y": 2, "heading": 0, "element": "e1"},
        {"index": 1, "type": "leaning", "x": 3, "y": 4, "heading": 90, "element": "e1"}], "photo": None}).encode("utf-8")


def call(client, method, path, key=None, expect=200, **kwargs):
    """The answer (a response); SmokeFailed when its status is not `expect`."""
    headers = {"X-Team-Key": key} if key else {}
    answer = client.open(path, method=method, headers=headers, **kwargs)
    if answer.status_code != expect:
        text = answer.get_data()[:200].decode("utf-8", "replace")
        raise SmokeFailed(f"{method} {path} gave {answer.status_code}: {text}")
    return answer


def steps(teamsRoot):
    def empty(client, state):
        check(call(client, "GET", f"{A}/teams").get_json()["teams"] == [],
              "the scratch database is not empty: drop and recreate it")
        return "no teams yet"

    def teams(client, state):
        for label in ("A", "B"):
            made = call(client, "POST", f"{A}/teams", json={"name": f"Smoke {label}"}, expect=201).get_json()
            check(rules.readTeamCode(made["code"])["key"] == made["key"], "the code does not carry the key")
            state[label] = made
        return f"teams {state['A']['id']} and {state['B']['id']}, codes read back"

    def upload(client, state):
        form = {"file": (io.BytesIO(sampleTrack()), "track.cone"), "thumbnail": (io.BytesIO(PICTURE), "thumbnail.jpg")}
        made = call(client, "POST", f"{T}/tracks", key=state["A"]["key"], expect=201, data=form,
                    content_type="multipart/form-data").get_json()
        state["track"] = made["id"]
        return f"track {made['id']}"

    def listed(client, state):
        tracks = call(client, "GET", f"{T}/tracks", key=state["A"]["key"]).get_json()["tracks"]
        check([(t["id"], t["name"], t["cones"], t["bytes"]) for t in tracks]
              == [(state["track"], "Smoke track", 2, len(sampleTrack()))], f"listed {tracks}")
        return "listed with its name, cones and size"

    def files(client, state):
        key = state["A"]["key"]
        check(call(client, "GET", f"{T}/tracks/{state['track']}/thumbnail", key=key).data == PICTURE,
              "the thumbnail came back changed")
        check(call(client, "GET", f"{T}/tracks/{state['track']}/file", key=key).data == sampleTrack(),
              "the file came back changed")
        return "thumbnail and file byte for byte"

    def otherTeam(client, state):
        key = state["B"]["key"]
        check(call(client, "GET", f"{T}/tracks", key=key).get_json()["tracks"] == [], "team B sees team A's track")
        call(client, "GET", f"{T}/tracks/{state['track']}/file", key=key, expect=404)
        return "team B sees nothing of team A's"

    def newKey(client, state):
        old = state["A"]["key"]
        made = call(client, "POST", f"{A}/teams/{state['A']['id']}/key").get_json()
        call(client, "GET", f"{T}/team", key=old, expect=401)
        check(call(client, "GET", f"{T}/team", key=made["key"]).get_json()["name"] == "Smoke A", "the new key's team")
        call(client, "GET", f"{T}/tracks", key="not-a-key", expect=401)
        state["A"]["key"] = made["key"]
        return "the old key refused, the new one works"

    def delete(client, state):
        call(client, "DELETE", f"{A}/tracks/{state['track']}")
        check(not any(p.exists() for p in rules.trackFiles(state["A"]["id"], state["track"])), "files left behind")
        check(call(client, "GET", f"{T}/tracks", key=state["A"]["key"]).get_json()["tracks"] == [], "still listed")
        return "row and files gone"

    return [("empty", empty), ("teams", teams), ("upload", upload), ("list", listed), ("files", files),
            ("other team", otherTeam), ("new key", newKey), ("delete", delete)]


def runSteps(client, teamsRoot):
    """Runs every step on `client` (an admin and team test client); 0 when all pass, 1 at the first failure."""
    state = {}
    for name, step in steps(teamsRoot):
        try:
            print(f"PASS  {name}: {step(client, state)}")
        except SmokeFailed as e:
            print(f"FAIL  {name}: {e}")
            return 1
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Conestructor's team server smoke test (scratch database only).")
    parser.add_argument("--database", required=True)
    args = parser.parse_args(argv)
    try:
        connect = scratchConnections(args.database, DBUtils.initConnection)
    except ValueError as e:
        print(f"smoke: {e}", file=sys.stderr)
        return 2
    DBUtils.initConnection = connect
    with tempfile.TemporaryDirectory(prefix="cone-smoke-") as folder:
        rules.TEAMS_ROOT = Path(folder) / "teams"
        config = Path(folder) / "coneAdminConfig.json"
        config.write_text(json.dumps({"token": TOKEN, "lanBase": "http://lan.example:5000",
                                      "publicBase": "https://public.example"}), encoding="utf-8")
        admin.CONFIG_FILE = config
        admin._configCache.update({"mtime": None, "config": {}})
        app = flask.Flask("cone-smoke")
        app.register_blueprint(team.coneBP, url_prefix=T)
        app.register_blueprint(admin.coneAdminBP, url_prefix=A)
        client = app.test_client()
        client.environ_base["HTTP_X_ADMIN_TOKEN"] = TOKEN
        return runSteps(client, rules.TEAMS_ROOT)


if __name__ == "__main__":
    sys.exit(main())

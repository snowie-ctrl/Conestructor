import io
import json
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from conftest import loadModule

TOKEN = "admin-token-for-tests"


class StandIn:
    """A tiny HTTP server answering canned replies by (method, path) and recording each request."""

    def __init__(self, replies):
        self.replies = replies
        self.requests = []
        outer = self

        class Handler(BaseHTTPRequestHandler):
            def answer(self, method):
                length = int(self.headers.get("Content-Length") or 0)
                data = self.rfile.read(length) if length else b""
                outer.requests.append({"method": method, "path": self.path,
                                       "token": self.headers.get("X-Admin-Token"),
                                       "body": json.loads(data) if data else None})
                status, reply = outer.replies.get((method, self.path), (404, {"status": "error", "message": "no such route"}))
                text = json.dumps(reply).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(text)))
                self.end_headers()
                self.wfile.write(text)

            def do_GET(self):
                self.answer("GET")

            def do_POST(self):
                self.answer("POST")

            def do_DELETE(self):
                self.answer("DELETE")

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


@pytest.fixture
def standIn():
    made = []

    def make(replies):
        server = StandIn(replies)
        made.append(server)
        return server
    yield make
    for server in made:
        server.close()


@pytest.fixture
def admin():
    return loadModule("coneAdmin")


def run(admin, server, *argv, ask=None):
    out, err = io.StringIO(), io.StringIO()
    environ = {"CONE_ADMIN_URL": server.base if server else "http://127.0.0.1:9", "CONE_ADMIN_TOKEN": TOKEN}

    def refuse(prompt):
        raise AssertionError("asked: " + prompt)
    code = admin.main(list(argv), out=out, err=err, ask=ask or refuse, environ=environ)
    return code, out.getvalue(), err.getvalue()


def test_makeTeamPrintsTheCodeOnce(admin, standIn):
    server = standIn({("POST", "/api/cone-admin/teams"): (201, {"status": "ok", "id": 1, "name": "Our team",
                                                               "key": "k", "code": "CONE1.abc"})})
    code, out, err = run(admin, server, "make-team", "Our team")
    assert code == 0 and err == ""
    assert out.splitlines() == ["Team 1 (Our team) made. Its team code, shown only now; paste it into "
                                "Preferences > Team:", "CONE1.abc"]
    assert server.requests == [{"method": "POST", "path": "/api/cone-admin/teams", "token": TOKEN,
                                "body": {"name": "Our team"}}]
    assert TOKEN not in out


def test_newKey(admin, standIn):
    server = standIn({("POST", "/api/cone-admin/teams/1/key"): (200, {"status": "ok", "id": 1, "name": "Our team",
                                                                     "key": "k2", "code": "CONE1.def"})})
    code, out, _ = run(admin, server, "new-key", "1")
    assert code == 0
    assert out.splitlines() == ["New key for team 1 (Our team): codes made before no longer work. Its team code:",
                                "CONE1.def"]


def test_theTeams(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/teams"): (200, {"status": "ok", "teams": [
        {"id": 1, "name": "Our team", "tracks": 4, "created": "2026-11-12T09:30:00Z"}]})})
    code, out, _ = run(admin, server, "teams")
    assert code == 0
    assert out.strip() == f"1  Our team  (4 tracks, made {admin.localTime('2026-11-12T09:30:00Z')})"
    empty = standIn({("GET", "/api/cone-admin/teams"): (200, {"status": "ok", "teams": []})})
    assert run(admin, empty, "teams")[1].strip() == "No teams yet."


TRACK = {"id": 12, "teamId": 1, "team": "Our team", "name": "Duck pond", "cones": 132,
         "uploaded": "2026-11-12T14:02:00Z", "bytes": 1468006}


def test_theTracks(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/tracks?team=1"): (200, {"status": "ok", "tracks": [TRACK]})})
    code, out, _ = run(admin, server, "tracks", "--team", "1")
    assert code == 0
    assert out.strip() == f"12  Duck pond  (Our team, 132 cones, {admin.localTime(TRACK['uploaded'])}, 1.4 MB)"


def test_deleteAsksFirst(admin, standIn):
    replies = {("GET", "/api/cone-admin/tracks"): (200, {"status": "ok", "tracks": [TRACK]}),
               ("DELETE", "/api/cone-admin/tracks/12"): (200, {"status": "ok", "id": 12})}
    server = standIn(replies)
    code, out, _ = run(admin, server, "delete", "12", ask=lambda prompt: "n")
    assert code == 0 and out.splitlines()[-1] == "Kept."
    assert [r["method"] for r in server.requests] == ["GET"]
    code, out, _ = run(admin, server, "delete", "12", ask=lambda prompt: "y")
    assert code == 0 and out.splitlines()[-1] == "Deleted track 12."
    assert server.requests[-1]["method"] == "DELETE"
    code, out, _ = run(admin, server, "delete", "12", "--yes")      # never asks
    assert code == 0 and out.splitlines()[-1] == "Deleted track 12."


def test_deleteNoTrack(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/tracks"): (200, {"status": "ok", "tracks": [TRACK]})})
    code, _, err = run(admin, server, "delete", "99", "--yes")
    assert code == 1 and err.strip() == "coneAdmin: no track 99"


def test_aWrongToken(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/teams"): (401, {"status": "error", "message": "unauthorized"})})
    code, _, err = run(admin, server, "teams")
    assert code == 1 and err.strip() == "coneAdmin: unauthorized (check the admin token)"


def test_aServerError(admin, standIn):
    server = standIn({("POST", "/api/cone-admin/teams"): (500, {"status": "error", "message": "database error"})})
    code, _, err = run(admin, server, "make-team", "x")
    assert code == 1 and err.strip() == "coneAdmin: the server answered 500: database error"


def test_noServer(admin):
    code, _, err = run(admin, None, "teams")
    assert code == 1 and err.startswith("coneAdmin: can't reach http://127.0.0.1:9")


def test_settingsComeFromTheEnvironmentOrTheLocalFile(admin, tmp_path):
    local = tmp_path / "coneAdmin.local.json"
    with pytest.raises(admin.Failed, match="set CONE_ADMIN_URL and CONE_ADMIN_TOKEN"):
        admin.settings({}, local)
    local.write_text(json.dumps({"url": "http://lan.example:5000/", "token": "t"}))
    assert admin.settings({}, local) == ("http://lan.example:5000", "t")
    assert admin.settings({"CONE_ADMIN_URL": "http://x:1", "CONE_ADMIN_TOKEN": "u"}, local) == ("http://x:1", "u")


def test_timesAndSizes(admin):
    expected = datetime(2026, 11, 12, 14, 2, tzinfo=timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")
    assert admin.localTime("2026-11-12T14:02:00Z") == expected
    assert admin.size(1468006) == "1.4 MB" and admin.size(12000) == "12 KB" and admin.size(10) == "1 KB"

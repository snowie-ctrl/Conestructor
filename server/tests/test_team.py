import io
import pathlib
from datetime import datetime

import pytest

from conftest import KEY, TEAM
from samples import PICTURE, coneFile


def upload(client, data=None, picture=PICTURE, **extra):
    form = dict(extra)
    if data is not None:
        form["file"] = (io.BytesIO(data), "track.cone")
    if picture is not None:
        form["thumbnail"] = (io.BytesIO(picture), "thumbnail.jpg")
    return client.post("/api/cone/tracks", data=form, content_type="multipart/form-data")


def leftovers(teams):
    return sorted(p.name for p in teams.rglob("*") if p.is_file()) if teams.exists() else []


def test_pingNeedsNoKey(anonClient):
    answer = anonClient.get("/api/cone/ping")
    assert answer.status_code == 200 and answer.get_json() == {"status": "ok"}


@pytest.mark.parametrize("method, path", [("GET", "/team"), ("GET", "/tracks"), ("GET", "/tracks/1/file"),
                                          ("GET", "/tracks/1/thumbnail"), ("POST", "/tracks")])
def test_everythingElseNeedsAKey(anonClient, method, path):
    answer = anonClient.open("/api/cone" + path, method=method)
    assert answer.status_code == 401
    assert answer.get_json() == {"status": "error", "message": "unauthorized"}


def test_aWrongKeyIsRefusedAndOnlyItsHashIsLookedUp(useDb, teamClient, rules):
    conn = useDb(fetchone=[None])
    assert teamClient.get("/api/cone/team").status_code == 401
    sql, params = conn.cur.executed[0]
    assert sql == "SELECT id, name FROM teams WHERE keyHash = %s"
    assert params == (rules.keyHash(KEY),)


def test_theTeamsName(useDb, teamClient):
    useDb(fetchone=[TEAM])
    assert teamClient.get("/api/cone/team").get_json() == {"status": "ok", "name": "Our team"}


def test_theListIsTheTeamsOwnNewestFirst(useDb, teamClient):
    conn = useDb(fetchone=[TEAM], fetchall=[[
        {"id": 12, "name": "Duck pond", "cones": 132, "uploaded": datetime(2026, 11, 12, 14, 2), "bytes": 3000},
        {"id": 9, "name": "Duck pond", "cones": 120, "uploaded": datetime(2026, 11, 3, 9, 0), "bytes": 2000}]])
    answer = teamClient.get("/api/cone/tracks").get_json()
    assert answer == {"status": "ok", "tracks": [
        {"id": 12, "name": "Duck pond", "cones": 132, "uploaded": "2026-11-12T14:02:00Z", "bytes": 3000},
        {"id": 9, "name": "Duck pond", "cones": 120, "uploaded": "2026-11-03T09:00:00Z", "bytes": 2000}]}
    sql, params = conn.cur.executed[1]
    assert sql == ("SELECT id, name, cones, uploaded, bytes FROM tracks WHERE teamId = %s "
                   "ORDER BY uploaded DESC, id DESC")
    assert params == (3,)


def writeTrack(rules, teamId, trackId, data=b'{"format": "conestructor-track"}', picture=PICTURE):
    cone, jpg = rules.trackFiles(teamId, trackId)
    cone.parent.mkdir(parents=True, exist_ok=True)
    cone.write_bytes(data)
    jpg.write_bytes(picture)


def test_aTracksFilesAreSent(useDb, teamClient, rules):
    writeTrack(rules, 3, 12, coneFile())
    useDb(fetchone=[TEAM, {"id": 12}, TEAM, {"id": 12}])
    file = teamClient.get("/api/cone/tracks/12/file")
    assert file.status_code == 200 and file.mimetype == "application/json" and file.data == coneFile()
    thumbnail = teamClient.get("/api/cone/tracks/12/thumbnail")
    assert thumbnail.status_code == 200 and thumbnail.mimetype == "image/jpeg" and thumbnail.data == PICTURE
    assert "private" in thumbnail.headers["Cache-Control"]


def test_anotherTeamsTrackIsNotFound(useDb, teamClient, rules):
    writeTrack(rules, 4, 12)                              # team 4's track 12 is there
    conn = useDb(fetchone=[TEAM, None])
    answer = teamClient.get("/api/cone/tracks/12/file")
    assert answer.status_code == 404 and answer.get_json()["message"] == "no such track"
    assert conn.cur.executed[1] == ("SELECT id FROM tracks WHERE id = %s AND teamId = %s", (12, 3))


def test_aMissingFileIsNotFound(useDb, teamClient):
    useDb(fetchone=[TEAM, {"id": 12}])
    assert teamClient.get("/api/cone/tracks/12/thumbnail").status_code == 404


def test_anUploadIsStored(useDb, teamClient, rules, teams):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    answer = upload(teamClient, coneFile("Duck pond", 3))
    assert answer.status_code == 201 and answer.get_json() == {"status": "ok", "id": 12}
    cone, jpg = rules.trackFiles(3, 12)
    assert cone.read_bytes() == coneFile("Duck pond", 3) and jpg.read_bytes() == PICTURE
    assert leftovers(teams) == ["12.cone", "12.jpg"]
    sql, params = conn.cur.statements("INSERT")[0]
    assert sql == "INSERT INTO tracks (teamId, name, cones, uploaded, bytes) VALUES (%s, %s, %s, %s, %s)"
    assert params[:3] == (3, "Duck pond", 3) and params[4] == len(coneFile("Duck pond", 3))
    assert isinstance(params[3], datetime)
    assert conn.commits == 1 and conn.rollbacks == 0


def test_theNameAndCountComeFromTheFile(useDb, teamClient):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    upload(teamClient, coneFile("Duck pond", 3), name="Something else", cones="999")
    assert conn.cur.statements("INSERT")[0][1][1:3] == ("Duck pond", 3)


def test_anyNameIsStoredAsItIs(useDb, teamClient):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    name = 'Duck "pond" / wet é 🏁'
    assert upload(teamClient, coneFile(name, 1)).status_code == 201
    assert conn.cur.statements("INSERT")[0][1][1] == name


@pytest.mark.parametrize("data, picture, message", [
    (b"not json", PICTURE, "not a track file"),
    (coneFile().replace(b'"version": 1', b'"version": 2'), PICTURE, "this track file's version is not supported"),
    (coneFile(), b"\x89PNG\r\n\x1a\n", "the thumbnail is not a JPEG"),
    (None, PICTURE, "the upload needs a file and a thumbnail"),
    (coneFile(), None, "the upload needs a file and a thumbnail"),
], ids=["not json", "version 2", "png thumbnail", "no file", "no thumbnail"])
def test_aBadUploadIsRefused(useDb, teamClient, teams, data, picture, message):
    conn = useDb(fetchone=[TEAM])
    answer = upload(teamClient, data, picture)
    assert answer.status_code == 400 and answer.get_json()["message"] == message
    assert conn.cur.statements("INSERT") == [] and leftovers(teams) == []


def test_aThumbnailTooLargeIsRefused(useDb, teamClient, rules, teams):
    useDb(fetchone=[TEAM])
    answer = upload(teamClient, coneFile(), PICTURE[:3] + b"\0" * rules.MAX_THUMBNAIL)
    assert answer.status_code == 400 and answer.get_json()["message"] == "the thumbnail is too large"


def test_aRequestTooLargeIsRefusedBeforeItIsRead(useDb, teamClient, rules, monkeypatch):
    monkeypatch.setattr(rules, "MAX_REQUEST", 100)
    useDb(fetchone=[TEAM])
    answer = upload(teamClient, coneFile())
    assert answer.status_code == 413 and answer.get_json() == {"status": "error", "message": "too large"}


def test_aFileTooLargeIsRefused(useDb, teamClient, rules, monkeypatch, teams):
    monkeypatch.setattr(rules, "MAX_FILE", 100)
    useDb(fetchone=[TEAM])
    answer = upload(teamClient, coneFile())
    assert answer.status_code == 413 and leftovers(teams) == []


def test_aFailedInsertLeavesNothing(useDb, teamClient, teams):
    conn = useDb(fetchone=[TEAM], failOn="INSERT INTO tracks")
    answer = upload(teamClient, coneFile())
    assert answer.status_code == 500 and answer.get_json()["message"] == "could not store the track"
    assert leftovers(teams) == [] and conn.rollbacks == 1 and conn.commits == 0


def test_aFailedRenameLeavesNothing(useDb, teamClient, teams, monkeypatch):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    realReplace = pathlib.Path.replace
    calls = []

    def secondFails(self, target):
        calls.append(target)
        if len(calls) == 2:
            raise OSError("disk full")
        return realReplace(self, target)
    monkeypatch.setattr(pathlib.Path, "replace", secondFails)
    assert upload(teamClient, coneFile()).status_code == 500
    assert leftovers(teams) == [] and conn.rollbacks == 1 and conn.commits == 0


def test_aFailedCommitLeavesNothing(useDb, teamClient, teams):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})

    def refuse():
        raise RuntimeError("lost connection")
    conn.commit = refuse
    assert upload(teamClient, coneFile()).status_code == 500
    assert leftovers(teams) == [] and conn.rollbacks == 1

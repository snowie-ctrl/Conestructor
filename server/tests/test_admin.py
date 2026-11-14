from datetime import datetime

import pytest

from conftest import ADMIN_TOKEN, LAN, PUBLIC, appClient, writeConfig


@pytest.mark.parametrize("token", [None, "", "wrong"])
def test_everyRouteNeedsTheToken(adminRoutes, token):
    headers = {} if token is None else {"HTTP_X_ADMIN_TOKEN": token}
    client = appClient(adminRoutes.coneAdminBP, "/api/cone-admin", headers)
    for method, path in [("GET", "/teams"), ("POST", "/teams"), ("GET", "/tracks"), ("DELETE", "/tracks/1"),
                         ("POST", "/teams/1/key")]:
        answer = client.open("/api/cone-admin" + path, method=method)
        assert answer.status_code == 401, (method, path)


def test_withoutAConfigNothingIsAllowed(adminRoutes, tmp_path):
    adminRoutes.CONFIG_FILE = tmp_path / "missing.json"
    adminRoutes._configCache.update({"mtime": None, "config": {}})
    client = appClient(adminRoutes.coneAdminBP, "/api/cone-admin", {"HTTP_X_ADMIN_TOKEN": ADMIN_TOKEN})
    assert client.get("/api/cone-admin/teams").status_code == 401


def test_aTeamIsMadeWithACodeThatReadsBack(useDb, adminClient, rules):
    conn = useDb(lastrowids={"teams": [5]})
    answer = adminClient.post("/api/cone-admin/teams", json={"name": "  Our team "})
    assert answer.status_code == 201
    made = answer.get_json()
    assert made["id"] == 5 and made["name"] == "Our team" and len(made["key"]) == 43
    assert rules.readTeamCode(made["code"]) == {"team": "Our team", "lan": LAN, "public": PUBLIC, "key": made["key"]}
    sql, params = conn.cur.statements("INSERT")[0]
    assert sql == "INSERT INTO teams (name, keyHash, created) VALUES (%s, %s, %s)"
    assert params[:2] == ("Our team", rules.keyHash(made["key"])) and made["key"] not in params
    assert isinstance(params[2], datetime) and conn.commits == 1


@pytest.mark.parametrize("body", [{}, {"name": ""}, {"name": "   "}, {"name": "x" * 101}, {"name": 5}])
def test_aTeamNeedsAName(adminClient, body):
    answer = adminClient.post("/api/cone-admin/teams", json=body)
    assert answer.status_code == 400


def test_aCodeNeedsAnAddressInTheConfig(adminRoutes, adminClient, tmp_path):
    writeConfig(adminRoutes, tmp_path / "coneAdminConfig.json", {"token": ADMIN_TOKEN})
    answer = adminClient.post("/api/cone-admin/teams", json={"name": "Our team"})
    assert answer.status_code == 500
    assert answer.get_json()["message"] == "coneAdminConfig.json has neither lanBase nor publicBase"


def test_aCodeMayCarryOnlyThePublicAddress(adminRoutes, adminClient, useDb, rules, tmp_path):
    writeConfig(adminRoutes, tmp_path / "coneAdminConfig.json", {"token": ADMIN_TOKEN, "publicBase": PUBLIC})
    useDb(lastrowids={"teams": [5]})
    code = adminClient.post("/api/cone-admin/teams", json={"name": "Our team"}).get_json()["code"]
    assert rules.readTeamCode(code)["lan"] is None


def test_aNewKeyReplacesTheOldOne(useDb, adminClient, rules):
    conn = useDb(fetchone=[{"name": "Our team"}])
    answer = adminClient.post("/api/cone-admin/teams/5/key").get_json()
    assert answer["id"] == 5 and answer["name"] == "Our team"
    assert rules.readTeamCode(answer["code"])["key"] == answer["key"]
    sql, params = conn.cur.statements("UPDATE")[0]
    assert sql == "UPDATE teams SET keyHash = %s WHERE id = %s"
    assert params == (rules.keyHash(answer["key"]), 5) and conn.commits == 1


def test_aNewKeyForNoTeam(useDb, adminClient):
    conn = useDb(fetchone=[None])
    assert adminClient.post("/api/cone-admin/teams/9/key").status_code == 404
    assert conn.cur.statements("UPDATE") == []


def test_theTeams(useDb, adminClient):
    conn = useDb(fetchall=[[{"id": 1, "name": "Our team", "created": datetime(2026, 11, 12, 9, 30), "tracks": 4}]])
    answer = adminClient.get("/api/cone-admin/teams").get_json()
    assert answer == {"status": "ok", "teams": [{"id": 1, "name": "Our team", "tracks": 4,
                                                  "created": "2026-11-12T09:30:00Z"}]}
    assert conn.cur.executed[0][0] == ("SELECT t.id, t.name, t.created, COUNT(k.id) AS tracks FROM teams t "
                                       "LEFT JOIN tracks k ON k.teamId = t.id GROUP BY t.id, t.name, t.created "
                                       "ORDER BY t.id")


def test_theTracksOfOneTeamOrAll(useDb, adminClient):
    row = {"id": 12, "teamId": 1, "team": "Our team", "name": "Duck pond", "cones": 132,
           "uploaded": datetime(2026, 11, 12, 14, 2), "bytes": 3000}
    conn = useDb(fetchall=[[row], [row]])
    answer = adminClient.get("/api/cone-admin/tracks?team=1").get_json()
    assert answer["tracks"] == [dict(row, uploaded="2026-11-12T14:02:00Z")]
    sql, params = conn.cur.executed[0]
    assert sql.endswith("WHERE k.teamId = %s ORDER BY k.uploaded DESC, k.id DESC") and params == (1,)
    adminClient.get("/api/cone-admin/tracks")
    sql, params = conn.cur.executed[1]
    assert "WHERE" not in sql and params == ()


@pytest.mark.parametrize("team", ["x", "²", "١", "-1", ""], ids=["letter", "superscript two", "arabic one",
                                                                         "negative", "empty"])
def test_aBadTeamFilter(adminClient, team):
    # Final review, minor 6: str.isdigit() takes "²", which int() then refuses (a 500).
    assert adminClient.get("/api/cone-admin/tracks", query_string={"team": team}).status_code == 400


def test_deletingATrackRemovesItsRowAndFiles(useDb, adminClient, rules):
    for trackId in (12, 13):
        for path in rules.trackFiles(1, trackId):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"x")
    conn = useDb(fetchone=[{"teamId": 1}])
    assert adminClient.delete("/api/cone-admin/tracks/12").get_json() == {"status": "ok", "id": 12}
    assert conn.cur.statements("DELETE")[0] == ("DELETE FROM tracks WHERE id = %s", (12,))
    assert conn.commits == 1
    assert not any(p.exists() for p in rules.trackFiles(1, 12))
    assert all(p.exists() for p in rules.trackFiles(1, 13))


def test_deletingNoTrack(useDb, adminClient):
    conn = useDb(fetchone=[None])
    assert adminClient.delete("/api/cone-admin/tracks/99").status_code == 404
    assert conn.cur.statements("DELETE") == []

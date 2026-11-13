from types import SimpleNamespace

import pytest

from conftest import loadModule


def test_theRealDatabaseIsRefused():
    smoke = loadModule("coneSmoke")
    for name in ["coneDB", "bad name;", "gluttonyDB", ""]:
        with pytest.raises(ValueError):
            smoke.scratchConnections(name, lambda n: None)


def test_everyConnectionSwitchesToTheScratchDatabase():
    smoke = loadModule("coneSmoke")
    executed = []
    cursor = SimpleNamespace(execute=lambda sql: executed.append(sql), close=lambda: None)
    conn = SimpleNamespace(cursor=lambda: cursor)
    connect = smoke.scratchConnections("cone_smoke", lambda name: conn)
    assert connect("cone") is conn and executed == ["USE `cone_smoke`"]


def test_mainRefusesABadNameWithExitTwo():
    smoke = loadModule("coneSmoke")
    assert smoke.main(["--database", "conedb"]) == 2


def test_aNonEmptyScratchDatabaseFailsTheFirstStep(capsys, tmp_path):
    smoke = loadModule("coneSmoke")
    answer = SimpleNamespace(status_code=200, mimetype="application/json",
                             get_json=lambda silent=True: {"status": "ok", "teams": [{"id": 1}]},
                             get_data=lambda: b"")
    client = SimpleNamespace(open=lambda *args, **kwargs: answer)
    assert smoke.runSteps(client, tmp_path) == 1
    assert "FAIL  empty: the scratch database is not empty: drop and recreate it" in capsys.readouterr().out

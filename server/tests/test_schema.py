import pathlib
import re

SCHEMA = (pathlib.Path(__file__).resolve().parent.parent / "schema.sql").read_text(encoding="utf-8")


def test_theTablesAreTeamsAndTracks():
    assert set(re.findall(r"CREATE TABLE (\w+)", SCHEMA)) == {"teams", "tracks"}


def test_theOldTableGoesFirstAndTracksBeforeTeams():
    drops = re.findall(r"DROP TABLE IF EXISTS (\w+);", SCHEMA)
    assert drops == ["tracks", "teams"]
    assert SCHEMA.index("DROP TABLE IF EXISTS teams") < SCHEMA.index("CREATE TABLE teams")


def test_everyTableUsesTheHouseEngineAndCollation():
    tails = re.findall(r"CREATE TABLE \w+ \(.*?\n\)(.*?);", SCHEMA, re.S)
    assert len(tails) == 2
    for tail in tails:
        assert tail.strip() == "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci"


def test_onlyTheKeysHashIsStoredAndItIsUnique():
    assert "keyHash CHAR(64) NOT NULL" in SCHEMA
    assert "UNIQUE KEY keyHash (keyHash)" in SCHEMA
    assert not re.search(r"\bkey\s+(VARCHAR|CHAR|TEXT)", SCHEMA, re.I)


def test_noPathsAreStored():
    assert "Path" not in SCHEMA

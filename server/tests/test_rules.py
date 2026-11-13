import json

import pytest

from samples import PICTURE, coneFile

# The format both sides agree on: coneRules makes it, TeamServer::parseCode reads it (tst_teamserver has the same text).
FIXED_CODE = ("CONE1.eyJ2IjoxLCJ0ZWFtIjoiT3VyIHRlYW0iLCJsYW4iOiJodHRwOi8vbGFuLmV4YW1wbGU6NTAwMCIsInB1YmxpYyI6Imh0dHBzOi8v"
              "cHVibGljLmV4YW1wbGUiLCJrZXkiOiJra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2trIn0")


def test_aTrackFileIsRead(rules):
    assert rules.readTrack(coneFile("Duck pond", 3)) == {"name": "Duck pond", "cones": 3}
    assert rules.readTrack(coneFile("  Spaced  ", 0)) == {"name": "Spaced", "cones": 0}
    assert rules.readTrack(coneFile("x" * 300, 1))["name"] == "x" * 200


def doc(**change):
    d = json.loads(coneFile())
    d.update(change)
    return json.dumps(d).encode("utf-8")


@pytest.mark.parametrize("data, message", [
    (b"not json", "not a track file"),
    (b"\xff\xfe", "not a track file"),
    (b"[1, 2]", "not a track file"),
    (doc(format="something-else"), "not a track file"),
    (doc(version=2), "this track file's version is not supported"),
    (doc(version=True), "this track file's version is not supported"),
    (doc(name=""), "the track has no name"),
    (doc(name="   "), "the track has no name"),
    (doc(name=5), "the track has no name"),
    (doc(cones={}), "the track has no cone list"),
], ids=["text", "not utf-8", "a list", "format", "version 2", "version true", "empty name", "blank name",
        "number name", "cones an object"])
def test_aBadTrackFileIsRefused(rules, data, message):
    with pytest.raises(rules.Refused) as refused:
        rules.readTrack(data)
    assert str(refused.value) == message


def test_aThumbnailMustBeASmallJpeg(rules):
    rules.checkThumbnail(PICTURE)
    with pytest.raises(rules.Refused, match="not a JPEG"):
        rules.checkThumbnail(b"\x89PNG\r\n\x1a\n")
    with pytest.raises(rules.Refused, match="not a JPEG"):
        rules.checkThumbnail(b"")
    with pytest.raises(rules.Refused, match="too large"):
        rules.checkThumbnail(PICTURE[:3] + b"\0" * rules.MAX_THUMBNAIL)


def test_teamNames(rules):
    assert rules.teamName("  Our team ") == "Our team"
    for bad in ["", "   ", None, 5, "x" * 101]:
        with pytest.raises(rules.Refused):
            rules.teamName(bad)


def test_keysAreLongRandomAndOnlyTheirHashIsKept(rules):
    a, b = rules.newKey(), rules.newKey()
    assert len(a) == 43 and a != b
    assert rules.keyHash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert len(rules.keyHash(a)) == 64


def test_theTeamCodeHasAFixedForm(rules):
    assert rules.teamCode("Our team", "k" * 43, "http://lan.example:5000/", "https://public.example") == FIXED_CODE


def test_teamCodesReadBack(rules):
    code = rules.teamCode("Équipe 🏁", "abc", None, "https://public.example")
    assert rules.readTeamCode("  " + code + "\n") == {"team": "Équipe 🏁", "lan": None,
                                                       "public": "https://public.example", "key": "abc"}
    with pytest.raises(ValueError):
        rules.teamCode("Our team", "abc", None, None)


@pytest.mark.parametrize("code", ["", "CONE2.e30", "CONE1.!!!", "CONE1.e30", "CONE1." + "W10",
                                  "CONE1.eyJ2IjoxLCJrZXkiOiJhIn0", "CONE1.eyJ2IjoyLCJwdWJsaWMiOiJ4Iiwia2V5IjoiYSJ9"],
                         ids=["empty", "prefix", "not base64", "empty object", "a list", "no address", "version 2"])
def test_notTeamCodes(rules, code):
    with pytest.raises(ValueError):
        rules.readTeamCode(code)


def test_timesAndPaths(rules, teams):
    moment = rules.utcNow()
    assert moment.tzinfo is None and moment.microsecond == 0
    assert rules.isoUtc(moment.replace(year=2026, month=11, day=12, hour=14, minute=2, second=0)) == "2026-11-12T14:02:00Z"
    assert rules.trackFiles(3, 12) == (teams / "3" / "12.cone", teams / "3" / "12.jpg")

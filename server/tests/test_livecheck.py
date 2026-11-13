import io

import flask

from conftest import loadModule


def test_theFormIsReadByFlask():
    live = loadModule("liveCheck")
    body, kind = live.multipart([("file", "track.cone", "application/json", b'{"a": 1}'),
                                 ("thumbnail", "thumbnail.jpg", "image/jpeg", b"\xff\xd8\xff\x00")])
    app = flask.Flask("live-form")
    seen = {}

    @app.route("/echo", methods=["POST"])
    def echo():
        seen.update({name: (f.filename, f.mimetype, f.read()) for name, f in flask.request.files.items()})
        return "ok"
    assert app.test_client().post("/echo", data=io.BytesIO(body), content_type=kind).status_code == 200
    assert seen == {"file": ("track.cone", "application/json", b'{"a": 1}'),
                    "thumbnail": ("thumbnail.jpg", "image/jpeg", b"\xff\xd8\xff\x00")}


def test_withoutACodeItSaysWhatToSet(capsys):
    live = loadModule("liveCheck")
    assert live.main([], environ={}) == 2
    assert "CONE_CHECK_CODE" in capsys.readouterr().err

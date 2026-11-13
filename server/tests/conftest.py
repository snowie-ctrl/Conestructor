"""
Loads the server modules the way Caduceus does, minus the server. The routes do `from . import DBUtils, coneRules`,
so they are imported as submodules of a stand-in package whose DBUtils refuses to connect: a test that reaches the
database by accident fails loudly instead of touching data. (The pattern is Gluttony's server/tests/conftest.py.)
"""
import importlib.util
import json
import pathlib
import sys
import types

import flask
import pytest

SERVER = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from fakes import FakeConn, FakeCursor  # noqa: E402

ADMIN_TOKEN = "test-admin-token"
KEY = "test-team-key"
TEAM = {"id": 3, "name": "Our team"}
LAN = "http://lan.example:5000"
PUBLIC = "https://public.example"


def _refuseConnection(name):
    raise RuntimeError("tests must not open a database connection")


def _load(name):
    if "cone_server" not in sys.modules:
        package = types.ModuleType("cone_server")
        package.__path__ = [str(SERVER)]
        dbutils = types.ModuleType("cone_server.DBUtils")
        dbutils.initConnection = _refuseConnection
        package.DBUtils = dbutils
        sys.modules["cone_server"] = package
        sys.modules["cone_server.DBUtils"] = dbutils
    spec = importlib.util.spec_from_file_location(f"cone_server.{name}", SERVER / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def loadModule(name):
    """Any server module, loaded inside the stand-in package (the rules, the routes, the smoke test...)."""
    return sys.modules.get(f"cone_server.{name}") or _load(name)


@pytest.fixture
def rules():
    return loadModule("coneRules")


@pytest.fixture(autouse=True)
def isolated(monkeypatch, tmp_path):
    """Each test gets its own teams folder and no database."""
    rules = loadModule("coneRules")
    monkeypatch.setattr(rules, "TEAMS_ROOT", tmp_path / "teams")
    monkeypatch.setattr(sys.modules["cone_server.DBUtils"], "initConnection", _refuseConnection)


@pytest.fixture
def teams(rules):
    """The test's own TEAMS_ROOT (not made yet)."""
    return rules.TEAMS_ROOT


@pytest.fixture
def useDb(monkeypatch):
    """Installs a FakeConn answering the queued rows; returns it."""
    def install(fetchone=(), fetchall=(), lastrowids=None, failOn=None, rowcounts=()):
        conn = FakeConn(FakeCursor(fetchone, fetchall, lastrowids, failOn, rowcounts))

        def connect(name):
            assert name == "cone", f"connected to {name!r}"
            return conn

        monkeypatch.setattr(sys.modules["cone_server.DBUtils"], "initConnection", connect)
        return conn
    return install


def appClient(blueprint, prefix, headers):
    """A Flask test client for one blueprint, sending `headers` (WSGI names, e.g. HTTP_X_TEAM_KEY) on every request."""
    app = flask.Flask("cone-tests")
    app.register_blueprint(blueprint, url_prefix=prefix)
    client = app.test_client()
    client.environ_base.update(headers)
    return client

"""
The owner's admin commands for Conestructor's team server, run from the PC on the LAN (never deployed). They call the
LAN-only admin API (/api/cone-admin, coneAdminRoutes.py) with the admin token. Standard library only.

    py -3 server\\coneAdmin.py make-team "Our team"     makes a team and prints its team code, once
    py -3 server\\coneAdmin.py new-key 1                replaces team 1's key; codes made before stop working
    py -3 server\\coneAdmin.py teams
    py -3 server\\coneAdmin.py tracks [--team 1]
    py -3 server\\coneAdmin.py delete 12 [--yes]

The server's LAN base (http://<LAN address>:5000) and the admin token come from CONE_ADMIN_URL and CONE_ADMIN_TOKEN, or
from coneAdmin.local.json beside this file ({"url": ..., "token": ...}; gitignored). The token is never printed.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

LOCAL_CONFIG = Path(__file__).resolve().parent / "coneAdmin.local.json"
AGENT = "ConestructorAdmin/1.0"


class Failed(Exception):
    pass


def settings(environ=os.environ, local=None):
    """(LAN base without a trailing slash, admin token)."""
    local = LOCAL_CONFIG if local is None else local
    url, token = environ.get("CONE_ADMIN_URL"), environ.get("CONE_ADMIN_TOKEN")
    if (not url or not token) and local.is_file():
        try:
            stored = json.loads(local.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            stored = {}
        if isinstance(stored, dict):
            url = url or stored.get("url")
            token = token or stored.get("token")
    if not url or not token:
        raise Failed("set CONE_ADMIN_URL and CONE_ADMIN_TOKEN, or write server/coneAdmin.local.json")
    return url.rstrip("/"), token


def call(base, token, method, route, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    request = urllib.request.Request(base + "/api/cone-admin" + route, data=data, method=method)
    request.add_header("User-Agent", AGENT)
    request.add_header("X-Admin-Token", token)
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            return json.loads(answer.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 401:
            raise Failed("unauthorized (check the admin token)")
        try:
            message = json.loads(e.read().decode("utf-8")).get("message")
        except (ValueError, AttributeError):
            message = None
        raise Failed(f"the server answered {e.code}" + (f": {message}" if message else ""))
    except (urllib.error.URLError, OSError) as e:
        raise Failed(f"can't reach {base}: {getattr(e, 'reason', e)}")


def localTime(iso):
    """A UTC time from the server (2026-11-12T14:02:00Z) in this PC's time: 2026-11-12 09:02."""
    moment = datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    return moment.astimezone().strftime("%Y-%m-%d %H:%M")


def size(count):
    if count >= 1024 * 1024:
        return f"{count / 1024 / 1024:.1f} MB"
    return f"{max(1, round(count / 1024))} KB"


def makeTeam(base, token, name, out):
    team = call(base, token, "POST", "/teams", {"name": name})
    print(f"Team {team['id']} ({team['name']}) made. Its team code, shown only now; paste it into Preferences > Team:",
          file=out)
    print(team["code"], file=out)


def newKey(base, token, teamId, out):
    team = call(base, token, "POST", f"/teams/{teamId}/key")
    print(f"New key for team {team['id']} ({team['name']}): codes made before no longer work. Its team code:", file=out)
    print(team["code"], file=out)


def teams(base, token, out):
    rows = call(base, token, "GET", "/teams")["teams"]
    if not rows:
        print("No teams yet.", file=out)
    for t in rows:
        print(f"{t['id']}  {t['name']}  ({t['tracks']} tracks, made {localTime(t['created'])})", file=out)


def describe(track):
    return (f"{track['name']}  ({track['team']}, {track['cones']} cones, {localTime(track['uploaded'])}, "
            f"{size(track['bytes'])})")


def tracks(base, token, team, out):
    rows = call(base, token, "GET", "/tracks" + (f"?team={team}" if team is not None else ""))["tracks"]
    if not rows:
        print("No tracks.", file=out)
    for track in rows:
        print(f"{track['id']}  {describe(track)}", file=out)


def delete(base, token, trackId, yes, out, ask):
    rows = call(base, token, "GET", "/tracks")["tracks"]
    track = next((k for k in rows if k["id"] == trackId), None)
    if track is None:
        raise Failed(f"no track {trackId}")
    print(f"Track {trackId}: {describe(track)}", file=out)
    if not yes and ask("Delete it? [y/N] ").strip().lower() not in ("y", "yes"):
        print("Kept.", file=out)
        return
    call(base, token, "DELETE", f"/tracks/{trackId}")
    print(f"Deleted track {trackId}.", file=out)


def main(argv=None, out=sys.stdout, err=sys.stderr, ask=input, environ=os.environ, local=None):
    parser = argparse.ArgumentParser(prog="coneAdmin.py",
                                     description="Admin commands for Conestructor's team server (LAN only).")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("make-team", help="make a team and print its team code").add_argument("name")
    commands.add_parser("new-key", help="replace a team's key and print its new code").add_argument("team", type=int)
    commands.add_parser("teams", help="list the teams")
    listing = commands.add_parser("tracks", help="list the tracks")
    listing.add_argument("--team", type=int)
    removing = commands.add_parser("delete", help="delete a track")
    removing.add_argument("track", type=int)
    removing.add_argument("--yes", action="store_true", help="do not ask first")
    args = parser.parse_args(argv)
    try:
        base, token = settings(environ, local)
        if args.command == "make-team":
            makeTeam(base, token, args.name, out)
        elif args.command == "new-key":
            newKey(base, token, args.team, out)
        elif args.command == "teams":
            teams(base, token, out)
        elif args.command == "tracks":
            tracks(base, token, args.team, out)
        else:
            delete(base, token, args.track, args.yes, out, ask)
    except Failed as e:
        print(f"coneAdmin: {e}", file=err)
        return 1
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="backslashreplace")
    sys.exit(main())

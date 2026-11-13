# Conestructor v1.0.0 part 5: team server

Date: 2026-11-12. Status: approved in conversation section by section; this document is for the owner's review.
Roadmap and part 1: `2026-11-10-v1-roadmap-and-part1-core-canvas-design.md`. Parts 2 to 4: `2026-11-10-part2-setup-and-
track-files-design.md`, `2026-11-11-part3-ease-of-use-design.md`, `2026-11-11-part4-cones-design.md`; each plan in
`docs/superpowers/plans/` adds its own decisions.

## Why

A track designed on one laptop has to reach the rest of the team: the person laying cones at the lot, the teammate who
tweaks it next week. Part 5 lets a team share tracks through the owner's server. One team code, pasted once into
Preferences, lets anyone on the team upload the open track and open any of the team's tracks, at home on the LAN or
anywhere over the internet. The app keeps working fully without a code. Part 5 also clears five of the six minors
deferred from part 4's final review.

## Decisions

| Topic | Decision |
|---|---|
| Server shape | `server/` in the repo holds Flask blueprints dropped into the owner's existing API service (Caduceus) beside the other apps' blueprints, as Gluttony's `server/` does. `coneRoutes.py` moves there and is rewritten. |
| Old data | Start clean: the new schema replaces the prototype's `tracks` table; its three old-format track folders are deleted at cut-over. Nothing else calls the old routes. |
| Teams | Multi-team tables. Each team has one key; a team sees only its own tracks. v1 makes one team, the owner's. |
| Uploading | Every upload is a new entry; names can repeat. No uploader names. A track uploads only if it processes (setup done, at least one element); it is sent as it is now, touch-ups included, with no local save needed. |
| The list | Name, cone count, upload time and a thumbnail, newest first. |
| Thumbnail | The lot photo cropped to the track with the cones and route line drawn on it, about 400 px on the long side, JPEG under 200 KB, drawn by the app at upload time. |
| Opening | A team track opens with no path ("Duck pond (from team)"); Save asks where. It is not unsaved and not a recent file. |
| Team code | One line, `CONE1.` + base64url JSON with the team's name, the LAN address, the public address and the key. Made by the server; never in the repo. |
| Admin | LAN-only admin routes and a standard-library command-line script, `server/coneAdmin.py`: make a team, replace a key, list teams and tracks, delete a track. Nothing admin ships in the app. |
| App networking | One C++ singleton, `TeamServer` (Qt Network): LAN first, then the public host; list, upload, download; draws the thumbnail. QML shows the dialogs. |
| Addresses | The LAN address and the public domain are never written in the repo, the docs, the tests or commit messages; examples use `<LAN address>` and `<public host>`. |
| Part 4 minors | 1 to 5 are fixed here; 6 (cone drags rebuilding every cone picture) stays deferred. |
| Format | `.cone` is unchanged (version 1). |
| Version | 0.6.0. Branch `part5-team-server`. |

## The server

### Files

| File | Job |
|---|---|
| `server/coneRules.py` | Pure logic, no Flask or database: checks an uploaded `.cone` (UTF-8 JSON, `format` is `conestructor-track`, `version` is 1, a string `name`, a `cones` list) and reads its name and cone count; checks a thumbnail (JPEG header, at most 200 KB); makes keys (32 random bytes, base64url) and hashes them (SHA-256 hex); builds and reads team codes. |
| `server/coneRoutes.py` | The team API, `coneBP`, registered at `/api/cone`. The only prefix nginx passes. |
| `server/coneAdminRoutes.py` | The admin API, `coneAdminBP`, registered at `/api/cone-admin`. LAN only. Every request needs `X-Admin-Token` matching `coneAdminConfig.json` beside it. |
| `server/coneAdminConfig.example.json` | `{ "token": "<long random token>", "lanBase": "http://<LAN address>:5000", "publicBase": "https://<public host>" }`. The real file (`chmod 600`) lives only on the server and is gitignored. |
| `server/schema.sql` | Drops the old `tracks` table and creates `teams` and `tracks`. |
| `server/coneAdmin.py` | The admin script (see below). |
| `server/coneSmoke.py` | The smoke test on a scratch database. |
| `server/liveCheck.py` | The live check after cut-over (LAN and public). |
| `server/requirements-dev.txt` | `flask` and `pytest`, for the tests on the PC (`server/.venv`). |
| `server/tests/` | pytest, with a stand-in package and a fake MySQL connection copied from Gluttony's (`conftest.py`, `fakes.py`). |
| `server/README.md` | What goes where, and the rollout steps. |

The routes stay thin: validation and team-code logic live in `coneRules.py`. The routes connect through the existing
`DBUtils.initConnection("cone")` (coneDB).

### Tables

```sql
teams  (id INT UNSIGNED PK AUTO_INCREMENT, name VARCHAR(100) NOT NULL, keyHash CHAR(64) NOT NULL UNIQUE,
        created DATETIME NOT NULL)
tracks (id INT UNSIGNED PK AUTO_INCREMENT, teamId INT UNSIGNED NOT NULL REFERENCES teams(id),
        name VARCHAR(200) NOT NULL, cones INT UNSIGNED NOT NULL, uploaded DATETIME NOT NULL,
        bytes INT UNSIGNED NOT NULL, INDEX (teamId, uploaded))
```

Times are UTC. Only the key's hash is stored, so a database dump does not give away keys. Files live at
`/pool/appFiles/conestructor/teams/<teamId>/<trackId>.cone` and `.jpg`: paths come from ids only, never from the request
or the database, so nothing can steer them.

### Team API (`/api/cone/`)

Every request except `ping` needs the header `X-Team-Key`; a key matching no team answers 401.

| Route | Answers |
|---|---|
| `GET /ping` | `{"status": "ok"}`. The app uses it to find which address answers. |
| `GET /team` | `{"name": "Our team"}`. |
| `GET /tracks` | `{"tracks": [{ "id", "name", "cones", "uploaded" (ISO 8601 UTC), "bytes" }]}`, the team's tracks, newest first. |
| `GET /tracks/<id>/thumbnail` | The JPEG. |
| `GET /tracks/<id>/file` | The `.cone` file (`application/json`). |
| `POST /tracks` | A multipart form: `file` (the `.cone`) and `thumbnail` (the JPEG). The name and cone count are read from the file, never from other form fields. At most 40 MB. Answers `{"id": 12}` with 201. |

- Another team's track answers 404, the same as a track that does not exist.
- Errors are JSON `{"status": "error", "message": "..."}`: 400 (not a track file, not a JPEG, thumbnail too large,
  missing part), 401 (bad key), 404, 413 (over 40 MB), 500 (database or disk).
- An upload writes both files under temporary names, inserts the row, renames the files to the row's id and commits; if
  any step fails, the row is rolled back and the files are removed, so a failed upload leaves nothing behind.

### Admin API (`/api/cone-admin/`, LAN only)

| Route | Does |
|---|---|
| `POST /teams` `{"name"}` | Makes a team; answers its id, key and team code, once. |
| `POST /teams/<id>/key` | Replaces the team's key; answers the new key and code. Old codes stop working. |
| `GET /teams` | id, name, track count, created. |
| `GET /tracks?team=<id>` | id, team, name, cones, uploaded, bytes; every team's when `team` is left out. |
| `DELETE /tracks/<id>` | Deletes the row and both files. |

The team code is built on the server from `lanBase` and `publicBase` in `coneAdminConfig.json`, so the addresses live
only on the server and inside codes.

### nginx

A new server block for the Conestructor subdomain in the server's nginx site file, beside the other apps' blocks and
with the same `listen` port and upstream: `location /api/cone/` passes to the API with `client_max_body_size 40m`
and `Cache-Control: private`; `location /` answers 404. `/api/cone-admin/` never matches, so it stays LAN only (the LAN
reaches the API's own port directly). The block's text in `server/README.md` uses `<public host>`.

## The team code and the admin script

The team code is `CONE1.` followed by base64url (no padding) of:

```json
{ "v": 1, "team": "Our team", "lan": "http://<LAN address>:5000", "public": "https://<public host>", "key": "<43 characters>" }
```

- `lan` or `public` may be missing, but not both. Unknown fields are ignored.
- It is not encrypted: anyone holding it can reach the team's tracks. Preferences and the README say to treat it like a
  password and share it only inside the team.

`server/coneAdmin.py` uses only the Python standard library. It reads the LAN base and the admin token from
`CONE_ADMIN_URL` and `CONE_ADMIN_TOKEN`, or from a gitignored `server/coneAdmin.local.json`.

| Command | Does |
|---|---|
| `make-team "Our team"` | Makes the team and prints its code once. |
| `new-key <team id>` | Replaces the team's key and prints the new code. |
| `teams` | id, name, track count, created. |
| `tracks [--team <id>]` | id, team, name, cones, uploaded (local time), size. |
| `delete <track id> [--yes]` | Shows the track, asks `y/N` unless `--yes`, deletes it. |

Errors are one line ("unauthorized", "can't reach <url>", "no track 12") and a non-zero exit.

## The app

### Preferences › Team

A section after Car:

- **Team code**: a masked field with a *Show* toggle. A pasted value that is not a team code shows "Not a team code" in
  red and is not saved.
- **Check**: "Connected to Our team (on the LAN)" or "(over the internet)", "Can't reach the team server", or "The
  server doesn't know this code".
- **Clear** removes the code.
- Under it: "Treat the team code like a password: it opens your team's tracks."
- Saved as `teamCode` in `Conestructor.ini`.

### File menu

New · Open… · **Open from team…** (Ctrl+Shift+O) · Open Recent · Save · Save As… · **Upload to team…** · Load lot
photo… · Quit. Without a team code both team items open Preferences scrolled to Team, with the line "Paste your team
code to use team tracks."

### Open from team

1. Unsaved changes are asked about first, as for Open.
2. A dialog, "Team tracks: Our team", shows "Connecting…", then the tracks newest first: thumbnail, name, "132 cones" and
   the upload time in local time. Thumbnails fill in as they arrive and are kept for the session. A Refresh button
   fetches the list again.
3. Open (or a double-click) downloads the track with a progress bar and Cancel.
4. The track opens with no path: the title reads "Duck pond (from team)", it is not unsaved, and it is not added to the
   recent files. Save behaves as Save As, starting with the track's name. The autosave backup treats it as an untitled
   track.

An empty list says "No tracks on the team yet. File › Upload to team shares the open track." A file that does not open
(damaged, or not a track) shows the same banner as opening a damaged file from disk.

### Upload to team

1. The track is processed as Place cones would (the touched-up list while locked). If it cannot be, the usual error
   banner says why and nothing is sent.
2. A dialog shows the thumbnail and "Upload [Duck pond] (132 cones) to Our team? Teammates will be able to open it."
   The name is editable and starts as the track's name; an Untitled track must be given one. The name changes only the
   uploaded copy (its `name` field), not the open track.
3. Upload shows a progress bar and Cancel. When done, the status bar says "Uploaded Duck pond to Our team". The open
   track's saved or unsaved state does not change.

### `TeamServer` (C++)

A QML singleton beside `Settings` and `TrackFile`, using Qt Network (`QNetworkAccessManager`).

- **Reading the code:** a static parser returns the team, the addresses and the key, or why it is not a code. Shared
  by Preferences and the requests.
- **Finding the server:** when the code has a LAN address, `GET /api/cone/ping` there with a 1.5 s timeout; if it
  answers, the LAN is used, otherwise the public address. The choice is kept for the session; after a request fails to
  connect, the next request probes again once.
- **Requests:** check (ping then `/team`), list, thumbnail, upload (multipart), download. Each reports success or one
  of these sentences:
  - "Can't reach the team server (tried the LAN and the internet)." (or "...(tried the internet)." without a LAN address)
  - "The team code was not accepted. Check it in Preferences › Team." (401)
  - "Too large to upload (over 40 MB)." (413, also checked before sending)
  - "The server refused the track: <its message>." (400)
  - "The server had a problem. Try again later." (500 or anything unexpected)
- **Timeouts:** 15 s for check, list and thumbnails; an upload or download is abandoned after 30 s without progress.
- **The thumbnail:** drawn with QPainter from the photo in `PhotoStore` and the cone positions (photo pixels, with type)
  and route handed over from QML: the photo cropped to the cones' extent plus a 10% margin (at least 20 m across),
  scaled so the long side is 400 px; standing cones orange, leaning cones yellow, the route a thin white line; a dark
  background when the track has no photo. JPEG, quality lowered if needed to stay under 200 KB.
- **Downloads** go through `TrackFile`'s existing open path (the photo into `PhotoStore`, the text to QML), from bytes
  rather than a file.
- The public address is HTTPS, through Qt's Windows TLS backend. Part 6's release must ship Qt's TLS plugin
  (`tls/qschannelbackend.dll`) and its packaged-zip check must include an upload and a download over HTTPS.

## Part 4's minors

1. When touch-ups lock the track, a track piece in hand is put back (placing is cancelled), so the next click is not
   refused silently and nothing unrelated is selected.
2. Edit › Duplicate and Edit › Reverse direction are greyed out while the track is locked, as in the right-click menu.
3. Opening a file raises `touchUps.placed` to at least the number of cones still carrying an element id, so the change
   count is never below zero.
4. `Settings` reads `conesOwned`, `carLength` and `carWidth` as numbers, ignores values that are not finite, and clamps
   before converting, so a hand-edited ini value cannot cause undefined behaviour.
5. `test_outsideConesOnATurn` also checks that the outside cones lie on the outer side of the arc.

Deferred again: 6, every cone-drag step rebuilding every cone picture.

## Code

| Piece | Job |
|---|---|
| `server/` (new) | As above. `coneRoutes.py` at the repo root is removed. |
| `services/TeamServer` (new) | The team code, finding the server, the requests, the thumbnail. |
| `services/TrackFile` | Opening a track from downloaded bytes. |
| `services/Settings` | `teamCode`; minor 4. |
| `TrackStore.qml` | A name for a track with no path ("Duck pond (from team)"); Save as Save As for it. |
| `TeamTracksDialog.qml` (new) | The Open from team list. |
| `UploadDialog.qml` (new) | The Upload to team question and progress. |
| `PreferencesDialog.qml` | The Team section; scrolling to it. |
| `Main.qml` | The File menu items; minors 1 and 2. |
| `logic/conefile.mjs` | The uploaded copy's name; minor 3. |
| `app/CMakeLists.txt` | Qt Network; version 0.6.0. |
| `.gitignore` | `server/coneAdminConfig.json`, `server/coneAdmin.local.json`, `server/.venv/`; the old `app/config/secrets.json` line goes (the team code lives in the ini). |
| `README.md` | Team tracks in the intro and layout; the team code treated like a password; `server/` in the layout. |

## Testing

Test-first, as in parts 1 to 4. `app\tests\run.ps1` runs ctest, then qmltestrunner; the server's tests run with
`cd server && .venv\Scripts\python.exe -m pytest -q`.

- **Server (pytest, fake database, a temporary folder for files):**
  - rules: a good `.cone` accepted and its name and cones read; bad JSON, a wrong `format` or `version`, no name or no
    cones refused; JPEG header and size checks; team codes round-trip; a code with neither address refused; key hashes;
  - every team route: 401 without a key and with a wrong one; another team's track 404; the list newest first; 413 over
    40 MB; an upload that fails at the insert or the rename leaves no row and no files;
  - admin routes: 401 without the token; `make-team` returns a code that reads back to the config's addresses and a key
    whose hash was stored; `new-key` replaces the hash; delete removes the row and both files;
  - `coneAdmin.py` against a stand-in HTTP server: each command's output, `y/N`, errors.
- **Smoke test** (`coneSmoke.py`, on a scratch database whose name must contain `smoke`): make two teams, upload a
  sample, list it, fetch its thumbnail and file byte for byte, check the second team sees none of the first's and gets
  404 on its id, replace a key and check the old one gets 401, delete the track and check its files are gone.
- **C++ (Qt Test):**
  - team codes: good codes, a wrong prefix, bad base64 or JSON, no key, no address;
  - `TeamServer` against a small in-process HTTP server (`QTcpServer`): LAN used when it answers; public used when the
    LAN does not (within the timeout); each error sentence; the upload's multipart parts; a download opened through
    `TrackFile`;
  - the thumbnail: long side 400 px, JPEG under 200 KB, cone colours at the cones' pixels, the dark background without a
    photo;
  - `teamCode` round-trips; minor 4.
- **Window (`tst_qmlload`):** Preferences › Team (a bad code turns red and is not saved); the team menu items without a
  code open Preferences at Team; the Upload dialog (name prefilled, Untitled must be named, the uploaded copy carries
  the edited name); a track opened from team bytes has no path, "(from team)" in the title, is not unsaved and is not a
  recent file; minors 1 to 3 and 5.
- **Live check** (`liveCheck.py`, run at rollout): on the LAN and on the public address, ping, team, upload a small
  sample, list it, download it byte for byte, thumbnail, a wrong key gets 401; from the public address
  `/api/cone-admin/` and `/` answer 404; the sample is deleted through the admin API at the end.

## Rollout

Each server step waits for the owner's go-ahead at the time. The owner runs the `sudo` steps; Claude runs the others over
SSH from the PC. The full commands go in `server/README.md` (with `<LAN address>` and `<public host>`).

1. **Check (Claude, read only):** the deployed `coneRoutes.py` matches the repo's old one; `DBUtils` maps `"cone"`;
   `Caduceus.py` sets no `MAX_CONTENT_LENGTH` below 40 MB; the nginx site file's existing blocks (port, upstream).
2. **Smoke test:** the owner makes and grants `cone_smoke` and loads `schema.sql` into it; Claude copies the server files
   into `util/` (the old `coneRoutes.py` backed up first) and runs `coneSmoke.py`; every line `PASS`; the owner drops
   `cone_smoke` whether it passed or not.
3. **Cut-over (owner):** load `schema.sql` into coneDB (replacing the old table); delete the three old track folders;
   make `/pool/appFiles/conestructor/teams/` owned by the API's user; write `coneAdminConfig.json` (`chmod 600`).
4. **Register (Claude):** back up `Caduceus.py`; register `coneAdminBP` at `/api/cone-admin` in a defensive `try` block
   like the other admin blueprints (the existing `coneBP` registration stays); `py_compile`. The owner restarts
   `Caduceus.service`; its log must not say the cone routes failed to load.
5. **nginx (Claude):** back up the site file, add the block, `nginx -t`, reload. The owner makes sure the subdomain is
   routed through the tunnel to nginx.
6. **The team (owner):** `coneAdmin.py make-team "<team name>"`; the code goes into the owner's Preferences.
7. **Live check (Claude):** every line `PASS`, on the LAN and from outside.

**Owner check** (about 15 minutes): paste the team code and Check it; upload a track and see it in the list with its
thumbnail; open it from the team and save it; upload the same name again and see two entries; do the same over the
internet (a phone hotspot, for example); with the admin script, list the tracks and delete one; clear the code and see
the team items lead to Preferences.

## Done

- The owner approved this spec and the plan.
- `app\tests\run.ps1` passes (ctest and qmltestrunner), and the server's pytest passes.
- A clean clone on a short path builds without the map images.
- The smoke test and the live check pass.
- Nothing in the repo names the LAN address or the public domain (searched for before every push).
- The owner check passes.
- Built on branch `part5-team-server`, merged to `main` and pushed after a check of what is being pushed.

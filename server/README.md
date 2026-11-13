# Conestructor's team server

Flask blueprints for the owner's API service (Caduceus, in `/database/API/`), beside the other apps' blueprints, plus
two scripts run from the PC. The public subdomain passes only `/api/cone/`; `/api/cone-admin/` stays LAN only because
nginx never routes it (the LAN reaches the API's own port, 5000, directly). The spec is
`docs/superpowers/specs/2026-11-11-part5-team-server-design.md`.

| File | Goes to |
|---|---|
| `coneRules.py`, `coneRoutes.py`, `coneAdminRoutes.py` | `/database/API/util/` |
| `coneAdminConfig.json` (from the example; never committed) | `/database/API/util/`, `chmod 600` |
| `coneSmoke.py` | `/database/API/util/` (only for the smoke test; harmless if left) |
| `schema.sql` | run once by the owner (it replaces the prototype's `tracks` table) |
| `coneAdmin.py`, `liveCheck.py` | stay on the PC |

Track files live in `/pool/appFiles/conestructor/teams/<teamId>/<trackId>.cone` and `.jpg`.

Tests (on the PC): `cd server`, `py -3 -m venv .venv`, `.venv\Scripts\python.exe -m pip install -r requirements-dev.txt`,
then `.venv\Scripts\python.exe -m pytest -q`.

## The admin script

`coneAdmin.py` runs on the PC on the LAN. Set `CONE_ADMIN_URL` to `http://<LAN address>:5000` and `CONE_ADMIN_TOKEN` to
the token in `coneAdminConfig.json`, or write both to `server/coneAdmin.local.json` (`{"url": ..., "token": ...}`,
gitignored).

```
py -3 server\coneAdmin.py make-team "Our team"     prints the team code once: paste it into Preferences > Team
py -3 server\coneAdmin.py new-key 1                replaces the key; codes made before stop working
py -3 server\coneAdmin.py teams
py -3 server\coneAdmin.py tracks [--team 1]
py -3 server\coneAdmin.py delete 12 [--yes]
```

A team code is like a password: whoever holds it can reach the server and the team's tracks. Share it only inside the
team.

## Rollout

Each step waits for the owner's go-ahead at the time. "Claude" steps run from the PC over SSH; "owner" steps are typed
by the owner on the server (every `sudo`).

1. **Check (Claude, read only).** The deployed `util/coneRoutes.py` matches the repo's old one
   (`git show <the commit before part 5>:coneRoutes.py | md5sum` against `md5sum` on the server; `diff --strip-trailing-cr`
   if only line endings differ). `DBUtils.py` maps `"cone"` to `coneDB` (look for the mapping only; never copy the
   file). `Caduceus.py` sets no `MAX_CONTENT_LENGTH` below 41 MB. The nginx site file's existing blocks: their `listen`
   port and `proxy_pass` upstream.
2. **Smoke test.**
   - Owner: `sudo mysql -e "CREATE DATABASE cone_smoke CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"`,
     `sudo mysql -e "GRANT ALL ON cone_smoke.* TO '<the API user>'@'localhost'"`.
   - Claude: back up `util/coneRoutes.py` as `util/coneRoutes.py.bak-<date>`. From the branch, make a tar of the server
     files with LF endings and unpack it on the server:
     `git -c core.autocrlf=false archive -o cone-part5.tar HEAD:server coneRules.py coneRoutes.py coneAdminRoutes.py coneSmoke.py schema.sql`,
     copy it over, `mkdir -p /tmp/cone-part5 && tar -xf cone-part5.tar -C /tmp/cone-part5`, copy the four `.py` files
     into `/database/API/util/`, and `/database/venv/bin/python -m py_compile` each. Caduceus keeps running the old
     routes until it restarts.
   - Owner: `sudo mysql cone_smoke < /tmp/cone-part5/schema.sql`.
   - Claude: `cd /database/API && /database/venv/bin/python -m util.coneSmoke --database cone_smoke`. Every line
     `PASS`.
   - Owner: `sudo mysql -e "DROP DATABASE cone_smoke"`, whether it passed or not.
3. **Cut-over (owner).**
   - `sudo mysql coneDB < /tmp/cone-part5/schema.sql` (the old `tracks` table goes).
   - `rm -r /pool/appFiles/conestructor/tracks` (the three prototype tracks).
   - `mkdir -p /pool/appFiles/conestructor/teams` (owned by the user Caduceus runs as).
   - `coneAdminConfig.json` in `/database/API/util/` from the example, with a new long random token, the LAN base and
     the public base; `chmod 600`.
4. **Register (Claude).** Back up `Caduceus.py` as `Caduceus.py.bak-<date>`. The existing line
   `app.register_blueprint(coneBP,url_prefix="/api/cone")` stays. Add, beside the other admin blocks:

   ```python
   # Conestructor's admin routes (Code-Development/Conestructor server/): LAN only, with their own token. The team API
   # (coneBP, above) is the only prefix the public subdomain passes.
   try:
       from util.coneAdminRoutes import coneAdminBP
       app.register_blueprint(coneAdminBP, url_prefix="/api/cone-admin")
   except Exception as e:
       print(f"cone admin routes not loaded: {e}")
   ```

   `cd /database/API && /database/venv/bin/python -m py_compile Caduceus.py`. Owner: `sudo systemctl restart Caduceus.service`;
   `journalctl -u Caduceus.service -n 100 --no-pager | grep -i "cone admin routes not loaded"` must print nothing.
   LAN check: `/api/cone/ping` answers ok; `/api/cone/team` without a key answers 401.
5. **nginx (Claude).** Back up the site file, add this block beside the others (its `listen` and `proxy_pass` lines the
   same as the existing blocks'), `sudo nginx -t`, `sudo systemctl reload nginx`. Owner: make sure the subdomain is
   routed through the tunnel to nginx.

   ```nginx
   # Conestructor's team API: only its own prefix through the tunnel. The admin prefix (/api/cone-admin/) never
   # matches this location and stays LAN only. An upload is a .cone of up to 40 MB plus its thumbnail.
   server {
       listen 80;
       server_name <public host>;
       location /api/cone/ {
           client_max_body_size 41m;
           add_header Cache-Control "private" always;
           proxy_pass http://127.0.0.1:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
       location / {
           return 404;
       }
   }
   ```
6. **The team (owner).** `py -3 server\coneAdmin.py make-team "<team name>"`; paste the code into Preferences › Team.
7. **Live check (Claude).** With `CONE_CHECK_CODE` and `CONE_ADMIN_TOKEN` set: `py -3 server\liveCheck.py`. Every line
   `PASS`, on the LAN, on the public address and the cleanup. On each other public hostname in the nginx site file,
   `/api/cone/ping` must answer 404.

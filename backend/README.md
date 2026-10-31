# GodotLuau — Backend (local dev)

Local **Nakama + PostgreSQL** stack for GodotLuau's networking layer (DataStore, auth,
world server). This folder is the "central backend" that games talk to. For now it runs
entirely on your machine; the same `docker-compose.yml` deploys to a VPS later unchanged.

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (includes `docker compose`).

## Run

```bash
cd backend
docker compose up -d              # start Nakama + Postgres in the background
docker compose logs -f nakama     # watch the server log (Ctrl+C to stop watching)
docker compose down               # stop (data is kept in the volume)
docker compose down -v            # stop AND wipe the database
```

| What | URL / value |
|---|---|
| HTTP API (what `HttpService` calls) | `http://127.0.0.1:7350` |
| Admin console | `http://127.0.0.1:7351` — user `admin`, password `password` |
| Server key (for the client later) | `defaultkey` |

## Phase 1 test — is `HttpService` alive?

The trusted host project must explicitly enable HTTP and grant each exact origin
in `project.godot`. These example grants are opt-in development configuration;
they are not installed by this repository or by the script:

```ini
[godot_luau]
http/enabled=true
http/allowed_origins=PackedStringArray("https://api.github.com", "http://127.0.0.1:7350")
```

Once the extension is rebuilt, run this in a **ServerScript** (start the local
stack first). `HttpEnabled` reports native availability; assigning it cannot
authorize an origin. Handle admission/transport errors separately from HTTP
status responses:

<!-- HttpServiceCaller -->
```lua
local Http = game:GetService("HttpService")

local GetOk, GetResult = pcall(Http.GetAsync, Http, "https://api.github.com/zen")
if GetOk then
    -- An empty body is still a successful response.
    print("[Network:Example] GET bytes:", #GetResult)
else
    print("[Network:Example] GET failed:", tostring(GetResult):sub(1, 160))
end

local RequestOk, Result = pcall(Http.RequestAsync, Http, {
    Url = "http://127.0.0.1:7350/", Method = "GET"
})
if not RequestOk then
    print("[Network:Example] Nakama request failed:", tostring(Result):sub(1, 160))
elseif not Result.Success then
    -- A non-2xx status is a normal RequestAsync result, not successful data.
    print("[Network:Example] Nakama HTTP failure:", Result.StatusCode)
else
    print("[Network:Example] Nakama status:", Result.StatusCode, Result.StatusMessage)
end
```

GL-023 removes the old empty-string error fallback. `GetAsync` also raises for
non-2xx; use `RequestAsync` when the caller needs that response's status, body or
headers. No application fallback grants network access. See the
[API and JSON migration contract](../newdocs/httpservice-api.md).

## Roadmap

- **Phase 3** — `NakamaService` (C++ singleton, WebSocket + non-blocking HTTP) exposed to Luau.
- **Phase 4** — route the existing `DataStoreService` to Nakama Storage (server-authoritative,
  with optimistic-concurrency `UpdateAsync`); local-disk fallback stays for offline/single-player.
- **Phase 5** — authoritative world server (Nakama match handlers) + networked `RemoteEvent`s.

Server-side modules (Lua/Go/TS) will live under `backend/modules/` and are mounted into the
container automatically (see the volume in `docker-compose.yml`).

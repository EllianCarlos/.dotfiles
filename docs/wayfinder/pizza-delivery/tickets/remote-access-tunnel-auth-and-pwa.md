---
title: Remote access: Cloudflare Tunnel, Access auth and PWA
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

How the owner reaches pizza-delivery from a phone or another browser: a Cloudflare Tunnel (`cloudflared`) from a hostname to the daemon's `127.0.0.1` HTTP adapter, Cloudflare Access as the mandatory identity layer, and the daemon verifying the Access JWT itself so a misrouted tunnel cannot bypass it. A PWA for the web UI (manifest, service worker, offline shell) with Web Push for the notifications mako gives on the desktop. Open points: who runs and configures `cloudflared` (home-manager module option, secrets handling, tunnel credentials); the Access policy and how the daemon fetches and caches the signing keys; whether job submission, reply, dismiss and cancel are allowed remotely or only reads and replies; Web Push key management and how the daemon sends pushes (a `Notifier` implementation) with click-through to the job page; how the existing local-only default and the unix-socket clients stay unchanged; what the ledger records for remote actors (a new actor identity); how the Cloudscape UI behaves at phone width; threat notes now that the surface is reachable beyond localhost (rate limits, CSRF, origin checks, audit events).

## Resolution

The owner confirmed the core: remote access is allowed for the owner alone, through a Cloudflare Tunnel. The remaining proposals were put to the owner as eight questions and answered with that one confirmation; items marked "proposed" below were not individually confirmed and can be amended.

- **Ownership (proposed)**: tunnel and Access are deployment config in dotfiles. A NixOS module in `nixos/modules/services/` defines `services.cloudflared.tunnels.pizza` (NixOS has `services.cloudflared.tunnels`; a home-manager equivalent was not confirmed). The tunnel credentials file lives at `/etc/cloudflared/pizza.json`, root 0600, out of git, like the AirVPN WireGuard config. Hostname `pizza.elliancarlos.com.br`, assuming that domain is on Cloudflare. pizza-delivery never starts `cloudflared`; it reads a `[remote]` config section (`enable`, Access team domain, `aud` tag, allowed emails, allowed origin).
- **Auth (confirmed in spirit, mechanism proposed)**: Cloudflare Access is the mandatory identity layer. The daemon keeps listening on `127.0.0.1` only. A request carrying Cloudflare headers (`Cf-Ray`, `Cf-Connecting-Ip`) must carry a valid `Cf-Access-Jwt-Assertion` (signature checked against cached team keys refreshed on unknown key id; `aud`, `iss`, expiry and allowlisted email checked) or gets 401. A request without Cloudflare headers is a local client, trusted as today.
- **Permissions (proposed)**: the allowlisted identity may read, reply, dismiss, cancel and submit. Remote submits are rate-limited (default 20 per hour) and `remote.allow_submit` can turn them off.
- **Browser safety (proposed)**: state-changing endpoints require a matching `Origin`, a JSON content type and an `X-Pizza-Client` header; no permissive CORS.
- **Ledger (proposed)**: a remote-human actor kind carrying the Access email and Cf-Ray id; rejected authentications become `auth-rejected` events aggregated per time window.
- **PWA (proposed)**: the daemon serves a manifest, icons and a service worker caching only the app shell; offline shows a stale read-only snapshot; no offline write queue in version one; at phone width the inbox is the landing page and the three job views stay reachable.
- **Web Push (proposed)**: VAPID keys generated on first start (private key in the data directory, mode 0600); subscriptions in an operational table with ledgered subscribe and unsubscribe events; a `WebPushNotifier` implements `Notifier` with the same urgency mapping and coalescing as mako; payloads carry only job id, state and a short title; click opens the job page on the tunnel hostname. iOS needs the PWA installed (16.4 or later).
- **Rollout (proposed)**: off unless `[remote]` is enabled; enabling it with an empty email allowlist or a missing `aud` fails daemon startup. The unix-socket CLI and the TUI are unchanged. Other remote auth methods stay out of scope.

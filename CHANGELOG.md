# Changelog

## v1.1 — 2026-10-03
- Added local AI explanations: each alert gets a plain-English follow-up from an Ollama model (default `hermes3`). Runs in the background so monitoring never waits on the AI.
- Added `--explain "alert text"` test mode.
- New config options: `AI_EXPLAIN`, `OLLAMA_MODEL`.
- Fixed the startup line showing the ntfy topic instead of "on".

## v1.0 — 2026-10-03
- Location tracking (city, country, network owner) via the free Mullvad check.
- Free phone alerts through ntfy.
- Landing page in `docs/` for GitHub Pages.

## v0 — 2026-10-03
- VPN drop, IP leak and route leak alerts.
- Wi-Fi, DNS and offline change detection with a log file.

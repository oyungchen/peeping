# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A macOS shell/Python tool that wraps **Xray-core** (from V2rayU) for one-command proxy control with multi-account support and two routing modes (global/split-tunnel).

## Commands

```bash
./install.sh                 # Deploy scripts to ~/.V2rayU/ and ~/.local/bin/, inject shell wrapper into ~/.zshrc
```

No build step, lint, or test framework. Manual verification:

```bash
curl -x socks5h://127.0.0.1:10808 -s https://httpbin.org/ip
```

## Architecture

The data flow is:

```
accounts.yml  →  gen_config  →  cash_proxy.json  →  xray-core
     ↑              ↑                                  ↑
  (hand-edited)  (Python)                        (proxy.sh starts/stops)
```

- **`proxy.sh`** — main CLI (installed as `~/.local/bin/xrayproxy`). Delegates config generation to `bin/gen_config`, account testing to `bin/test_account`, and xray process management to direct commands. Reads/writes `~/.V2rayU/.current_account` to persist selected account + mode.
- **`bin/gen_config`** — Python 3 script, no external dependencies. Hand-parses YAML (line-by-line, no PyYAML) because accounts use a flat list-of-dicts format. Generates a full Xray JSON config with SOCKS5 inbound on `10808`, HTTP inbound on `10809`, one proxy outbound, one `freedom` (direct) outbound, and routing rules that differ by mode (`global` vs `smart` split-tunnel with explicit rules for Google, GitHub, OpenAI, Anthropic, etc.).
- **`bin/test_account`** — Python 3 script, no external dependencies. Reuses the same hand-rolled YAML parser as `gen_config`. Tests each account via ping (latency + loss), `nc` (TCP reachability), and curl through a temporary xray instance (TTFB + download speed), then computes a 0–100 weighted score.
- **`install.sh`** — copies scripts to `~/.V2rayU/` and `~/.local/bin/`, injects a zsh shell function (`xrayproxy`) that intercepts `shell on|off|status` as function calls and forwards everything else to `~/.local/bin/xrayproxy`. This split exists because `shell on` must set environment variables in the calling shell, which a subprocess cannot do.

## Key constraints

- **macOS only** — uses `networksetup` and hardcoded Wi-Fi interface name (`IFACE=Wi-Fi`).
- **No Python dependencies** — the hand-rolled YAML parser in both Python scripts only handles a flat `- name:` / `key: value` format. Do not introduce PyYAML or any other dependency without updating the install flow.
- **Config is gitignored** — `accounts/accounts.yml`, `*.log`, `cash_proxy*.json`, `.current_account` are never committed.
- **Account schema** is documented in `accounts/accounts.example.yml`. Supported protocols: `vless`, `vmess`, `trojan`, `shadowsocks`. Supported transports: `ws`, `tcp`, `grpc`, `xhttp`. TLS security: `tls`, `reality`, `none`.
- **Hardcoded paths**: xray binary at `/usr/local/v2rayu/bin/xray-core/xray-arm64`, config at `~/.V2rayU/cash_proxy.json`, logs at `~/.V2rayU/xray_cash.log`.
- **Proxy ports**: SOCKS5 on `127.0.0.1:10808`, HTTP on `127.0.0.1:10809`.
- **Default account**: `cash2`, default mode: `global`. These are wired as fallbacks in `proxy.sh`.
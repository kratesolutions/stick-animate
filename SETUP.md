# Stick-Animate — Setup (quick technical reference)

For the friendly, step-by-step walkthrough, open **"Start Here - Setup Guide.html"**.
This file is the short technical version of the same thing.

## 1. Install the skill
Copy the whole `stick-animate` folder into your Claude Code skills folder so you have:
```
C:\Users\<you>\.claude\skills\stick-animate\SKILL.md
```

## 2. Connect Higgsfield (your account, your credits)
Higgsfield is a remote MCP server, connected with a one-time **browser sign-in** (no API key).
This is **Claude Code** (the agent tool at claude.ai/code that runs skills), not the Claude chat app.

- Run once in a terminal:
  ```
  claude mcp add --transport http --scope user higgsfield https://mcp.higgsfield.ai/mcp
  ```
  then `claude mcp login higgsfield` (sign in via the browser), and verify with `claude mcp list`.
- Manual fallback — add this under `"mcpServers"` in `C:\Users\<you>\.claude.json`, then reopen
  Claude Code and sign in with `/mcp` -> higgsfield -> Authenticate:
  ```json
  "higgsfield": { "type": "http", "url": "https://mcp.higgsfield.ai/mcp" }
  ```
- A **Higgsfield Plus** plan is plenty; each finished clip is only a few credits.

## 3. Requirements (Windows)
- **Windows PowerShell** (built in).
- **ffmpeg + ffprobe** on PATH: `winget install Gyan.FFmpeg` (reopen the terminal afterward).

## 4. Brand (preset in brand.json)
Navy `#1A2238` figures, **footless**, generated on a green screen that is keyed out automatically.
Drop the real logo at `assets/motivationeer-logo.png` (used in the guide headers).

## 5. What you get out
Every clip is **16:9** and **figure-only (no background)**:
- a transparent **ProRes `.mov`** (drops straight onto any slide or video), plus
- a small **green-screen `.mp4`** (universal backup you can key in your own editor).

## Use it
In Claude Code, just describe what you want. Examples:
- `make the "breaking chains" clip`
- `a figure climbing to the top and throwing their arms up`
- `animate the angel from sheets/angels.png doing a slow victory jump`

The skill picks the figure, shows you the start frame, renders, keys out the green, and hands you the clips.
There is a built-in library of coaching metaphors (see `recipes.json`), and you can describe anything else too.

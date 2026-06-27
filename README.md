# Motivationeer Stick-Figure Animation Studio

Turn a quick description into a short, on-brand stick-figure animation, right inside Claude Code.
Built for Motivationeer Christian Coaching by Krate Solutions.

## Install (one time)

Clone this repo into your Claude Code skills folder, so the path ends up exactly like:

```
C:\Users\<you>\.claude\skills\stick-animate\SKILL.md
```

In a terminal (PowerShell):

```
git clone <REPO-URL> "$env:USERPROFILE\.claude\skills\stick-animate"
```

Then open **`SETUP.md`** (or the "Start Here - Setup Guide" we sent) and follow it once to connect your
own Higgsfield account. Setup is about ten minutes, one time only.

## Update (whenever Krate ships an improvement)

From the skill folder, pull the latest:

```
cd "$env:USERPROFILE\.claude\skills\stick-animate"
git pull
```

Or just tell Claude Code: **"update my stick-animate skill with git pull."** That's it, you keep every
improvement we make.

## Use it

Open Claude Code and describe what you want, for example *"make the breaking chains clip"* or
*"a figure reaching the top of a climb, arms up."* It renders on your own Higgsfield account and hands
you the finished clip (a green-screen `.mp4` plus a ready-keyed transparent `.mov`).

## Notes

- Runs entirely on your own accounts. There is **no API key or password stored in any file here** —
  Higgsfield connects through a secure one-time browser sign-in.
- Simple clips cost about 50 cents of compute; bigger, more complex scenes cost a bit more and the tool
  gives you an estimate before it runs anything.
- Questions, or want a new style or scene added? Reach out to Krate Solutions.

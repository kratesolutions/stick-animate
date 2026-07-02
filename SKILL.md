---
name: stick-animate
description: >-
  Turn a stick-figure action sheet plus a one-line action into a short (3 to 10 second)
  on-brand, flat-2D animation with Higgsfield. Use when the user wants to animate a stick
  figure, pictogram, or action-sheet pose, for example "animate the angel doing a victory
  jump", "make this figure wave", "turn this sheet into a 5 second clip", or "stickmation".
  It finds and recolors the chosen figure to the brand, then animates it: Seedance 1.5 Pro for simple
  actions and Kling 2.6 for complex/effects scenes (start frame plus a directed prompt), and exports
  16:9 (client default), on a scene or as a transparent cutout. Requires the Higgsfield MCP connected
  and brand.json present (see SETUP.md). Cheap and near one-shot: simple clips about 5 credits.
---

# Stick-Animate

Animate a flat stick-figure pose into a short branded clip. The figure's own artwork
becomes the first video frame, so the output keeps the exact flat 2D style. Engine and
defaults are locked for cheap, near one-shot results.

All scripts live in `./scripts` relative to this skill folder. Run them with
`powershell -ExecutionPolicy Bypass -File <script> ...`. Read `brand.json` (this folder)
first; every default below comes from it.

## Preflight (do this before anything else)
1. Confirm the Higgsfield MCP is connected (tools named `mcp__higgsfield__*`). If not, stop
   and point the user to SETUP.md.
2. Load `brand.json`. Keys: figureColor, backgroundColor, logo, logoCorner, defaultAspect,
   defaultDurationSec, defaultOutput, model (simple), complexModel, premiumModel, fallbackModel,
   complexModelParams, premiumModelParams, resolution, generateAudio, declinedPresetId, costGate, scenes.
3. ffmpeg and ffprobe must be on PATH (SETUP.md covers install).

## Inputs
- A sheet image path (a multi-figure grid OR a single figure), or a figure already prepared.
- One action line, e.g. "does a slow victory jump, arms up".
- Options (any omitted fall back to brand.json):
  - length: 3 to 10 seconds (default `defaultDurationSec`)
  - aspect: LOCKED to `16:9` (client rule 2 below; brand.json `defaultAspect`). Do not offer or
    render 9:16 / 1:1 unless the client explicitly changes the rule.
  - output: `scene` | `transparent` (default `defaultOutput`)
  - scene: a key from brand.json `scenes` (default plain backdrop)

Pick a short kebab `slug` from the action, e.g. `angel-victory-jump`. Work in
`_work/<slug>/`, write finals to `_out/<slug>/`.

## Output rules (client-locked, apply to EVERY clip)
1. NO FEET. Every plate prompt states the figure's legs end in plain rounded stumps, with no feet,
   no shoes, no ground line, and no shadow. (Baked into recipes' `globalImageStyle`.)
2. 16:9 ONLY. Render every clip 16:9. Never 9:16 or 1:1.
3. FIGURE ONLY, NO BACKGROUND. Generate on a SINGLE UNIFORM FLAT PURE GREEN chroma-key background
   (brand.json `chromaColor` #00B140); state in the prompt one even flat green, NO horizon, NO field,
   NO two-tone, NO gradient, edge to edge. (Some models, e.g. seedance, imagine a two-tone "field" green;
   the green-DOMINANCE key removes it cleanly anyway, but a flat source also helps editor-side keying.)
   Then animate (the green stays flat). Then key it out:
   `scripts/chroma_key.ps1 -Video "<greenscreen.mp4>" -Out "<slug>_transparent_16x9.mov"` ->
   a transparent ProRes 4444 .mov that drops onto any slide/video. Deliver BOTH:
   `<slug>_transparent_16x9.mov` (pre-keyed; already SILENT, the key drops the audio) AND
   `<slug>_greenscreen_16x9.mp4`. ALWAYS write the green-screen mp4 with audio STRIPPED:
   `ffmpeg -i "<raw model mp4>" -an -c:v copy "<slug>_greenscreen_16x9.mp4"` (small, universal,
   the client can key it in their own editor). chroma_key uses a GREEN-DOMINANCE key (alpha from how
   much green beats red and blue), so it is robust to the AI green screen being clouded/non-flat and
   needs no per-clip tuning. NEVER use a green accent (it would be keyed out); navy + warm accents
   (red/gold/yellow) survive automatically. (VP9/WebM alpha is unreliable here; ProRes MOV is the safe format.)
   - BACKGROUND ON REQUEST (any clip, not just environmental ones): figure-only is the default, but if the
     user asks for a background (e.g. "on a simple backdrop" or "with a scene"), SKIP the green screen
     entirely: render the figure on the brand backdrop (#D4D9E0) or the named scene and deliver the normal
     mp4 (no key). Generate the plate on that background instead of green and animate it directly.
4. ENVIRONMENTAL clips get a CHOICE. Some metaphors are a scene/world, not just a figure plus props
   (e.g. Light of the World's brightening room, planting's ground, the narrow gate). These are listed in
   recipes.json `environmentalRecipes`. For any such clip, figure-only does not fit cleanly, so ASK the
   user first: (a) figure-only on green (default), or (b) KEEP A BACKGROUND -> bypass the green screen,
   render on the brand backdrop or a scene, and SKIP chroma_key (deliver the normal mp4). Let them decide
   per clip rather than forcing green screen.

## Build complexity, model tier, and cost approval (decide BEFORE generating)
Classify the build, pick the model tier, then decide whether to ask first.

- **SIMPLE** = one figure, one whole-body action (wave, jump, run), no effects, default duration.
  -> `model` (Seedance 1.5 Pro, ~5cr). Just run it, no approval needed.
- **LIBRARY RECIPE** = any recipes.json metaphor run as written. These are pre-validated multi-beat
  builds and run on their own listed model (`kling2_6`, 5s, `sound:"off"`, ~5cr, 1080p). Preflight
  `get_cost`, STATE the cost, and run - no approval wait needed at the listed model/duration/rolls.
- **COMPLEX** = any of: 2+ figures/interaction, an effect (fire, smoke, explosion), a small fast object
  or projectile (a kicked or thrown ball), a precise payoff, or 8s+. -> `complexModel` (Kling 2.6,
  ~5cr, 1080p), pass `complexModelParams` (sound:"off"). **Seedance CANNOT animate a struck or launched
  ball (it vanishes or explodes at the figure); Kling 2.6 and Veo can. Always route any strike / launch
  / projectile physics to complexModel or premiumModel.**
- **PREMIUM** = a complex clip that needs the absolute cleanest result. -> `premiumModel` (Veo 3.1 full,
  ~22cr), pass `premiumModelParams` (quality:"high", variant). Escalation only, and always gated.

**Cost-approval gate.** Before spending on any NOVEL COMPLEX build, anything PREMIUM, any run whose
TOTAL planned spend (including `count:2`/rolls) >= `costGate.thresholdCredits`, any 8s+ render, or any
batch: preflight with `get_cost:true`, then tell the user the credit total AND the dollar figure on
their plan (Starter ~$0.074/cr), warn that physics-heavy gags may need rerolls (more credits) and might
not one-shot, and WAIT for explicit approval before generating. SIMPLE clips and LIBRARY RECIPES under
the threshold just run (still state the preflighted cost). Never burn `count:2` on the premium model
without approval.

## Pipeline

### 1. Pick the figure
Run:
```
scripts/segment_sheet.ps1 -Sheet "<sheet>" -Out "_work/<slug>" -FigureColor <figureColor> -BgColor <backgroundColor>
```
It writes `normalized.png` (transparent, figures opaque), `figures.json`
(`[{index,x,y,w,h}, ...]` in sheet pixels), and `figures_grid.png` (numbered picker).
- If 1 figure: use it.
- If several: show `figures_grid.png`, ask which index, or match the user's words
  ("the angel" -> the winged figure). Read the chosen `x,y,w,h` from `figures.json`.

### 2. Build the brand start frame (free, no credits)
```
scripts/prep_plate.ps1 -Norm "_work/<slug>/normalized.png" -Bbox "x,y,w,h" `
  -Out "_work/<slug>/start.png" -FigureColor <figureColor> -BgColor <backgroundColor> `
  -Aspect <aspect> -Scene "<scenePath or none>"
```
For output=scene with a named scene, pass the scene's path from brand.json `scenes`; else
`none` (flat brand backdrop). Show `start.png` to the user as a sanity check before spending
any credits.

### 3. Decide the motion (smart auto)
Read the action line and classify:
- SIMPLE (wave, nod, wing flap, bounce, float, breathe, gentle step, look around):
  start frame plus prompt only. This is the default and the cheapest. No end pose.
- BIG pose change (jump, kick, run, throw, fall, spin, raise both arms, lunge):
  also make an end pose so the motion stays on-model:
  ```
  generate_image  model: nano_banana_2
    medias: [{role:"image", value:<start media_id from step 4>}]
    prompt: "Exact same flat 2D minimalist navy stick figure on the exact same plain pale
             grey background, redrawn in this pose: <END POSE>. Identical color, identical
             line weight, flat vector, no shading, no 3D."
  ```
  Poll the image job (see step 5 polling) and keep its job id as the end image.
  When unsure, treat it as SIMPLE (one shot).

### 4. Upload the start frame
```
media_upload   { filename:"start.png", content_type:"image/png" }   -> uploads[0].upload_url, media_id
scripts/hf_put.ps1 -Url "<upload_url>" -File "_work/<slug>/start.png" -ContentType "image/png"
media_confirm  { type:"image", media_id:"<media_id>" }
```
The confirmed `media_id` is the start image. (For a BIG move, do step 3 now using this media_id.)

### 5. Generate
```
generate_video
  model: <model tier>            (SIMPLE -> model = seedance1_5; COMPLEX -> complexModel = kling2_6; PREMIUM -> premiumModel = veo3_1; see the tier section above)
  resolution: <resolution>       (brand.json, default 720p; kling2_6 renders 1080p)
  aspect_ratio: <aspect>         (generate natively in the requested aspect -> no letterbox)
  duration: per the model        (seedance1_5: 4/8/12; kling2_6: 5/10; veo3_1: 4/6/8; from defaultDurationSec, round to the model's nearest)
  + model params                 (kling2_6: sound:"off"; veo3_1: quality+variant from premiumModelParams)
  generate_audio: false           (seedance + veo; KLING IGNORES this, it silences via sound:"off" above.
                                   CAUTION: veo3_1 FULL may ignore it too - only veo3_1_lite documents the
                                   param - so the ffmpeg -an strip below is the only guarantee on premium)
  declined_preset_id: <declinedPresetId from brand.json>
  prompt: <guardrail template, below, wrapped around the action line>
  medias: [{role:"start_image", value:<start media_id>}]
          (+ {role:"end_image", value:<end image job id>} only for a BIG move)
```
- **ALWAYS SILENT (client rule).** These models generate native audio BY DEFAULT, and they only obey the
  silence PARAMETER, never a prompt or a chat request. Saying "no audio" in the prompt or in chat does
  NOTHING. So enforce silence two ways, every time: (1) pass the model's own off-flag on the call
  (`generate_audio:false` for seedance/veo, `sound:"off"` for kling), AND (2) strip audio from every
  delivered mp4 with `ffmpeg -i in.mp4 -an -c:v copy out.mp4` (the green-screen mp4 and any background/
  scene mp4; the transparent .mov is already silent from the key). Clips are silent by design; the user
  adds their own music in an editor.
- If the response is a `preset_recommendation` notice instead of a job, retry the SAME call
  adding `declined_preset_id` set to the notice's `data.preset.id`.
- Poll: `job_status { jobId:<id>, sync:true }` until `status` is `completed`. The MP4 is
  `results.rawUrl`. (Same polling for the step-3 image job.)
- If `status` is `nsfw` or `failed` (auto-refunded), reword the action and retry once. If it
  still fails, switch `model` to `fallbackModel` (seedance_2_0), same params, and retry.

### 6. Finish and export
Scene output (default):
```
scripts/finish.ps1 -Video "<rawUrl>" -Out "_out/<slug>" -Slug "<slug>" `
  -Aspects "<comma list of any EXTRA aspects you also want>" -BgColor <backgroundColor> `
  -Logo "<logo path or none>" -LogoCorner <logoCorner> [-TrimSec <exact seconds, optional>]
```
- CLIENT RULE: 16:9 only, so leave `-Aspects` EMPTY (the machinery exists for other brands; do not
  derive 9:16/1:1 for this client unless the rule is explicitly changed).
- Logo: pass brand.json `logo` if the file exists, else `none`.
- TrimSec: only when the user wants an exact length different from 4/8/12.

Transparent output:
```
remove_background { params:{ media_id:"<video job id>", media_type:"video" } }
```
Poll, then deliver that result (it carries alpha). Skip the pad/logo finish for transparent
unless the user wants a logo burned in.

QA: `scripts/qa_montage.ps1 -Video "<a final mp4>" -Out "_out/<slug>/qa.png"` and show it.

## Interaction scenes (two or more figures) and exact durations
- TWO+ figures (a face-off, a handshake, a fight): build the plate with
  `scripts/compose_scene.ps1 -Norm "<normalized.png>" -Boxes "x,y,w,h|x,y,w,h" -Out "<start.png>"
  [-Flip "0|1"] -Aspect <aspect> -HeightFrac 0.55`. Take the boxes from figures.json; use -Flip
  to mirror a figure so two face each other. Then continue from step 4 (upload + generate).
- Extra-dynamic motion (fights, big effects like fire, a struck or flying ball): use `complexModel`
  (kling2_6, ~5cr, 1080p, durations 5/10) instead of the simple model. Pass `sound:"off"` and the same
  `declined_preset_id`; keep the flat-2D guardrails in the prompt. For the absolute cleanest physics,
  escalate to `premiumModel` (veo3_1, quality high) behind the cost gate. The angel-vs-devil
  flaming-goal clip in `_out/angel-devil-goal` was built this way (an angel+devil source plate, then a
  directed prompt): Seedance fumbled the ball-kick every take, while Kling 2.6 and Veo nailed the
  struck, flaming, flying ball.
- NO SHEET for the subject (the client has no matching sheet): generate the figures or the whole
  scene first with `generate_image` (nano_banana_2) in the brand style ("flat 2D pictogram, solid
  navy #1A2238 figures and shapes on #D4D9E0, crisp flat edges, no shading, no 3D, no text"), then
  animate that image (its job id works directly as start_image). The soccer clip in `_out/soccer-goal`
  was made this way (generated player + ball + goal + goalie scene).
- PIN A PRECISE PAYOFF (a specific ending or gag the model keeps fumbling): build an explicit END
  frame of the final state with `generate_image` (pass the start as a reference image so the scene
  matches), then run the `complexModel` (kling2_6) with BOTH start_image and end_image so it must
  resolve to that ending. The soccer "headless goalie, head in the net" payoff was locked this way.
  Note: in a one-color pictogram a detached head and a ball are both navy circles, so sell such gags
  through the BODY (e.g. a clearly headless figure), not the loose circle.

## Guardrail prompt template
Wrap the user's action line exactly like this so the look stays flat and on-model:
> Flat 2D minimalist motion-graphics animation. The dark navy stick figure <ACTION>. Fast-paced,
> snappy, no slow motion. Smooth clean flat vector style. Keep the background exactly as in the start
> frame, perfectly flat and unchanged (green-screen clips: a SINGLE UNIFORM FLAT chroma green, no
> horizon, no field, no two-tone, no gradient, edge to edge). Crisp flat edges, no shading,
> no gradients, no 3D, no texture, no film grain, no camera movement.

## Power features

### Coaching metaphor library (recipes.json)
`recipes.json` holds ready-made visual metaphors for a teaching point (letting go, the climb,
breaking chains, the lightbulb moment, the narrow gate, light of the world, and more), each with a
scripture hook, accent color, model, aspect, duration, an auto-judge `beats` checklist, and a
`rolls` hint. All recipes run on `kling2_6` (5s, 1080p, ~5cr) - ALWAYS pass `sound:"off"` (Kling
generates audio by default; client rule is silent) and strip the delivered mp4 with `-an` as usual.
To run one: read the recipe, generate the start plate with `scenePrompt` + `globalImageStyle`
(nano_banana_2), then animate with `motionPrompt` + `globalMotionStyle` on the recipe's `model`,
following the single-start recipe. A recipe run as written is pre-validated: state the preflighted
cost and run (see the LIBRARY RECIPE tier). If the user names a theme ("make a 'breaking chains'
clip", or "I'm teaching on letting go this week"), match it to a recipe. Use the recipe's `accent`
as the only non-navy color (warm only, never green). Add new recipes by appending to the file.

### Auto-judge (reliable one-shot)
Never ship the first render blind. After generating:
1. From the request (or the recipe `beats`), write a short checklist of the key beats that must be
   visible (e.g. "ball enters net", "head detaches", "balloon pops", "figure ends flat").
2. Build a frame strip with `scripts/qa_montage.ps1` (or a denser grid) and actually LOOK at it.
3. Score it: are all beats present, on-model, flat-style, and did any small/fast object vanish?
4. For a precise or small-object gag, render `rolls: 2` (generate_video `count:2`) and pick the take
   that hits the most beats. Whole-body actions usually pass in one roll.
5. If no take passes, reroll once with a sharper prompt (name the missing beat, add "fast/snappy"),
   then pick the best. Trim any static tail with `finish -TrimSec`.
This is variance selection; it keeps results reliable without the user ever seeing a bad take.

### Consistent character (mascot)
To keep the SAME figure across a client's clips, pass `brand.json.character` (a saved mascot image)
as a reference when generating scenes/figures: `generate_image` with
`medias:[{role:"image", value:<mascot media_id>}]` plus "match this exact character and style."
Register or replace the mascot by saving a clean figure to `assets/character/mascot.*` (generate one,
or pick a figure from a sheet via segment_sheet).

### Polish
- Caption: `scripts/caption.ps1 -Video <in> -Out <out> -Text "..." [-Position bottom|top]` burns a
  branded navy caption bar. Use `-Position top` when the subject sits low in frame. Off by default.
- Aspect ratios: this client is LOCKED to 16:9 (rule 2) - no secondary aspects. (For other brands the
  machinery supports them: generate the primary natively, prefer a native re-render over padding.)
- Resolution: for projector/slide crispness, optionally upscale the final via Higgsfield
  `upscale_video` (media_id = the video job id, to 1080p/2K) before `finish`. Costs a few credits.

## Cost and guardrails
- Per-clip credits (720p silent, ~5s): SIMPLE on Seedance 1.5 Pro ~5cr (~37 cents Starter); COMPLEX on
  Kling 2.6 ~5cr (1080p); PREMIUM on Veo 3.1 full ~22cr (~$1.63). Add ~1.5cr for the nano plate, and
  double for `count:2`. Always `get_cost:true` to quote before rendering.
- Run the cost-approval gate (see "Build complexity, model tier, and cost approval") before any
  COMPLEX / PREMIUM / count:2 / 8s+ spend.
- Keep clips short and silent (generate_audio:false). The user adds music in their editor.
- If a request implies many clips (a whole sheet, a batch), confirm the credit total first.

## Output conventions
- Finals: `_out/<slug>/<slug>_16x9...` (e.g. `angel-victory-jump_greenscreen_16x9.mp4` +
  `angel-victory-jump_transparent_16x9.mov`). Always 16:9 (client rule), always silent.
- Always show the start frame before generating, and the QA sheet after.

## Troubleshooting
- "unknown model" error: Higgsfield retired or renamed the model (this is how seedance_1_5 went away).
  Run `models_explore(action:'recommend')` with the goal, pick the current equivalent, and update brand.json.
- Preset notice instead of a job: add `declined_preset_id` and retry (step 5).
- Figure renders black, not navy: check `figureColor` in brand.json (default #1A2238).
- Wrong figure picked from a grid: re-run with the correct index from `figures_grid.png`.
- A pose drifts off-model on a big move: make sure you supplied an `end_image` (step 3),
  shorten to 4s, or switch to `fallbackModel`.
- Slow / floaty action, a late or mistimed move, or a small fast object (e.g. a ball) vanishing:
  you probably used start_image + end_image, which MORPHS between the two stills (slow, back-loaded,
  late action, and it drops objects not present in the end frame). For fast physics/action use a
  SINGLE start_image + a directive prompt with pace words ("fast-paced, snappy, no slow motion") and
  let the model choreograph. Reserve end_image for when a precise STATIC ending matters more than
  pace. If the action finishes before the clip ends, trim the static tail with `finish -TrimSec`.
- A struck or launched ball (kick / throw / projectile) that vanishes, explodes at the figure, or
  never flies: this is the hardest beat and SEEDANCE CANNOT DO IT. Switch to `complexModel` (kling2_6)
  or `premiumModel` (veo3_1), keep the strike and the ignition as SEPARATE beats ("strikes the ball
  cleanly; the ball shoots off and THEN ignites, flame trailing behind the flying ball only, no fire
  at the figure"), and run count:2 + judge.
- A subject has no sheet and the generated source has flaws (broken net, tiny ball): regenerate the
  scene with explicit cleanup cues ("neat evenly-spaced connected grid", "large clearly visible
  ball") and `count:2` to pick the cleanest.
- Background not perfectly flat in a secondary aspect: generate that aspect natively instead
  of deriving it, or use transparent output.

# UX polish pass — game feel, visual design, sound

You are the **UX lead** on RogueChess, a chess roguelike deckbuilder MVP built in Godot 4.7 / GDScript at `/Users/franciscoaraujo/GIT/godot/rogue-chess`. The game is feature-complete and fully playable. Your job is to make it **feel, look and sound excellent** — the kind of build you'd proudly put in front of playtesters — without changing any game rule.

You are a project manager, not the main implementer. Plan, spawn subagents for each area, review their work with fresh eyes, and **loop until every item in the Exit criteria passes**. Only then report back. Don't stop to ask questions: decide, record the decision in `docs/UX_DECISIONS.md`, and keep going.

## Read first
- `docs/SPEC.md` (what the game is), `docs/DECISIONS.md` (rules as built, binding), `docs/API.md` (ChessMatch / RunSession / MatchAI — the only logic the UI calls), `README.md` (commands).
- `docs/screenshots/*.png` — the current look of every screen. Look at all of them before planning.
- The UI code: `scripts/ui/` (`main.gd` screen manager, `game.gd` autoload, `ui.gd` shared builders/effects, `theme/` palette, fonts and Theme, `widgets/` board, pieces, cards, map, HUD, `screens/` one script per screen, `match/` pure helpers) and `scenes/`.
- Skills, if available: `interface-design:interface-design` (and `:critique`, `:audit`), `gdscript-kiss:gdscript-kiss`, `godot-code-review:godot-code-review`. Use them and tell your subagents to.

## Current state (so you don't rediscover it)
- Art direction already chosen: "club room at night" — walnut surfaces, ivory text, one brass accent, oxblood for the opponent and captures, ember for Fire, steel for shields. Georgia headings, sans body, Avenir Next/Helvetica numerals. Pieces are drawn discs with Apple Symbols chess glyphs (letter fallback). Keep this direction unless you have a strong reason to change it; refine it, don't restart it.
- Feedback exists but is basic: short tweens, pops, floating "+N", shake, a match log, toasts.
- **There is no audio at all.**
- 1280×720 base window, `canvas_items` stretch.

## Goals
1. **Game feel ("juice")** — every action feels responsive and satisfying, yet readable and never slow: card hover/lift/drag-to-play, piece pick-up/move/land with weight, capture impact, shield block, explosion, Fire ignite/burn/burn-out, promotion, check + escape, score-race progress, energy spend/refill, draw/shuffle/discard, turn handoff, match victory/defeat, reward/shop/coaching purchases, map travel, unlocks. Clear cause → effect, consistent timing curves, anticipation and follow-through, hit-stop used sparingly. Opponent turns stay easy to follow. A setting for animation speed (incl. a fast mode) is welcome.
2. **Visual design** — coherent, intentional, polished: hierarchy, spacing rhythm, typography scale, contrast (WCAG AA for text), iconography, board and piece readability at a glance (both sides, piece types, upgrades, shields, burn timers, check, holes), card design, map, panels, transitions between screens, empty/disabled/hover/pressed/focus states, a title screen with presence. Colour-blind safe: never rely on red vs green alone. No overlaps, clipping or layout jumps at 1280×720 **and** at 1920×1080.
3. **Sound design** — a complete, cohesive soundscape: UI (hover, click, confirm, cancel, error, purchase), cards (draw, shuffle, play, discard), pieces (pick up, move, land per weight class, capture, shield block, explosion, ignite/burn/burn-out, promotion, check, escape), score/energy ticks, turn start for each side, victory/defeat stingers, map/screen transitions, unlock fanfare, and quiet ambient music or ambience for menus/map vs matches. Mixed so nothing is harsh or repetitive (pitch/volume variation, limits on simultaneous voices). Audio bus layout (Master/Music/SFX/UI), a settings panel with volume sliders and mute, settings persisted to `user://settings.json`.
   - **Assets must be original and offline.** Do not download anything. Synthesize sounds procedurally — e.g. a script under `tools/audio/` that generates `.wav` files (Python standard library or GDScript `AudioStreamWAV`), committed under `assets/audio/` — or generate them at runtime. Music can be a simple generated loop. Keep generation scripts so sounds can be regenerated and tuned.
4. **Accessibility & comfort** — keyboard shortcuts for common actions (End turn, Redraw, cancel, select card 1–5), visible focus, reduced-motion option (disables shake/flash), readable minimum font size, tooltips everywhere a rule matters.

## Hard constraints
- **No game-rule changes.** Don't edit `scripts/core/**` or `config/*.json` gameplay values. UI legality always comes from ChessMatch/RunSession. If you find a logic bug, write it up in your report; don't patch core.
- New tunables (animation timings, volumes, colours) go in a config file (e.g. `config/ux.json`) or the existing theme scripts — not scattered literals.
- KISS: small scripts, reuse `ui.gd` helpers, one audio autoload (e.g. `Sfx`) with a tiny API like `Sfx.play("capture")`. No plugins or downloads.
- Never touch the player's real `user://meta.json` in tests or tools.
- Don't break existing input guards (double-press, opponent-turn lockout, escape prompt) or public handler names used by `tests/integration/ui_helpers/ui_driver.gd`.
- Don't commit; leave changes in the working tree.

## Team (spawn these as subagents; run independent work in parallel)
Give each a focused brief: the relevant goals above, the files it owns, acceptance criteria, and the commands below. Avoid two agents editing the same file at the same time.
1. **Visual designer** — theme, palette, typography, panels, cards, board, pieces, icons, map, title, transitions, 1920×1080 layout. Owns `scripts/ui/theme/**`, `scripts/ui/widgets/**`, screen layout code.
2. **Game-feel / animation engineer** — every action's motion and timing, hit-stop, anticipation, animation-speed + reduced-motion settings. Coordinates with the visual designer on shared widgets (sequence them, or split files clearly).
3. **Sound designer** — audio generator tools, assets, `Sfx`/music autoload, bus layout, mixing, hooks into every event, settings panel + persistence.
4. **Accessibility & input** — shortcuts, focus, tooltips, colour-blind check, minimum sizes, settings UI integration.
5. **QA / test engineer** — keeps `tests/` green, adds tests for new pure helpers and settings persistence, extends the screenshot tool to new states (settings panel, 1920×1080 shots), and runs the full verification below.
6. **Independent critic** — a fresh subagent every iteration that did NOT build anything. It reviews all screenshots, reads the event→feedback→sound mapping, and scores the rubric below. It also runs `godot-code-review` on the changed code. Its scores decide whether you loop.

## Verification (every iteration)
```
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --import
$GODOT --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json      # must stay 100% green
$GODOT --headless -s tools/sim/run_sim.gd -- --runs=100 --seed=1                   # must PASS (logic untouched)
$GODOT --path . res://tools/screenshots/take_screenshots.tscn                      # regenerate every screen
```
(No `timeout` command on this Mac; run long jobs in the background.) Look at every screenshot yourself with the Read tool. Because screenshots can't show motion or sound, also produce `docs/ux/feedback_map.md`: a table of every game event → visual feedback → animation timing → sound, and have the critic check it for gaps. Where possible, capture short frame sequences (e.g. 6–8 PNGs across a capture or explosion) to judge motion.

## Rubric (critic scores each 1–5, with evidence)
For each screen (title, set select, artifact select, map, roster, match — normal / opponent turn / escape prompt / match over, reward, shop, coaching, deck & collection views, run end, settings):
- **Clarity**: you can tell what to do next and what just happened within 2 seconds.
- **Visual polish**: hierarchy, spacing, alignment, contrast, consistency; no clipping/overlap at 1280×720 and 1920×1080.
- **Feel**: responsive (<100 ms visual response to input), satisfying, consistent timing, never sluggish.
- **Sound**: present for every meaningful event, cohesive, well-mixed, not annoying after 30 minutes.
- **Accessibility**: readable, colour-blind safe, keyboard usable, reduced-motion respected.
Plus whole-game scores for **cohesion** (does it feel like one product?) and **delight** (would a playtester smile?).

## Exit criteria — loop until ALL pass
1. Critic scores every rubric line **≥ 4.5 / 5**, and no single item below 4, with written evidence — two consecutive critic passes (fresh critic each time) agree.
2. Full GUT suite green twice in a row; 100-run sim PASS; screenshot tool runs without errors.
3. Every event in `feedback_map.md` has visual feedback and a sound; no known UX bug left open.
4. Settings (volumes, mute, animation speed, reduced motion) work and persist across restarts (tested).
5. No game rule or core file changed (`git diff --stat scripts/core config` shows only the new `config/ux.json`, if any).
6. Performance: no frame hitches on the match screen during animations (keep per-frame work light; no blocking loads mid-match).

If an iteration doesn't improve the scores, change approach (different subagent brief, narrower scope, or a design critique pass) rather than repeating. Cap at 8 iterations; if you hit the cap, report honestly what's still below the bar and why.

## Final report (only when the exit criteria pass)
- Summary of what changed in feel, look and sound, with before/after screenshot references.
- The final rubric table with scores and the critic's evidence.
- `docs/UX_DECISIONS.md` list (every taste call you made).
- How to run, how to regenerate the sounds, and where the settings live.
- Test, sim and screenshot results; known limitations.

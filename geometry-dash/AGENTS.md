# Geometry Dash — Project Guide

## Architecture
Single HTML file (`index.html`). All game logic is in `<script>` at the top of the file (~300 lines).
**Line 42 contains a large base64 image blob — never edit that line manually.** Use `rebuild.py` to regenerate it from a source image.

## Canvas
- Resolution: 900 × 500 (game-space pixels, never change these)
- Responsive display via CSS scale in `resize()` — logical coords stay fixed
- Context: `canvas.getContext('2d')`, stored as `ctx`

## Physics Constants
| Constant | Value | Notes |
|---|---|---|
| `GRAVITY` | 0.55 | px/frame² |
| `JUMP_VY` | -13.5 | negative = up; second jump subtracts 1.5 more |
| `GROUND_Y` | H - 90 | bottom of playable area |
| `PW / PH` | 44 / 44 | player hitbox size |
| `PX` | 160 | player fixed X position |

## Visual Style
- Background hue: `bgHue` cycles 0→360 at +0.08/frame
- Obstacles and glow use complementary hue: `bgHue + 180`
- Neon glow applied via `ctx.shadowBlur` — reset to 0 after each draw call or it bleeds
- Player trail uses 5 trailing rects with decreasing alpha

## Game Feel Systems
- **Squash/stretch**: `scaleX`/`scaleY` — set on jump (0.72/1.35) and land (1.35/0.72), lerp to 1 each frame at rate 0.18
- **Screen shake**: `shakeFrames`/`shakeAmt` — set in `spawnDeath()`, applied in `loop()` via `ctx.translate`
- **Coyote time**: `coyoteFrames=6` on landing — allows first jump for 6 frames after leaving edge
- **Input buffer**: `jumpBuffer=10` on press — executes jump up to 10 frames after input

## Score & Persistence
- Score = `Math.floor(frame / 7)` ≈ 100 pts/sec at start
- Best score persisted in `localStorage` key `gd_best`
- Milestones at 50, 100, 200, 500, 1000 trigger a gold flash

## Obstacle Patterns
7 patterns in `PATTERNS[]`. Difficulty unlocks higher-index patterns at score/80 intervals (max index = 6 at score 480+).

## Build
```
python rebuild.py   # re-embeds hero image from source HEIC file
```

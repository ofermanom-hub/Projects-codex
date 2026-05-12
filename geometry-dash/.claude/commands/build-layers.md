# Skill: Modular Build Workflow

You are a senior game developer who builds games in strict layers. Never build everything at once. Each layer must be complete and verified before moving to the next.

## The Three Layers

### Layer 1 — Core Scene (Mechanics First)
Goal: Working physics and input. No visuals beyond colored rectangles.

Deliverables:
- Player `CharacterBody2D` with gravity, jump, auto-run
- Ground `StaticBody2D`
- Collision detection (player dies on obstacle touch)
- Input: jump on Space/click/touch
- Score counter incrementing with distance

Acceptance criteria: *You can play and die. Nothing else matters yet.*

Do NOT add at this stage:
- Particles, trails, shaders
- Menus or overlays (just restart on R)
- Sound
- Obstacle variety (one spike type only)

---

### Layer 2 — Visual Polish
Goal: The game looks intentional. Apply `/visual-pipeline` before this layer.

Deliverables (in order):
1. **Background** — parallax layers with grid shader, hue cycling
2. **Ground line** — glowing neon line with `shadowBlur` / `Light2D`
3. **Obstacle materials** — PBR shader with emissive glow
4. **Player sprite** — custom shader with outline + inner glow
5. **Post-processing** — bloom, tone mapping, color grade (see `/visual-pipeline`)
6. **Camera** — smooth follow with slight lag, no hard snapping

Acceptance criteria: *A screenshot could be posted and look intentional.*

Do NOT add at this stage:
- Juice / screen shake / particles (that's Layer 3)
- Multiple obstacle types
- Audio

---

### Layer 3 — Juice & Polish
Goal: Every action has feedback. Consult `/game-juice` for all code in this layer.

Deliverables (in order):
1. **Jump feel** — squash/stretch, trail, jump particles
2. **Landing** — dust particles, squash
3. **Death** — screen shake (trauma system), explosion particles, shockwave ring, DOF blur
4. **Obstacle approach** — subtle pulse/throb on obstacles as they enter screen
5. **Score milestones** — gold flash at 50, 100, 200, 500
6. **Speed ramp** — background hue shift accelerates with speed
7. **Audio** — jump SFX, death SFX, background music loop

Acceptance criteria: *Every action feels satisfying. Removing any effect would be noticeable.*

---

## The Iteration Loop (Layer 2 and 3)

After each deliverable, run this exact feedback loop:

```
1. Build/run the change
2. Observe: what looks or feels wrong?
3. Report back with specifics:
   "Here is the result:
    - Glow is too intense on spikes, washing out the shape
    - Player trail disappears too fast
    Improve ONLY these two things."
4. Claude fixes only what was reported
5. Repeat
```

Rules:
- Never ask Claude to fix more than 3 things per iteration
- Never skip the "run it" step — issues compound if you don't catch them early
- Keep feedback visual and specific: "too bright", "too stiff", "feels laggy" is enough

---

## Art Director Mode
When Layer 2 is 80% done, switch to `/art-director` for a full scene review.

---

## Task Tracking Template
Use this to stay focused during each session:

```
Current layer: [1 / 2 / 3]
Current deliverable: [name]
Status: [not started / in progress / done / needs iteration]
Blockers: [any issues]
Next: [next deliverable]
```

---

## What This Prevents
- Building beautiful visuals on broken physics (Layer 1 must come first)
- Adding juice before the core loop is fun (Layer 3 can't save bad Layer 1)
- Scope creep mid-layer (each layer has a hard stop list)
- Claude rewriting working systems when fixing unrelated things (scoped requests only)

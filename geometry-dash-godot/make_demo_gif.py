#!/usr/bin/env python3
"""Render a demo GIF of the Geometry Dash Godot clone."""

from PIL import Image, ImageDraw, ImageFont
import math, random

# ── Game constants (original scale) ──────────────────────────────────────────
SW, SH       = 1280, 720
GROUND_Y     = 670
CEILING_Y    = 80
PLAYER_X     = 200
PW, PH       = 52.0, 52.0
GRAVITY      = 2800.0
JUMP_VEL     = -960.0
BASE_SPEED   = 480.0
OBS_SCALE    = 4.0
MAX_JUMPS    = 3

# ── Output settings ───────────────────────────────────────────────────────────
SCALE        = 0.55          # render at this fraction of game resolution
GW           = int(SW * SCALE)
GH           = int(SH * SCALE)
GIF_FPS      = 30
SIM_FPS      = 120           # internal sim rate for accuracy
SIM_PER_GIF  = SIM_FPS // GIF_FPS
SIM_DT       = 1.0 / SIM_FPS
TOTAL_SEC    = 9.0

ASSETS       = "/Users/ofer/Projects/geometry-dash-godot/assets"
OUT_PATH     = "/Users/ofer/Projects/geometry-dash-godot/demo.gif"

def s(v):  return v * SCALE
def si(v): return int(v * SCALE)

# ── Load cat sprites ──────────────────────────────────────────────────────────
cw, ch = si(PW), si(PH)
def load_cat(name):
    img = Image.open(f"{ASSETS}/{name}.png").convert("RGBA")
    return img.resize((cw, ch), Image.LANCZOS)

CATS = {k: load_cat(f"cat_{k}") for k in ['idle','jump','doublejump','land']}

# ── Star field (static seed) ──────────────────────────────────────────────────
rng = random.Random(7)
STARS = [(rng.randint(0, GW), rng.randint(0, si(CEILING_Y + 40)),
          rng.randint(si(CEILING_Y + 40), si(GROUND_Y) - 20),
          rng.randint(1, 3), rng.random()) for _ in range(120)]

# ── Draw helpers ──────────────────────────────────────────────────────────────
def clamp8(v): return max(0, min(255, int(v)))
def hdr(r, g, b, a=255):
    return (clamp8(r*55), clamp8(g*55), clamp8(b*55), clamp8(a))

def draw_background(draw, t, bg_hue):
    h = bg_hue % 1.0
    # Sky gradient — dark with hue tint
    for y in range(GH):
        frac = y / GH
        base_r = 4 + int(6  * math.sin(h * 6.28))
        base_g = 2 + int(4  * math.sin(h * 6.28 + 2))
        base_b = 18 + int(14 * math.sin(h * 6.28 + 4))
        r = clamp8(base_r + frac * 8)
        g = clamp8(base_g + frac * 4)
        b = clamp8(base_b + frac * 20)
        draw.line([(0, y), (GW, y)], fill=(r, g, b))

    # Stars (two-layer: ceiling band + mid-sky)
    for sx, sy_top, sy_mid, sr, phase in STARS:
        if sy_top < si(CEILING_Y):
            sy = sy_top
        else:
            sy = sy_mid
        br = clamp8(140 + 115 * math.sin(t * 2.5 + phase * 6.28))
        a  = clamp8(br * 0.7)
        draw.ellipse([sx-sr, sy-sr, sx+sr, sy+sr], fill=(br, br, br, a))

    # Ground platform
    gy = si(GROUND_Y)
    for i, (col, w) in enumerate([
        ((20, 60, 80, 120), 18),
        ((40, 180, 255, 200), 5),
        ((120, 240, 255, 255), 2),
    ]):
        draw.line([(0, gy + i*2), (GW, gy + i*2)], fill=col, width=w)

    # Neon floor grid lines (perspective)
    pulse = 0.4 + 0.2 * math.sin(t * 3)
    grid_col = (clamp8(20*pulse), clamp8(120*pulse), clamp8(180*pulse), clamp8(120*pulse))
    for gx in range(0, GW, si(120)):
        draw.line([(gx, gy), (gx, GH)], fill=grid_col, width=1)

def draw_spike(draw, ox, ow, oh):
    gy = si(GROUND_Y)
    ox_i, ow_i, oh_i = si(ox), si(ow), si(oh)
    # Danger aura
    draw.polygon([
        (ox_i - si(8), gy),
        (ox_i + ow_i//2, gy - oh_i - si(14)),
        (ox_i + ow_i + si(8), gy),
    ], fill=(180, 20, 20, 70))
    # Sub-spikes
    draw.polygon([
        (ox_i, gy),
        (ox_i + ow_i//5, gy - int(oh_i*0.55)),
        (ox_i + ow_i*2//7, gy),
    ], fill=(160, 10, 15, 200))
    draw.polygon([
        (ox_i + ow_i*5//7, gy),
        (ox_i + ow_i*4//5, gy - int(oh_i*0.55)),
        (ox_i + ow_i, gy),
    ], fill=(160, 10, 15, 200))
    # Main body
    draw.polygon([
        (ox_i, gy),
        (ox_i + ow_i//2, gy - oh_i),
        (ox_i + ow_i, gy),
    ], fill=(220, 35, 45, 240))
    # Neon outline
    draw.line([
        (ox_i, gy), (ox_i + ow_i//2, gy - oh_i),
        (ox_i + ow_i, gy), (ox_i, gy),
    ], fill=(255, 80, 90, 255), width=2)
    # Tip glow
    tx, ty = ox_i + ow_i//2, gy - oh_i
    r = max(3, oh_i//9)
    draw.ellipse([tx-r*2, ty-r*2, tx+r*2, ty+r*2], fill=(255, 120, 130, 90))
    draw.ellipse([tx-r, ty-r, tx+r, ty+r], fill=(255, 220, 220, 230))

def draw_block(draw, ox, ow, oh):
    gy = si(GROUND_Y)
    ox_i, ow_i, oh_i = si(ox), si(ow), si(oh)
    # Body
    draw.rectangle([ox_i, gy - oh_i, ox_i + ow_i, gy], fill=(70, 15, 110, 240))
    # Grid lines
    for i in range(1, 4):
        gx2 = ox_i + ow_i * i // 4
        draw.line([(gx2, gy - oh_i), (gx2, gy)], fill=(0, 0, 0, 70), width=1)
    draw.line([(ox_i, gy - oh_i//2), (ox_i + ow_i, gy - oh_i//2)], fill=(0,0,0,50), width=1)
    # Crown spikes along top
    for i in range(5):
        t2 = (i + 0.5) / 5
        sx = ox_i + int(ow_i * t2)
        sh = oh_i * 38 // 100
        hw = ow_i * 7 // 100
        draw.polygon([
            (sx - hw, gy - oh_i),
            (sx, gy - oh_i - sh),
            (sx + hw, gy - oh_i),
        ], fill=(180, 60, 255, 220))
    # Animated neon outline
    draw.rectangle([ox_i, gy - oh_i, ox_i + ow_i, gy], outline=(200, 80, 255, 255), width=2)
    # Highlight
    draw.rectangle([ox_i+3, gy-oh_i+3, ox_i+ow_i-3, gy-oh_i+oh_i//5], fill=(255,255,255,20))

def draw_pad(draw, ox, ow, oh, t):
    gy = si(GROUND_Y)
    ox_i, ow_i, oh_i = si(ox), si(ow), si(oh)
    bd         = math.sin(t * 3.2)
    bounce_amt = int(oh_i * 0.16 * bd)
    frame_y    = gy - oh_i * 28 // 100
    surf_y     = gy - oh_i * 68 // 100 + bounce_amt
    sag        = oh_i * 7 // 100 * int(bd)

    spring_cols = [
        (255, 60, 80),  (255, 160, 0),  (255, 230, 0),
        (60, 220, 80),  (0, 180, 255),  (180, 60, 255),
    ]

    # Base feet
    draw.line([(ox_i, gy), (ox_i + ow_i//6, gy)],  fill=(0,210,190,255), width=si(4)+2)
    draw.line([(ox_i + ow_i*5//6, gy), (ox_i+ow_i, gy)], fill=(0,210,190,255), width=si(4)+2)
    # Angled legs
    for lx, lft in [(ox_i + ow_i//14, ox_i + ow_i//6),
                    (ox_i + ow_i*13//14, ox_i + ow_i*5//6)]:
        draw.line([(lx, gy), (lft, frame_y)], fill=(0,160,220,255), width=si(3)+1)
    # Horizontal frame bar
    draw.line([(ox_i + ow_i//6, frame_y), (ox_i + ow_i*5//6, frame_y)],
              fill=(0,130,210,255), width=si(5)+2)
    # Springs
    for i, col in enumerate(spring_cols):
        sx  = ox_i + ow_i//6 + (ow_i * 2//3) * i // 5
        pts = []
        segs = 6
        hw = max(2, ow_i * 4 // 100)
        for j in range(segs + 1):
            ft = j / segs
            sy2 = int(frame_y + (surf_y - frame_y) * ft)
            xo = hw if j % 2 == 0 else -hw
            pts.append((sx + xo, sy2))
        draw.line(pts, fill=col+(220,), width=2)
    # Rainbow surface
    sag_f = oh_i * 7 // 100
    surf_pts = [
        (ox_i + ow_i//10,    surf_y),
        (ox_i + ow_i*32//100, surf_y + sag_f//2),
        (ox_i + ow_i//2,     surf_y + sag_f),
        (ox_i + ow_i*68//100, surf_y + sag_f//2),
        (ox_i + ow_i*9//10,  surf_y),
    ]
    for col in reversed(spring_cols):
        draw.line(surf_pts, fill=col+(180,), width=4)
    draw.line(surf_pts, fill=(255, 255, 255, 230), width=2)
    # End caps
    for ex, ey in [(ox_i + ow_i//10, surf_y), (ox_i + ow_i*9//10, surf_y)]:
        draw.ellipse([ex-4, ey-4, ex+4, ey+4], fill=spring_cols[0]+(255,))

def draw_label(draw, text, y, col=(255, 240, 80, 255)):
    font = ImageFont.load_default()
    tw = len(text) * 6
    x  = GW // 2 - tw // 2
    # Drop shadow
    draw.text((x+1, y+1), text, font=font, fill=(0, 0, 0, 180))
    draw.text((x, y),     text, font=font, fill=col)

def paste_cat(canvas, py, tilt_deg, sprite_key):
    cat = CATS[sprite_key]
    if abs(tilt_deg) > 0.5:
        cat = cat.rotate(-tilt_deg, resample=Image.BICUBIC, expand=False)
    cx = si(PLAYER_X + PW * 0.5)
    cy = si(py + 26.0)
    x  = cx - cw // 2
    y  = cy - ch // 2
    canvas.paste(cat, (x, y), cat)

# ── Physics ───────────────────────────────────────────────────────────────────
def physics_step(state, dt):
    pvy  = state['pvy'] + GRAVITY * dt
    py   = state['py'] + pvy * dt
    on_g = False
    if py >= GROUND_Y - PH:
        py, pvy, on_g = GROUND_Y - PH, 0.0, True
        state['jumps'] = 0
    state.update(py=py, pvy=pvy, on_ground=on_g)

def do_jump(state):
    if state['jumps'] < MAX_JUMPS:
        pvy = JUMP_VEL - state['jumps'] * 80.0
        state.update(pvy=pvy, jumps=state['jumps'] + 1)
        return True
    return False

def do_pad_bounce(state, mult=1.9):
    state.update(pvy=JUMP_VEL * mult, jumps=1)

# ── Obstacle sequence ─────────────────────────────────────────────────────────
# Each obstacle spawns off the right edge and scrolls left.
# spawn_t: sim time when it appears at x = SW + 80.
# ow/oh are the full game-coordinate widths (OBS_SCALE applied).
SPIKE_W, SPIKE_H = 52 * OBS_SCALE, 52 * OBS_SCALE
BLOCK_W, BLOCK_H = 52 * OBS_SCALE, 52 * OBS_SCALE
PAD_W,   PAD_H   = 54 * OBS_SCALE, 22 * OBS_SCALE

OBS_SEQ = [
    {'type': 'spike', 'w': SPIKE_W, 'h': SPIKE_H, 'x': SW + 80, 'spawn_t': 0.0,  'triggered': False},
    {'type': 'block', 'w': BLOCK_W, 'h': BLOCK_H, 'x': SW + 80, 'spawn_t': 2.6,  'triggered': False},
    {'type': 'pad',   'w': PAD_W,   'h': PAD_H,   'x': SW + 80, 'spawn_t': 5.2,  'triggered': False},
    {'type': 'spike', 'w': SPIKE_W, 'h': SPIKE_H, 'x': SW + 80, 'spawn_t': 7.4,  'triggered': False},
]

# ── Simulate and collect frames ───────────────────────────────────────────────
state = {'py': GROUND_Y - PH, 'pvy': 0.0, 'jumps': 0, 'on_ground': True}
sim_t = 0.0
bg_hue = 0.6

active_obs = []
frames     = []

# label: (text, until_sim_t, col)
current_label = None

last_on_ground = True
land_flash     = 0.0   # frames to show 'land' sprite after touching down

total_steps = int(TOTAL_SEC * SIM_FPS)

print(f"Simulating {total_steps} steps → {total_steps // SIM_PER_GIF} GIF frames …")

for step in range(total_steps):
    sim_t  = step * SIM_DT
    bg_hue = (0.6 + sim_t * 0.04) % 1.0

    # Spawn scheduled obstacles
    for obs in OBS_SEQ:
        if not obs.get('spawned') and sim_t >= obs['spawn_t']:
            obs['x']       = SW + 80.0
            obs['spawned'] = True
            obs['triggered'] = False
            active_obs.append(obs)

    # Scroll obstacles
    for obs in active_obs:
        obs['x'] -= BASE_SPEED * SIM_DT

    # Remove off-screen
    active_obs = [o for o in active_obs if o['x'] + o['w'] > -100]

    # ── Scripted AI decisions ─────────────────────────────────────────────────
    cat_bottom = state['py'] + PH

    for obs in active_obs:
        ox, ow, oh = obs['x'], obs['w'], obs['h']
        dist = ox - (PLAYER_X + PW)   # gap between cat right edge and obs left edge

        if obs['type'] in ('spike', 'block') and not obs.get('jumped'):
            # Jump when obstacle is ~280 px ahead and we're on ground
            if dist < 280 and dist > 0 and state['on_ground']:
                do_jump(state)
                obs['jumped'] = True
                lbl_text = 'JUMP!' if obs['type'] == 'spike' else 'JUMP!'
                current_label = (lbl_text, sim_t + 0.55, (255, 240, 80, 255))

        if obs['type'] == 'pad' and not obs['triggered']:
            px_overlap = PLAYER_X + PW > ox and PLAYER_X < ox + ow
            if px_overlap and abs(cat_bottom - GROUND_Y) < 30 and state['pvy'] >= -200:
                do_pad_bounce(state, 1.9)
                obs['triggered'] = True
                current_label = ('AUTO JUMP!', sim_t + 0.9, (80, 255, 200, 255))

    # Double-jump: fire when descending after trampoline bounce if another obs is ahead
    if state['pvy'] > 300 and state['jumps'] == 1:
        for obs in active_obs:
            if obs['type'] == 'spike' and not obs.get('jumped') and obs.get('spawned'):
                dist2 = obs['x'] - (PLAYER_X + PW)
                if 0 < dist2 < 450:
                    do_jump(state)
                    obs['jumped'] = True
                    current_label = ('DOUBLE JUMP!', sim_t + 0.7, (200, 120, 255, 255))

    # ── Physics step ─────────────────────────────────────────────────────────
    prev_on_ground = state['on_ground']
    physics_step(state, SIM_DT)
    if state['on_ground'] and not prev_on_ground:
        land_flash = 10   # frames

    if land_flash > 0:
        land_flash -= 1

    # ── Choose sprite ─────────────────────────────────────────────────────────
    if state['on_ground']:
        sprite = 'land' if land_flash > 0 else 'idle'
    elif state['pvy'] < 0:
        sprite = 'doublejump' if state['jumps'] >= 2 else 'jump'
    else:
        sprite = 'jump'

    tilt = max(-22.0, min(22.0, state['pvy'] * 0.020))

    # ── Capture GIF frame ─────────────────────────────────────────────────────
    if step % SIM_PER_GIF == 0:
        canvas = Image.new('RGBA', (GW, GH), (0, 0, 0, 255))
        draw   = ImageDraw.Draw(canvas, 'RGBA')

        draw_background(draw, sim_t, bg_hue)

        # Obstacles
        for obs in active_obs:
            ox, ow, oh = obs['x'], obs['w'], obs['h']
            if ox + ow < 0 or ox > SW:
                continue
            if obs['type'] == 'spike':
                draw_spike(draw, ox, ow, oh)
            elif obs['type'] == 'block':
                draw_block(draw, ox, ow, oh)
            elif obs['type'] == 'pad':
                draw_pad(draw, ox, ow, oh, sim_t)

        # Cat
        paste_cat(canvas, state['py'], tilt, sprite)

        # Label
        if current_label and sim_t < current_label[1]:
            label_y = si(state['py']) - si(80)
            draw_label(draw, current_label[0], max(10, label_y), current_label[2])

        # HUD score strip
        draw.rectangle([0, 0, GW, si(28)], fill=(0, 0, 0, 120))
        draw_label(draw, 'GEOMETRY DASH  —  DEMO', si(6), col=(200, 200, 255, 200))

        frames.append(canvas.convert('P', palette=Image.ADAPTIVE, colors=128))

print(f"Rendering {len(frames)} frames to {OUT_PATH} …")
frames[0].save(
    OUT_PATH,
    save_all=True,
    append_images=frames[1:],
    duration=int(1000 / GIF_FPS),
    loop=0,
    optimize=True,
)
print("Done.")

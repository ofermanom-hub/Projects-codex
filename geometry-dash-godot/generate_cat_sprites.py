"""
Draw anime chibi cat game sprites (64x64 RGBA).
Inspired by the real cat: orange tabby, green eyes, fluffy fur.
Outputs: cat_idle.png, cat_jump.png, cat_doublejump.png, cat_land.png, cat_dead.png
"""
import math
from PIL import Image, ImageDraw, ImageFilter
import os

OUT_DIR = r"C:\Users\yotam\.claude\projects\geometry-dash-godot\assets"
SIZE    = 64

# ── Palette ────────────────────────────────────────────────────────────────
FUR_MID    = (228, 110,  28, 255)   # main orange fur
FUR_LIGHT  = (248, 170,  70, 255)   # highlight / chest
FUR_DARK   = (180,  65,  10, 255)   # shadow / stripes
EAR_INNER  = (220, 150, 130, 255)   # ear pink
EYE_IRIS   = ( 55, 190,  85, 255)   # green eyes (matches real cat)
EYE_PUPIL  = ( 15,  10,   8, 255)
EYE_SHINE  = (255, 255, 255, 255)
NOSE       = (220,  85, 110, 255)
MOUTH_C    = (180,  60,  80, 255)
WHISKER    = (255, 255, 255, 180)
OUTLINE    = ( 18,   6,   0, 255)   # very dark brown
TRANS      = (  0,   0,   0,   0)


def new_canvas(size=SIZE):
    return Image.new('RGBA', (size, size), TRANS)


def draw_outline_ellipse(draw, bbox, fill, outline, width=2):
    ox, oy, ox2, oy2 = bbox
    draw.ellipse([ox-width, oy-width, ox2+width, oy2+width], fill=outline)
    draw.ellipse(bbox, fill=fill)


def draw_outline_polygon(draw, pts, fill, outline, width=2):
    def expand(pts, amt):
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        return [(cx + (x-cx)*(1+amt/10), cy + (y-cy)*(1+amt/10)) for x,y in pts]
    draw.polygon(expand(pts, width), fill=outline)
    draw.polygon(pts, fill=fill)


def draw_cat(scale_x=1.0, scale_y=1.0, state='idle'):
    """
    Draw the anime chibi cat.
    state: 'idle' | 'jump' | 'doublejump' | 'land' | 'dead'
    scale_x/y: squash-stretch applied to the final image.
    """
    img  = new_canvas(SIZE * 2)   # draw at 2x then downsample
    draw = ImageDraw.Draw(img)
    S    = SIZE * 2                # 128 px canvas

    # ── coordinate helpers (all in 2x space) ──────────────────────────────
    cx  = S // 2           # horizontal center = 64
    # Vertical layout:
    head_cy  = 52          # head center y
    head_rx  = 30          # head x-radius
    head_ry  = 28          # head y-radius
    body_cy  = 92          # body center
    body_rx  = 22
    body_ry  = 18

    # ── Body ──────────────────────────────────────────────────────────────
    draw_outline_ellipse(draw,
        [cx-body_rx, body_cy-body_ry, cx+body_rx, body_cy+body_ry],
        FUR_MID, OUTLINE, width=3)
    # chest highlight
    draw.ellipse([cx-10, body_cy-10, cx+10, body_cy+8], fill=FUR_LIGHT)

    # Tail (arc approximated with a thick curved polyline)
    tail_pts = []
    for i in range(12):
        t     = i / 11.0
        ang   = math.radians(-20 + t * 140)
        rad   = 26 + t * 6
        tx    = int(cx + 22 + math.cos(ang) * rad)
        ty    = int(body_cy + 10 - math.sin(ang) * rad)
        tail_pts.append((tx, ty))
    for i in range(len(tail_pts)-1):
        w = 5 if i < 6 else 4
        draw.line([tail_pts[i], tail_pts[i+1]], fill=OUTLINE, width=w+3)
    for i in range(len(tail_pts)-1):
        w = 5 if i < 6 else 4
        draw.line([tail_pts[i], tail_pts[i+1]], fill=FUR_MID, width=w)
    # tail tip lighter
    draw.ellipse([tail_pts[-1][0]-5, tail_pts[-1][1]-5,
                  tail_pts[-1][0]+5, tail_pts[-1][1]+5], fill=FUR_LIGHT)

    # Front paws
    for px_off in [-14, 6]:
        draw_outline_ellipse(draw,
            [cx+px_off, body_cy+body_ry-4, cx+px_off+14, body_cy+body_ry+10],
            FUR_MID, OUTLINE, width=2)
        draw_outline_ellipse(draw,
            [cx+px_off+1, body_cy+body_ry+4, cx+px_off+13, body_cy+body_ry+12],
            FUR_LIGHT, OUTLINE, width=1)

    # Body stripes
    for dx in [-8, 0, 8]:
        draw.line([(cx+dx, body_cy-body_ry+4), (cx+dx, body_cy+body_ry-6)],
                  fill=FUR_DARK, width=2)

    # ── Head ──────────────────────────────────────────────────────────────
    draw_outline_ellipse(draw,
        [cx-head_rx, head_cy-head_ry, cx+head_rx, head_cy+head_ry],
        FUR_MID, OUTLINE, width=3)

    # Head highlight (top dome)
    draw.ellipse([cx-18, head_cy-head_ry+2, cx+18, head_cy], fill=FUR_LIGHT)

    # Forehead tabby stripes
    for dx in [-8, 0, 8]:
        draw.line([(cx+dx, head_cy-head_ry+4), (cx+dx, head_cy-10)],
                  fill=FUR_DARK, width=2)

    # ── Ears ──────────────────────────────────────────────────────────────
    for side in [-1, 1]:
        ear_tip_x = cx + side * (head_rx - 4)
        ear_tip_y = head_cy - head_ry - 18
        ear_bl    = (cx + side * 8,  head_cy - head_ry + 4)
        ear_br    = (cx + side * 22, head_cy - head_ry + 4)
        pts = [(ear_tip_x, ear_tip_y), ear_bl, ear_br]
        draw_outline_polygon(draw, pts, FUR_MID,   OUTLINE, width=3)
        # inner ear (smaller, lighter)
        inner = [(ear_tip_x, ear_tip_y+6),
                 (ear_bl[0]+side*2, ear_bl[1]-2),
                 (ear_br[0]-side*2, ear_br[1]-2)]
        draw.polygon(inner, fill=EAR_INNER)

    # ── Eyes ──────────────────────────────────────────────────────────────
    eye_y   = head_cy - 2
    eye_sep = 16
    eye_rx  = 10
    eye_ry  = 9 if state not in ('dead',) else 7

    for side in [-1, 1]:
        ex = cx + side * eye_sep
        # white sclera
        draw.ellipse([ex-eye_rx-1, eye_y-eye_ry-1, ex+eye_rx+1, eye_y+eye_ry+1],
                     fill=(240, 245, 240, 255))
        if state == 'dead':
            # X eyes
            draw.line([(ex-eye_rx+2, eye_y-eye_ry+2), (ex+eye_rx-2, eye_y+eye_ry-2)],
                      fill=(220, 40, 40, 255), width=4)
            draw.line([(ex-eye_rx+2, eye_y+eye_ry-2), (ex+eye_rx-2, eye_y-eye_ry+2)],
                      fill=(220, 40, 40, 255), width=4)
        else:
            # iris
            draw.ellipse([ex-eye_rx, eye_y-eye_ry, ex+eye_rx, eye_y+eye_ry],
                         fill=EYE_IRIS)
            # pupil (slightly off-center for expression)
            pd = 2 if state in ('jump','doublejump') else 0
            draw.ellipse([ex-5, eye_y-eye_ry+1+pd, ex+5, eye_y+eye_ry-1+pd],
                         fill=EYE_PUPIL)
            # shine dot
            draw.ellipse([ex-eye_rx+2, eye_y-eye_ry+2,
                          ex-eye_rx+8, eye_y-eye_ry+8],
                         fill=EYE_SHINE)
            # smaller second shine
            draw.ellipse([ex+3, eye_y+3, ex+6, eye_y+6],
                         fill=(255, 255, 255, 160))

    # Wink/excited line under eyes for jump state
    if state in ('jump', 'doublejump'):
        for side in [-1, 1]:
            ex = cx + side * eye_sep
            draw.arc([ex-eye_rx, eye_y, ex+eye_rx, eye_y+eye_ry*2+4],
                     start=0, end=180, fill=(*EYE_IRIS[:3], 160), width=2)

    # ── Nose ──────────────────────────────────────────────────────────────
    nose_pts = [(cx, head_cy+10), (cx-5, head_cy+16), (cx+5, head_cy+16)]
    draw.polygon(nose_pts, fill=NOSE)
    draw.polygon(nose_pts, fill=OUTLINE)
    draw.polygon([(cx, head_cy+11), (cx-4, head_cy+15), (cx+4, head_cy+15)],
                 fill=NOSE)

    # ── Mouth ─────────────────────────────────────────────────────────────
    if state == 'dead':
        draw.arc([cx-10, head_cy+14, cx+10, head_cy+24],
                 start=180, end=360, fill=MOUTH_C, width=3)
    else:
        draw.arc([cx-8, head_cy+14, cx, head_cy+22],
                 start=0, end=180, fill=MOUTH_C, width=3)
        draw.arc([cx, head_cy+14, cx+8, head_cy+22],
                 start=0, end=180, fill=MOUTH_C, width=3)

    # ── Cheek fluff ───────────────────────────────────────────────────────
    for side in [-1, 1]:
        fx = cx + side * (head_rx - 6)
        fy = head_cy + 6
        draw.ellipse([fx-8, fy-6, fx+8, fy+6],
                     fill=(*FUR_LIGHT[:3], 80))

    # ── Whiskers ──────────────────────────────────────────────────────────
    for side in [-1, 1]:
        wx0 = cx + side * 6
        for row, dy in enumerate([-4, 0, 4]):
            wx1 = cx + side * 36
            wy  = head_cy + 10 + dy
            draw.line([(wx0, wy), (wx1, wy + row - 1)], fill=WHISKER, width=2)

    # ── Ears inner tip lines (fur detail) ─────────────────────────────────
    for side in [-1, 1]:
        ear_tip_x = cx + side * (head_rx - 4)
        ear_tip_y = head_cy - head_ry - 18
        for i in range(3):
            ty = ear_tip_y + 4 + i * 4
            tx = ear_tip_x + side * i * 1
            draw.line([(tx, ty), (cx + side*15, head_cy - head_ry + 2)],
                      fill=(*FUR_DARK[:3], 100), width=1)

    # ── Downsample 2x → SIZE ──────────────────────────────────────────────
    result = img.resize((SIZE, SIZE), Image.LANCZOS)

    # ── Squash/stretch transform ───────────────────────────────────────────
    if scale_x != 1.0 or scale_y != 1.0:
        nw = max(1, int(SIZE * scale_x))
        nh = max(1, int(SIZE * scale_y))
        scaled = result.resize((nw, nh), Image.LANCZOS)
        canvas = new_canvas(SIZE)
        ox = (SIZE - nw) // 2
        oy = (SIZE - nh) // 2
        canvas.paste(scaled, (ox, oy), scaled)
        result = canvas

    return result


def add_sparkles(img_in, color=(255, 230, 60, 230)):
    out  = img_in.copy()
    draw = ImageDraw.Draw(out)
    sz   = out.size[0]
    for sx, sy, arm_len in [(7,7,7),(sz-7,7,7),(5,sz-9,6),(sz-5,sz-8,6),(sz//2,3,6)]:
        for a in range(4):
            ang = math.radians(a * 90)
            ex = int(sx + math.cos(ang) * arm_len)
            ey = int(sy + math.sin(ang) * arm_len)
            draw.line([(sx,sy),(ex,ey)], fill=color, width=2)
        draw.ellipse([sx-2,sy-2,sx+2,sy+2], fill=color)
    # diagonal shorter sparkles
    for sx, sy in [(12, sz-14), (sz-12, sz-14)]:
        for a in [45, 135]:
            ang = math.radians(a)
            ex = int(sx + math.cos(ang) * 5)
            ey = int(sy + math.sin(ang) * 5)
            draw.line([(sx,sy),(ex,ey)], fill=color, width=1)
    return out


def add_motion_lines(img_in):
    out  = img_in.copy()
    draw = ImageDraw.Draw(out)
    sz   = out.size[0]
    for y_frac, length in [(0.3, 14), (0.45, 18), (0.55, 16), (0.7, 12)]:
        y = int(sz * y_frac)
        draw.line([(0, y), (length, y)], fill=(255,255,255,110), width=2)
    return out


# ── Generate all frames ─────────────────────────────────────────────────────
frames = {
    'cat_idle':       draw_cat(1.0, 1.0, 'idle'),
    'cat_jump':       add_motion_lines(draw_cat(0.80, 1.22, 'jump')),
    'cat_doublejump': add_sparkles(draw_cat(1.28, 0.72, 'doublejump')),
    'cat_land':       draw_cat(1.30, 0.72, 'idle'),
    'cat_dead':       draw_cat(1.0,  1.0,  'dead'),
}

os.makedirs(OUT_DIR, exist_ok=True)
for name, frame in frames.items():
    path = os.path.join(OUT_DIR, f"{name}.png")
    frame.save(path, 'PNG')
    print(f"Saved: {path}")

print("All sprites done!")

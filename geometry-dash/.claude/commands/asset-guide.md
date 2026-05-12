# Skill: Asset Integration Guide

You are an asset pipeline specialist. When the user needs art, always source free high-quality assets before generating placeholder art. Provide exact import steps, not vague instructions.

## Free Asset Sources (priority order)

### 2D Sprites & Textures
| Source | Best for | URL |
|---|---|---|
| Kenney.nl | UI, tilesets, icons, characters | kenney.nl/assets |
| OpenGameArt | Everything; variable quality | opengameart.org |
| Itch.io free assets | Stylized 2D packs | itch.io (filter: free) |
| Lospec Palette List | Pixel art palettes | lospec.com/palette-list |

### 3D Models
| Source | Best for | URL |
|---|---|---|
| Sketchfab (free filter) | Hero models, environments | sketchfab.com |
| Poly Pizza | Low-poly game-ready | poly.pizza |
| Quaternius | Stylized animated characters | quaternius.com |
| Mixamo | Rigged + animated humanoids | mixamo.com |

### Fonts
| Source | Notes |
|---|---|
| Google Fonts | Free, commercial OK |
| DaFont | Check license per font |
| FontSquirrel | Pre-cleared commercial use |

### Audio
| Source | Best for |
|---|---|
| freesound.org | SFX |
| OpenGameArt | Music loops |
| Incompetech (Kevin MacLeod) | Background music, royalty-free |
| JSFXR / ChipTone | Procedural 8-bit SFX |

---

## Mixamo → Godot 4 Workflow (Animated Characters)

1. **Get a character:** Download from Mixamo as FBX (With Skin)
2. **Get animations:** Download each animation as FBX (Without Skin) — keep same rig
3. **Import to Godot:**
   - Drag FBX into `res://characters/` — Godot auto-imports
   - Select the `.fbx` in FileSystem → Import tab → set **Animation Import Mode: All**
   - Click **Reimport**
4. **Retarget animations:**
   ```
   AnimationLibrary resource → add each animation FBX as source
   Use AnimationTree + AnimationStateMachine for blending
   ```
5. **Apply in scene:**
   ```gdscript
   @onready var anim_tree: AnimationTree = $AnimationTree
   anim_tree["parameters/conditions/is_jumping"] = true
   ```

---

## Blender → Godot 4 Workflow (Custom Models)

Export settings from Blender:
- Format: **glTF 2.0 (.glb)** — best Godot compatibility
- Include: Mesh data + Armature + Shape Keys
- Apply modifiers: Yes
- Compression: None (Godot handles this)

Import in Godot:
1. Drop `.glb` into project folder
2. Godot auto-generates a scene — right-click → **New Inherited Scene** to customize
3. Materials: Godot imports Blender PBR materials automatically if using Principled BSDF

---

## Kenney Asset Pack → Godot 2D Workflow

1. Download PNG spritesheet + XML atlas from kenney.nl
2. In Godot: Import PNG → **Texture Import** → Filter: Nearest (for pixel art)
3. Create `AtlasTexture` resources pointing to regions from the XML
4. Or use **SpriteFrames** resource for animation:
   ```
   SpriteFrames → Add frames from atlas → assign to AnimatedSprite2D
   ```

---

## Geometry Dash Specific Recommendations

### Player skin
- Use a 64×64 PNG sprite sheet with 4 rotation frames
- Source: design in Aseprite (free), or grab from Kenney's shape packs

### Obstacle textures
- Keep obstacles shader-driven (no textures) — neon glow from emission is the style
- If adding variety: use simple geometric SVGs converted to PNG

### Background
- No texture needed — procedural grid shader (see `/visual-pipeline`)
- For distant mountains/cityscape: download silhouette PNG from opengameart.org

### Music
- Target BPM: 140 (typical Geometry Dash feel)
- Source: search "140 bpm loop free" on freesound.org or opengameart.org
- Format: OGG Vorbis — Godot's native audio format (smaller than MP3, loops cleanly)

### SFX
- Jump: short sine sweep up, 80ms — generate with JSFXR
- Death: noise burst + pitch drop, 300ms — generate with ChipTone
- Milestone: major chord arpeggio, 500ms

---

## Import Checklist
When bringing any asset into the project:
- [ ] Texture: compression set correctly (Lossless for sprites, VRAM for 3D)
- [ ] Audio: OGG format, loop points set if music
- [ ] Model: materials imported, scale correct (1 unit = 1 meter in 3D)
- [ ] Font: added to Project Settings → Fonts for global access
- [ ] All assets in `res://assets/[category]/` — never in project root

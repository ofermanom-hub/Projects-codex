# Skill: Visual Rendering Pipeline

You are a rendering engineer. Before writing any scene code, establish the full visual pipeline first. Do not skip this step — it is the difference between a flat prototype and a polished game.

## Step 1 — Environment & Lighting Foundation
Set up `WorldEnvironment` with an `Environment` resource:
```gdscript
# In Main.tscn, add WorldEnvironment node, then configure:
environment.background_mode = Environment.BG_SKY
environment.sky = ProceduralSkyMaterial.new()

# Sky colors (tune per art style)
sky_material.sky_top_color    = Color(0.05, 0.05, 0.15)   # deep indigo
sky_material.sky_horizon_color = Color(0.1, 0.05, 0.2)    # dark violet
sky_material.ground_horizon_color = Color(0.05, 0.02, 0.1)
sky_material.ground_bottom_color  = Color(0.02, 0.02, 0.05)
```

Add a `DirectionalLight3D` (or `DirectionalLight2D` for 2D):
- **2D:** Use `CanvasModulate` + a point/directional light from `Light2D` nodes
- **Shadows:** Enable on all significant light sources (`shadow_enabled = true`)
- **Energy:** Start at 1.2, tweak per mood

## Step 2 — PBR Materials
Every surface needs all four PBR channels. Never use a plain `Color` for a surface visible to the player:

```gdscript
var mat := StandardMaterial3D.new()
mat.albedo_color    = Color(0.1, 0.1, 0.2)   # base color — no baked lighting
mat.metallic        = 0.0                      # 0 = plastic/stone, 1 = metal
mat.roughness       = 0.7                      # 0 = mirror, 1 = chalk
mat.normal_enabled  = true
mat.normal_texture  = preload("res://textures/ground_normal.png")
mat.emission_enabled = true
mat.emission        = Color(0.0, 0.4, 1.0)    # neon glow color
mat.emission_energy = 2.0
```

For Geometry Dash 2D style — use `CanvasItemMaterial` with a custom `.gdshader`:
```glsl
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = tex;
    COLOR.rgb += glow_color.rgb * tex.a * glow_strength;
}
```

## Step 3 — Post-Processing Stack
Configure on the `Environment` resource (required before any scene code):

```gdscript
# Glow / Bloom
environment.glow_enabled       = true
environment.glow_intensity     = 0.8
environment.glow_bloom         = 0.3
environment.glow_blend_mode    = Environment.GLOW_BLEND_MODE_ADDITIVE

# Tone Mapping (ACES for cinematic look)
environment.tonemap_mode       = Environment.TONE_MAPPER_ACES
environment.tonemap_exposure   = 1.1
environment.tonemap_white      = 6.0

# Color Grading
environment.adjustment_enabled    = true
environment.adjustment_brightness = 1.05
environment.adjustment_contrast   = 1.1
environment.adjustment_saturation = 1.15

# Ambient Occlusion (3D only)
environment.ssao_enabled = true
environment.ssao_radius  = 1.0
environment.ssao_intensity = 2.0

# Depth of Field (optional, for menu/death screens)
environment.dof_blur_far_enabled   = false   # enable on death screen
environment.dof_blur_far_distance  = 10.0
environment.dof_blur_far_transition = 5.0
```

## Step 4 — Dynamic Shadows
For 2D:
- Use `Light2D` with `shadow_enabled = true` on obstacles and player
- Set `shadow_filter = Light2D.SHADOW_FILTER_PCF13` for soft shadows
- Layer masks: background on layer 1, obstacles on layer 2, player on layer 3

For 3D:
```gdscript
directional_light.shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
directional_light.directional_shadow_max_distance = 100.0
```

## Step 5 — Skybox / Background
Geometry Dash style — use a `ParallaxBackground` with shader-driven layers:
```gdscript
# Each ParallaxLayer gets a ColorRect with this shader
shader_type canvas_item;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;
uniform vec4 color_a : source_color;
uniform vec4 color_b : source_color;
uniform float grid_size : hint_range(10.0, 200.0) = 50.0;
uniform float glow : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec2 uv = UV * vec2(textureSize(TEXTURE, 0));
    vec2 grid = fract((uv + vec2(TIME * time_offset, 0.0)) / grid_size);
    float line = step(0.96, grid.x) + step(0.96, grid.y);
    COLOR = mix(color_a, color_b * glow, line);
}
```

## Pipeline Setup Order (always follow this sequence)
1. `WorldEnvironment` + sky → establishes baseline lighting
2. `DirectionalLight` / `Light2D` → primary illumination
3. PBR/shader materials on all surfaces → correct surface response
4. Post-processing (glow, tone map, color grade) → cinematic finish
5. Particles and VFX → layered on top of correct lighting

## Audit Checklist
Before writing any gameplay code, verify the pipeline is complete:
- [ ] `WorldEnvironment` node exists with `Environment` resource
- [ ] Glow/bloom enabled
- [ ] ACES tone mapping active
- [ ] No plain `Color` materials on player-visible surfaces
- [ ] Shadows enabled on primary light source
- [ ] Background uses parallax + shader, not a flat color fill

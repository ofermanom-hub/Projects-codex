# Skill: Godot 4 Engine Architect

You are a Lead Godot 4.x Developer. Apply these standards to all GDScript, scene structures, and project architecture:

## Static Typing — Always
```gdscript
# WRONG
var speed = 5.0
func move(delta):

# RIGHT
var speed: float = 5.0
func move(delta: float) -> void:
```
- Every variable, parameter, and return type must be annotated
- Use `@export` with type hints: `@export var jump_force: float = 400.0`
- Prefer `int`, `float`, `Vector2`, `Vector3`, `String`, `bool` over untyped `Variant`

## Signals — Godot 4 Syntax
```gdscript
# Declaration
signal player_died(score: int)
signal obstacle_hit(obstacle: Node2D)

# Emission (NOT .emit on the class — call on the signal)
player_died.emit(current_score)

# Connection (prefer code over editor for programmatic nodes)
player.player_died.connect(_on_player_died)
```

## Composition over Inheritance
Build features as **component Nodes**, not base class hierarchies:
```
Player (CharacterBody2D)
├── HealthComponent (Node) — hp, damage, death signal
├── JumpComponent (Node) — coyote, buffer, jump logic
├── TrailComponent (Node2D) — visual trail
└── SquashStretchComponent (Node) — scale animation
```
Each component owns its own state and emits signals. Parent just wires signals together.

## Scene Structure for Geometry Dash
```
Main.tscn
├── World (Node2D)
│   ├── Background (ParallaxBackground)
│   │   ├── ParallaxLayer (far)
│   │   └── ParallaxLayer (near)
│   ├── Ground (StaticBody2D + CollisionShape2D + Sprite2D)
│   ├── ObstaclePool (Node2D) — pooled obstacle instances
│   └── Player (CharacterBody2D)
│       ├── CollisionShape2D
│       ├── Sprite2D (or AnimatedSprite2D)
│       ├── Trail (Line2D or GPUParticles2D)
│       ├── JumpParticles (GPUParticles2D)
│       └── DeathParticles (GPUParticles2D)
├── HUD (CanvasLayer)
│   ├── ScoreLabel
│   ├── BestLabel
│   └── AttemptLabel
└── GameManager (Node) — state machine, scoring, spawning
```

## Resource-Driven Data
Use `Resource` classes for all tunable data — never hardcode in scripts:
```gdscript
# obstacle_data.gd
class_name ObstacleData extends Resource

@export var type: String = "spike"
@export var width: float = 40.0
@export var height: float = 40.0
@export var color: Color = Color.RED
```
Store instances as `.tres` files. Load with `preload("res://data/spike.tres")`.

## Object Pooling for Obstacles
```gdscript
# obstacle_pool.gd
var _pool: Array[Node2D] = []

func get_obstacle() -> Node2D:
    for o in _pool:
        if not o.visible:
            o.visible = true
            return o
    var new_ob := OBSTACLE_SCENE.instantiate()
    add_child(new_ob)
    _pool.append(new_ob)
    return new_ob

func release(obstacle: Node2D) -> void:
    obstacle.visible = false
    obstacle.position.x = 2000.0  # move offscreen
```

## Input — Use InputMap
Define actions in Project Settings → InputMap:
- `jump` → Space, Up Arrow, W, screen touch
- `restart` → R, Enter

```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("jump"):
        _try_jump()
```
Never hard-check `KEY_SPACE` in game logic.

## `await` for Async Flow
```gdscript
# Wait for animation to finish before respawning
await death_animation.animation_finished
reset_player()

# Wait for a timer
await get_tree().create_timer(0.5).timeout
```

## Export for Tweaking
Every gameplay constant must be `@export`:
```gdscript
@export_group("Physics")
@export var gravity: float = 980.0
@export var jump_velocity: float = -550.0
@export var max_speed: float = 320.0

@export_group("Difficulty")
@export var speed_increase_per_point: float = 0.04
@export var min_obstacle_gap: float = 55.0
```

## Performance Rules
- Use `GPUParticles2D`, not `CPUParticles2D`
- Pool all frequently spawned nodes — never `instantiate()` in a hot loop
- Use `Area2D` for death detection (cheaper than `CharacterBody2D.move_and_slide` collision checks against obstacles)
- Keep draw calls low: batch same-material obstacles via `MultiMeshInstance2D` if spawning >50 at once

## Godot Exe Path (this project)
The Godot 4.6.2 executable is at:
`C:\Users\yotam\.claude\projects\geometry-dash\Godot_v4.6.2-stable_win64.exe`

Run headless for script execution:
```
Godot_v4.6.2-stable_win64.exe --headless --script res://tools/build.gd
```
Export to exe via export presets — requires Windows export template installed.

## Audit Checklist
After generating Godot code, verify:
- [ ] All vars/params/returns statically typed
- [ ] Signals use `.emit()` syntax
- [ ] No deep inheritance — components used instead
- [ ] All tunable values are `@export`
- [ ] Input uses InputMap action names
- [ ] Obstacles use object pool, not instantiate-on-spawn
- [ ] `Area2D` used for kill zones, not collision layers on CharacterBody2D

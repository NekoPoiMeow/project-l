# Battle Stage Editor Notes

This document records the current MVP workflow for making a standard base-mode battle stage.

## Scene Folder

Per stage:

```text
res://scenes/Battle/Battle_00.tscn
res://scenes/Battle/Battle_00.ini
res://scenes/Battle/Battle_00/
  Background.png
  Collision.png
  Bio.png
  TenderArea.gif
```

`Background.png` is the visible map.  
`Collision.png` is the alpha mask. Pixels with alpha <= `block_alpha_limit` are unwalkable.
`Bio.png` is used for enemy drops, player-carried biomass, and flying delivery particles.
`TenderArea.gif` is the visible delivery area for the tentacle base.

Shared battle placeholder art currently lives in:

```text
res://GraphicAssets/07_Battle/
  weapon_basic_projectile.svg
  weapon_melee_arc.svg
  weapon_laser_beam.svg
  weapon_blackhole_core.svg
  weapon_orbit_blade.svg
  weapon_boomerang_barb.svg
```

These SVG files are white-background placeholders for art direction and replacement. Runtime attacks currently use procedural pixel blocks/trails, so replacing these files is optional until the attack art pipeline is formalized.

## Required Scene Nodes

Attach `res://BattleAssets/ScriptShader/BattleDirector.gd` to `NodeBattleDirector`.

```text
Node2DBattle
- Sprite2DBackground
- Sprite2DBlockMask
- Node2DWorld
  - Node2DNode2DEntities
  - Node2DProjectiles
  - Node2DEffects
- Node2DSpawnPoints
  - Marker2DPlayerSpawn
  - Marker2DTentacleBaseSpawn
  - Marker2DEnemyBaseSpawn
  - Marker2DEnemySpawnA
  - Marker2DEnemySpawnB
  - Marker2DEnemySpawnC
- Node2DSpecialTriggers
- CanvasLayerUI
  - LabelTimer
  - LabelObjective
  - TextureProgressBarPlayerBaseHP
  - TextureProgressBarEnemyBaseHP
- AudioStreamPlayerBGM
- AudioStreamPlayerSFX
- NodeBattleDirector
- Camera2DBattle
```

## Stage INI

Godot `ConfigFile` string values must be quoted.

```ini
[stage]
id="Battle_00"
duration=720
map_size="3200,2133"
background="res://scenes/Battle/Battle_00/Background.png"
block_mask="res://scenes/Battle/Battle_00/Collision.png"
block_alpha_limit=0.1
bio_texture="res://scenes/Battle/Battle_00/Bio.png"
win_condition="destroy_enemy_base"
```

Entity spawn sections:

```ini
[player]
entity_id="000"
spawn="PlayerSpawn"

[tentacle_base]
entity_id="001"
spawn="TentacleBaseSpawn"

[enemy_base]
entity_id="003"
spawn="EnemyBaseSpawn"
```

Wave sections:

```ini
[wave_001]
time=5
entity_id="002"
count=5
spawn="EnemySpawnA"
interval=0.5
ai_mode="chase_nearest"
movement_mode="direct"
target_factions="player|tentacle"
target_priority="nearest"
```

Leveling section:

```ini
[leveling]
start_level=1
level_cap=8
xp_curve="2,4,6,8,10,12,15"
choice_pool="laser_test|melee_arc_test|heal_pulse_test|blackhole_test|split_shot_test"
```

Enemy deaths grant XP through `reward.xp`; if omitted, normal enemies give 1 and buildings give 5. When player levels up, the game pauses and the battle UI offers 3 random choices from `choice_pool`; picking one applies the upgrade and resumes battle.

Level choices may be full attacks or upgrade items:

```json
{
  "upgrade_mode": "modify_attacks",
  "selector": {"tag": "basic_projectile"},
  "modifiers": [
    {"path": "emitter.count", "op": "add", "value": 1},
    {"path": "interval", "op": "mul", "value": 0.8}
  ]
}
```

```json
{
  "upgrade_mode": "add_effect_to_attacks",
  "selector": {"tag": "basic_projectile"},
  "effect": {
    "mode": "spawn_attack",
    "emitter_override": {"mode": "ring", "count": 4},
    "attack": {}
  }
}
```

Current selector fields: `id`, `kind`, `tag`.
Current modifier ops: `add`, `mul`, `set`.

Supported `spawn` values:

```text
Marker names: PlayerSpawn, EnemySpawnA, EnemyBaseSpawn, ...
Coordinate: "1200,900"
random_around_player
random_near_tentacle_base
```

For marker-based random spawns, use:

```ini
spawn="EnemyBaseSpawn"
random_radius_min=230
random_radius=420
```

`random_radius_min` keeps units away from the marker center. The script also rejects spawn points that overlap a building block radius.

Current AI fields:

```text
ai_mode: idle, player, chase_nearest
movement_mode: direct, strafe_close, orbit_close
target_priority: nearest, building_first, player_first
target_priority_order: player|minion|building|unit|base|tag:xxx|type:xxx
target_distance_mode: nearest, farthest
target_factions: enemy|player|tentacle
```

Target examples:

```ini
target_priority_order="player|minion|building"
target_distance_mode="nearest"
```

```json
"ai": {
  "mode": "chase_nearest",
  "target_factions": ["enemy"],
  "target_priority_order": ["building", "enemy", "unit"],
  "target_distance_mode": "farthest"
}
```

Use `nearest` for normal behavior. Use `farthest` for cases like minions being ordered toward distant bases while the player handles nearer sub-bases.

Pathing is lightweight steering rather than grid A*:

```text
Units move toward target.
If a building block circle is ahead, units blend in a tangent direction and slide around it.
If a unit barely moves for about 0.45 seconds, it forces one second of left/right building avoidance.
If the alpha collision mask blocks the next step, units try nearby rotated directions.
Normal units may overlap each other; only enemy-vs-tentacle overlaps cause small knockback and damage.
```

## Entity JSON

Entity configs live in:

```text
res://BattleAssets/000.json
res://BattleAssets/001.json
...
```

Each entity should define:

```json
{
  "id": "002",
  "type": "enemy",
  "faction": "enemy",
  "tags": ["enemy"],
  "visual": {
    "gif": "res://BattleAssets/002.gif",
    "scale": 1.0,
    "size": [120, 192],
    "offset": [0, 0]
  },
  "body": {
    "radius": 22,
    "sense_radius": 700
  },
  "stats": {
    "max_hp": 80,
    "move_speed": 95,
    "attack": 10,
    "defense": 0
  },
  "ai": {
    "mode": "chase_nearest",
    "movement_mode": "direct",
    "target_priority": "nearest",
    "target_factions": ["player", "tentacle"]
  },
  "attacks": [],
  "reward": {
    "bio": 3
  }
}
```

Building/base body:

```json
"body": {
  "radius": 142,
  "block_radius": 142,
  "sense_radius": 600
}
```

`radius` is hit/attack collision.  
`block_radius` blocks non-building units from walking over the building.

## Base System

Tentacle base can receive biomass only when the player stands inside its delivery area.

```json
"zones": {
  "delivery_radius": 128,
  "delivery_offset": [0, 260],
  "delivery_texture": "res://scenes/Battle/Battle_00/TenderArea.gif",
  "contact_radius": 120,
  "contact_damage": 16,
  "contact_cooldown": 0.9
},
"base": {
  "bio_cap": 160,
  "level": 1,
  "max_level": 3,
  "upgrade_thresholds": [60, 120],
  "upgrade_cd": 12.0,
  "level_passive_bio_per_second": [0, 10, 15],
  "can_spawn_level": 3,
  "spawn_entity_id": "004",
  "spawn_cost": 40,
  "spawn_interval": 1.5,
  "spawn_radius": 190
}
```

Current behavior:

```text
Enemy death drops Bio.
Player magnet-picks Bio.
Player carries max Bio by `stats.bio_cargo_max`.
Player stack display is compressed by `stats.bio_visual_unit`; for example, 100 carried Bio with `bio_visual_unit=10` shows about 10 Bio sprites.
Player stands on TenderArea.gif to send stack sprites one by one toward the base center.
Base receives Bio only after the flying Bio reaches the base. The delivered value per flying sprite is controlled by `stats.bio_transfer_chunk`.
Base upgrades after threshold is held for 12 seconds.
Level 2 starts passive Bio generation.
Level 3 increases passive Bio and starts minion production.
```

Player Bio fields:

```json
"stats": {
  "bio_cargo_max": 100,
  "bio_visual_unit": 10,
  "bio_transfer_chunk": 10
}
```

## Unit Contact

Current MVP contact rules:

```text
Buildings use their contact aura against enemy non-building units.
Player and tentacle are allied, so the tentacle base does not damage player.
Enemy base can damage and knock back player.
Enemy non-building units and tentacle non-building units push/damage each other when overlapping.
Player does not collide/knock back with normal units, so crowds should not trap player.
```

For melee units that must attack buildings, keep `range` larger than the target building block radius. Otherwise the unit stops outside the building collision but cannot hit the center point.

## Damage Multipliers

Damage is scaled by attacker config, then defense is subtracted. If scaled damage is above 0, the final result has a 1 damage floor. Movement speed does not decide whether something is a base; use `type`, `tags`, and `body.block_radius`.

```json
"combat": {
  "damage_multipliers": {
    "player": 1.0,
    "minion": 1.2,
    "building": 0.1,
    "tag:boss": 0.5,
    "tag:base": 0.1
  }
}
```

Current use cases:

```text
No-base mode: give player `building: 1.0` or omit the multiplier.
Base mode: give player low building damage, such as `building: 0.1`.
Anti-minion enemy: use `minion: 2.0`.
Enemy projectile that barely hurts buildings: put `"damage_multipliers": {"building": 0.05}` on that attack.
Enemy melee that can hurt buildings: omit the attack multiplier or use a higher building value.
```

## Attacks

Attacks currently live inside entity JSON. `BattleAttackRunner.gd` routes attack behavior.

Projectile example:

```json
{
  "kind": "projectile",
  "motion": "homing",
  "fire_point": "center",
  "target_point": "center",
  "interval": 0.7,
  "speed": 420,
  "damage": 25,
  "radius": 12,
  "life_time": 2.5
}
```

Supported fire/target points:

```text
center
top
bottom
left
right
custom
```

Use custom with:

```json
"fire_point": "custom",
"fire_offset": [0, -40]
```

## Attack Instance MVP

New attacks can use `kind: "attack_instance"` to enter the event/effect attack system. Old `melee` and `projectile` attacks still work.

Core structure:

```json
{
  "kind": "attack_instance",
  "requires_target": false,
  "interval": 3.0,
  "origin": {"mode": "self_center"},
  "aim": {"mode": "nearest_enemy"},
  "emitter": {"mode": "ring", "count": 8},
  "motion": {"mode": "linear", "speed": 360, "life_time": 2.0},
  "hit_shape": {"mode": "circle", "radius": 18},
  "hit_rule": {
    "mode": "on_contact",
    "destroy_on_hit": true,
    "hit_same_target_delay": 999
  },
  "target_filter": {
    "relation": "enemy",
    "include_building": true
  },
  "effects": [
    {"mode": "damage", "value": 25}
  ]
}
```

Supported MVP fields:

```text
origin.mode: self_center, target_center, camera_random_inside, camera_edge
aim.mode: target, nearest_enemy, player, mouse, random_dir, fixed_angle
emitter.mode: single, ring, spread, random_scatter
motion.mode: static, linear, homing, beam, orbit, boomerang, bounce_wall
hit_shape.mode: circle, sector, beam_rect
hit_rule.mode: on_spawn_once, on_contact, while_active_tick, on_arrive, on_expire
effect.mode: damage, heal, force, spawn_attack
target_filter.relation: enemy, ally, any
```

Damage and healing numbers are shown automatically by `BattleEntity.take_damage()` and `BattleEntity.heal()`.

## Bullet Test Stage

Use this scene for fast attack/bullet debugging:

```
res://scenes/Battle/Battle_BulletTest.tscn
res://scenes/Battle/Battle_BulletTest.ini
```

`Battle_BulletTest.ini` uses:

```
[test]
enabled=true
attack_ids="melee_arc_test|laser_test|flame_cone_test|lob_grenade_test|chain_lightning_test|poison_aura_test|control_seed_test|orbit_seek_test|spike_nova_test|blackhole_test"
spawn_entity_id="013"
spawn_count=12
spawn_radius=180
```

Controls in this test stage:

```
Q/E        previous/next test attack
Space      fire current test attack
Left Mouse fire current test attack
R          spawn test enemies around the mouse
1          projectile count +1
Shift+1    projectile count -1
2          damage x +0.25
Shift+2    damage x -0.25
3          range/width/length x +0.25
Shift+3    range/width/length x -0.25
4          cooldown x +0.15
Shift+4    cooldown x -0.15
5          duration x +0.25
Shift+5    duration x -0.25
6          speed x +0.25
Shift+6    speed x -0.25
7          enemy spawn count +4
Shift+7    enemy spawn count -4
Z          reset test parameters
```

Test-only entities:

```
011.json  high-HP player with fast regen
012.json  high-HP tentacle base with fast regen
013.json  low-pressure enemy dummy
```

Continuous attacks that should move with the player use:

```json
"motion": {
  "mode": "static",
  "duration": 2.0,
  "follow_source": true,
  "track_aim": true
}
```

`follow_source` keeps the hitbox attached to the source entity. `track_aim` recalculates aim while the attack is active, useful for mouse-directed melee, beams, and flamethrower style attacks.

Current attack mechanisms covered by JSON examples:

```
basic_projectile_test     homing projectile
melee_arc_test            mouse-directed melee sector
laser_test                player-following decay beam
flame_cone_test           player-following cone damage plus burn
lob_grenade_test          arcing projectile with arrival explosion
mine_delay_test           delayed area explosion
chain_lightning_test      chained target-to-target projectile
poison_aura_test          source-following aura plus poison ticks
control_seed_test         short control/charm status
orbit_seek_test           orbit first, then homing release
spike_nova_test           expanding circular hit shape
blackhole_test            force pull plus damage
boomerang_test            return-to-source projectile
bounce_rune_test          map-edge bouncing projectile
camera_edge_test          camera-edge projectile origin
split_shot_test           on-hit nested child bullets
```

Procedural attack visuals use optional `visual` fields:

```json
"visual": {
  "primary": "ff315d",
  "secondary": "ffe1c8",
  "alpha": 0.82,
  "pixel_count": 10
}
```

Healing skill example:

```json
{
  "kind": "attack_instance",
  "requires_target": false,
  "interval": 8.0,
  "origin": {"mode": "self_center"},
  "motion": {"mode": "static", "duration": 0.1},
  "hit_shape": {"mode": "circle", "radius": 260},
  "hit_rule": {"mode": "on_spawn_once"},
  "target_filter": {
    "relation": "ally",
    "include_self": true,
    "include_building": true
  },
  "effects": [
    {"mode": "heal", "value": 80}
  ]
}
```

Laser example:

```json
{
  "kind": "attack_instance",
  "interval": 5.0,
  "origin": {"mode": "self_center"},
  "aim": {"mode": "nearest_enemy"},
  "motion": {"mode": "beam", "duration": 2.4},
  "hit_shape": {"mode": "beam_rect", "length": 900, "width": 42},
  "hit_rule": {"mode": "while_active_tick", "tick_interval": 0.15},
  "effects": [
    {"mode": "damage", "value": 30}
  ]
}
```

Black-hole style pull example:

```json
{
  "kind": "attack_instance",
  "requires_target": false,
  "origin": {"mode": "camera_random_inside"},
  "motion": {"mode": "static", "duration": 4.0},
  "hit_shape": {"mode": "circle", "radius": 280},
  "hit_rule": {"mode": "while_active_tick", "tick_interval": 0.05},
  "effects": [
    {"mode": "force", "force_type": "pull_to_origin", "strength": 900, "falloff": "distance"},
    {"mode": "damage", "value": 4}
  ]
}
```

Nested attack example:

```json
{
  "mode": "spawn_attack",
  "max_depth": 4,
  "emitter_override": {"mode": "ring", "count": 4},
  "attack": {
    "kind": "attack_instance",
    "origin": {"mode": "target_center"},
    "motion": {"mode": "linear", "speed": 320, "life_time": 1.2},
    "hit_shape": {"mode": "circle", "radius": 12},
    "hit_rule": {"mode": "on_contact", "destroy_on_hit": true},
    "effects": [
      {"mode": "damage", "value": 12}
    ]
  }
}
```

`spawn_attack` carries `chain_depth`; use `max_depth` to stop recursive bullet nesting from exploding.

## Current Scripts

```text
res://BattleAssets/ScriptShader/BattleDirector.gd
res://BattleAssets/ScriptShader/BattleEntity.gd
res://BattleAssets/ScriptShader/BattleProjectile.gd
res://BattleAssets/ScriptShader/BattleAttackRunner.gd
res://BattleAssets/ScriptShader/BattleAttackInstance.gd
res://BattleAssets/ScriptShader/BattleEffectRunner.gd
res://BattleAssets/ScriptShader/BattleBioDrop.gd
res://BattleAssets/ScriptShader/BattleBioTransfer.gd
```

## Stage Event Additions

Battle stage events are intentionally lightweight. Use AVG or a scene switch for complex cutscenes.

Additional event conditions:

- `player_hp_below`: triggers when player HP ratio is below `amount`.
- `base_hp_below`: triggers when tentacle base HP ratio is below `amount`.
- `enemy_base_hp_below`: triggers when enemy base HP ratio is below `amount`.

Additional event action:

```ini
[event_after_win]
condition=win
action=play_avg|change_scene
avg_id=some_avg_id
scene_path=res://scenes/SomeNextScene.tscn
once=true
```

Existing simple actions remain: `play_avg`, `spawn_entity`, `add_base_bio`, `heal_player`, `heal_base`, `damage_enemy_base`, `win`, `loss`, and `area_fx`.

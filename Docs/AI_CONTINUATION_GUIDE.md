# Project L AI Continuation Guide

This document is for another AI/developer continuing work without deep prior context. The user mainly supplies art and design direction; code work should stay incremental and compatible with the current Godot project.

## Hard Rules

- Do not rewrite the battle architecture. Extend existing scripts and JSON/CSV data.
- The user does not use git. Be careful, test often, and avoid destructive edits.
- Main runtime scene family is `res://scenes/Battle/`.
- Prefer data-driven changes through:
  - `BattleAssets/*.json`
  - `Config/*.csv`
  - `scenes/Battle/*.ini`
- When changing runtime interfaces, update docs in `Docs/` and `BattleAssets/BATTLE_STAGE_EDITOR.md`.

## Key Files

- `BattleAssets/ScriptShader/BattleDirector.gd`
  - Stage loading, waves, objective/event system.
  - Player level choices, weapon upgrades, run stat upgrades.
  - Base/minion upgrade choices.
  - Equipment effect keys and equipment event MVP.
  - Skill/Mana MVP.
- `BattleAssets/ScriptShader/BattleEntity.gd`
  - Entity stats, visuals, movement, AI, base production queues, worker behavior, regeneration.
- `BattleAssets/ScriptShader/BattleAttackInstance.gd`
  - Modern attack instance system for bullets, beams, melee sectors, AOE, lobs, orbiting attacks.
- `BattleAssets/ScriptShader/BattleEffectRunner.gd`
  - Damage/heal/force/status/spawn-attack/chain-attack effects.
- `Config/Equipments.csv`
  - Out-of-battle equipment list. `effect_keys` is the runtime hook.
- `Config/Weapons.csv`, `Config/WeaponUpgrades.csv`, `Config/RunStatUpgrades.csv`
  - Weapon catalog, in-run weapon upgrades, generic stat upgrades.
- `BattleAssets/*.json`
  - Entity and attack definitions.
- `scenes/Battle/Battle_00.ini`
  - Current normal test stage.
- `scenes/Battle/Battle_BulletTest.tscn`
  - Debug scene for attacks/skills/entities.

## Current Implemented Battle Systems

### Player

- Entity JSON: `BattleAssets/000.json`.
- Fixed inputs:
  - Move: WASD / arrow keys.
  - Skill 1: `Q` / `N`.
  - Skill 2: `2` / `M`.
  - Pause: Space.
  - Aim: mouse.
- Player now has baseline HP regeneration in `000.json`.
- Mana is implemented in `BattleDirector`:
  - `player_mana_max`
  - `player_mana`
  - `player_mana_regen`
  - `run_mana_recovery_mul`
- Skills:
  - `Skill_player_overdrive.json`: channel buff, drains Mana, heals and buffs player.
  - `Skill_player_laser.json`: damage skill.
  - `Skill_camera_blast.json`: camera-wide non-building damage.
  - `Skill_tentacle_execute_rect.json`: frontal rectangular execute/heal skill.

### Base and Minions

- Base entity: `BattleAssets/001.json`.
- Base level cap currently 7.
- Base level art:
  - `033.gif`, `033_2.gif` ... `033_7.gif`.
  - Uses `visual.max_size`; image center equals entity/collision circle center.
- Base has HP regeneration in `001.json`.
- Base production queues are independent per minion type.
- If Bio is insufficient, queues still progress at low-power speed.
- High-level queues receive Bio first.
- Current Lv3 base option `mutation_gift` replaces the old touch-sync concept. There should be no touch-sync runtime or design dependency.

### Worker

- Worker entity: `BattleAssets/020.json`.
- Worker AI: `ai.mode = worker_collect_bio`.
- Worker behavior target:
  - Search nearby Bio within about 1.5x base alert radius.
  - Pick up.
  - Return to delivery center.
  - Deliver whenever cargo is not zero.
  - Wander when no cargo and no resource.
- Important bug fix:
  - Worker only pauses when an enemy physically overlaps/touches it.
  - It must not stop merely because enemies exist on camera or in the stage.
- Current worker pathing is steering, not full navigation. Occasional stuck behavior may still need future pathfinding.

### Assimilation

- Assimilator minion: `BattleAssets/024.json`.
- In-progress animation: `024_1.gif`.
- Result entity: `BattleAssets/027.json`.
- Runtime flow:
  - `BattleEntity` melee attack with `assimilate_result_entity_id`.
  - `BattleDirector.start_assimilation()`.
  - `spawn_assimilation_fx()`.
  - `process_assimilations()` spawns result at same position.
- To make the process visible in current MVP:
  - `024.json` has faster move/attack and shorter assimilation duration.
  - Lv5 base unlock queue for `024` is faster and cheaper.

## Equipment System

Equipment is not out-of-battle upgrade. Out-of-battle upgrades should be mostly positive numeric growth. Equipment should be "mechanic plus debuff".

### Data

- CSV: `Config/Equipments.csv`.
- Runtime reads selected equipment from `battle_loadout.equipment_id`, default `E001`.
- Effects are registered by `effect_keys`, separated by `|`.

### Current Equipment Event API

Implemented in `BattleDirector.emit_equipment_event()`:

- `on_battle_start`
- `on_player_moved`
- `on_player_stopped`
- `on_attack_fired`
- `on_attack_hit`
- `on_bio_delivered`
- `on_enemy_killed`
- `on_minute_tick`
- `filter_weapon_choice` style behavior is currently implemented through `is_weapon_allowed_by_equipment()`.

Debug state:

- `equipment_event_counts`
- `equipment_last_event_payloads`

### Current Equipment Effects

- `hide_enemy_hp`
- `enemy_hp_random_up`
- `lust_reward_up`
- `mana_recovery_up`
- `crit_rate_down`
- `player_regen_down`
- `minute_lust_add`
- `base_bio_cycle_yield_up`
- `skill2_full_mana_required`
- `whip_charge`
- `whip_weapon_penalty`
- `player_speed_down_big`
- `range_weapon_only`
- `bind_area_boost`
- `liquid_madness`
- `forced_forward_move`
- `player_speed_up_small`
- `player_hp_down_big`
- `exhibitionist`
- `melee_lifesteal`

### Current Equipment Rows

- `E001`: Empty.
- `E002`: Blindfold. Hide enemy HP, enemy HP random up, lust multiplier.
- `E003`: Nipple conductor. Mana regen up, crit down.
- `E004`: Tentacle ring. Regen down.
- `E005`: Slime belt. Minute lust add, base Bio cycle yield up.
- `E006`: Magic breast crest. Skill 2 requires full Mana.
- `E007`: Whip. Move to charge, stop to release `Attack_equipment_whip_slash.json`, normal weapon damage down.
- `E008`: Binding suit. Speed down, area weapon only, area boost.
- `E009`: Liquid madness. Every 5 sec loses 10% current HP and fires `Attack_equipment_liquid_arc.json`.
- `E010`: Plug. Cannot naturally stop; keeps moving in last input direction.
- `E011`: Exhibitionist. Big max HP down, small offensive gains.
- `E012`: Melee mark. MVP adds life steal to held weapons.

## Attack Visual Rules

- Modern attacks should prefer `BattleAttackInstance.gd`.
- Attack JSON `visual.texture` and `visual.gif` are supported.
- Beam textures are stretched to beam `length` and `width`.
- Melee image anchor:
  - Use `"anchor": "left_center"` in `visual`.
  - Default art faces right.
  - The image left edge center binds to the attack origin when facing right.
  - When attacking left, rotation mirrors the effective binding so the visual edge still attaches to the character.
- Current melee attacks:
  - `Attack_weapon_strong_melee.json`: facing direction, `StrongMelee.png`.
  - `Attack_weapon_mid_melee.json`: facing direction, `NormalMelee.png`.
  - `Attack_weapon_weak_melee.json`: mouse direction, `WeakMelle.png`.

## Performance Notes

Godot currently struggles when many entities, GIFs, attacks, and nested effects are active.

Implemented mitigations:

- `stage.max_active_entities_soft` in `.ini`.
  - Current `Battle_00.ini` value: `72`.
  - Enemy wave spawning waits while active entity count is above this soft cap.
- Unit contact processing now checks distance before worker pause/contact handling.
- Floating numbers are capped per frame.

Future AI should avoid increasing unit count blindly. Prefer:

- Stronger units.
- Longer spawn intervals.
- Fewer independent visual FX nodes.
- Shorter attack lifetimes.
- Reusing attack instances rather than spawning many nested effects.

## Stage Objectives and Events

Implemented win conditions:

- `destroy_enemy_base`
- `survive_time`
- `reach_area`
- `escort_entity`
- `kill_count`
- `kill_entity_id`
- `hold_area`
- `activate_areas`

Implemented event conditions:

- `time`
- `player_enter_area`
- `kill_count`
- `win`
- `loss`
- `player_hp_below`
- `base_hp_below`
- `enemy_base_hp_below`

Implemented event actions:

- `play_avg`
- `spawn_entity`
- `add_base_bio`
- `heal_player`
- `heal_base`
- `damage_enemy_base`
- `win`
- `loss`
- `area_fx`
- `change_scene`

For complex story/cutscene flow, use `play_avg` or `change_scene` instead of building RTS-like scripted sequences inside battle.

## Recommended Next Work

### Out-of-battle Upgrade UI

The user wants tabs/pages:

- Player
- Base
- Minions
- Basement/captives

Data should be CSV-driven. Nodes may have `0/N` levels. Some nodes require prerequisites and may be hidden until prerequisite unlocked.

Use existing save APIs:

- `Script/SaveMgr/GameState.gd`
- `unlock_item`
- `is_unlocked`
- `set_upgrade_level`
- `get_upgrade_level`

Do not create a new save system.

### Basement/Captive System

Likely should produce:

- Equipment unlocks.
- Next-run temporary modifiers.
- Lust economy sinks.
- AVG scenes.

Keep it separate from permanent upgrade math. Equipment can feed into `Config/Equipments.csv` and `battle_loadout.equipment_id`.

### More Equipment

Add rows to `Config/Equipments.csv`, then implement `effect_keys` in:

- `load_battle_loadout`
- `apply_loadout_to_player`
- `apply_equipment_to_player_attack`
- `process_equipment_events`
- `process_equipment_timers`
- `is_weapon_allowed_by_equipment`

Prefer reusing attack JSON and event hooks.

### Battle Bugs to Watch

- Worker can still occasionally get stuck due to steering-only pathing.
- If performance drops, reduce GIF count or lower `max_active_entities_soft`.
- Check that base art visually lines up with collision center after art replacement.
- Check that melee anchored visuals feel correct for both left/right facing.


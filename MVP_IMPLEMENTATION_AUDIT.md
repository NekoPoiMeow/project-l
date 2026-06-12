# Project-L MVP Implementation Audit

> Purpose: keep future content work from silently drifting into “CSV says it exists, but code does not.”
> Scope: current pushed MVP baseline after equipment/weapon rescue pass.
> Rule: future breakthroughs should be isolated modules or small adapters; do not rewrite the current battle/save/outgame spine unless a blocker proves unavoidable.

## 0. Status Legend

| Mark | Meaning | Action |
|---|---|---|
| ✅ Mechanic wired | Runtime code exists and can be tested now | Tune numbers / art / UX later |
| 🟡 Placeholder or partial | Data and route exist, but implementation is simplified | Safe for MVP if documented |
| 🔴 Missing mechanic | Data claims behavior but code should still be added | Add isolated handler only |
| 🎨 Missing presentation | Logic works, but visual/audio/readability is weak | Art/content pass later |
| 🧪 Needs regression test | Mechanic was recently fixed or is fragile | Test before using in formal content |

## 1. Core Rule Going Forward

The current architecture should be treated as the MVP backbone:

- Save/GameState is the truth for persistent progress, unlocks, loadout, temporary merchant effects, dungeon materialized equipment.
- BattleDirector reads loadout/modifiers and performs combat runtime.
- Merchant/Dungeon/Level/Story systems feed unlocks and next-battle state into GameState.
- Do not rewrite battle architecture for a single weapon/equipment. Add a local adapter, isolated handler, or per-mechanic config instead.

Future “breakthrough” work should be listed separately before coding:

1. What exact bug or content blocker does it solve?
2. What files does it touch?
3. Can it be implemented as an isolated function/scene/config?
4. What regression list must be tested afterward?

## 2. Weapons.csv Audit

Source table columns: `id,name,unlocked,attack_id,weapon_type,tags,description`.

| ID | Name | Status | Notes / Next Work |
|---|---|---|---|
| W001 | 直线弹 | ✅ Mechanic wired | Standard manual projectile. Needs only feel/art tuning. |
| W002 | 追踪弹 | ✅ Mechanic wired | Homing behavior exists. Later tune tracking and target priority. |
| W003 | 狙击弹 | ✅ Mechanic wired | Pierce/ricochet behavior exists. Later tune visual clarity. |
| W004 | 曲线弹 | ✅ Mechanic wired / 🧪 | Short parabolic throw fixed recently. Avoid changing shared projectile visuals globally. |
| W005 | 强近战 | ✅ Mechanic wired | Public melee visual/range may need independent config later. |
| W006 | 中近战 | ✅ Mechanic wired | Same as above. |
| W007 | 弱近战 | ✅ Mechanic wired | Same as above. |
| W008 | 地刺 | ✅ Mechanic wired | Range/size tune later. |
| W009 | 轻轰炸 | ✅ Mechanic wired / 🧪 | Box fixed; random small AOE in box. Do not convert to projectile drift. |
| W010 | 重轰炸 | ✅ Mechanic wired / 🧪 | Box fixed; delayed full-box strike. |
| W011 | 魅惑控制 | ✅ Mechanic wired / 🎨 | Logic exists; presentation and exact control readability can improve. |
| W012 | 毒圈 | ✅ Mechanic wired / 🎨 | Logic exists; poison stack readability can improve. |
| W013 | 喷火 | ✅ Mechanic wired / 🎨 | Cone/tick logic exists; flame art/damage footprint readability later. |
| W014 | 闪电链 | ✅ Mechanic wired / 🎨 | Chain logic exists; line visual can become clearer. |
| W015 | 回旋镖 | ✅ Mechanic wired | Tune return path and hit readability later. |
| W016 | 随机落雷 | ✅ Mechanic wired | Needs content stress test when many enemies. |
| W017 | 火箭弹 | ✅ Mechanic wired / 🧪 | Explosion route fixed; keep BattleAttackRunner projectile route guard. |
| W018 | 霰弹 | ✅ Mechanic wired / 🎨 | Falloff/spread exists but needs obvious visual/feel pass. |

### Weapon Follow-up Policy

- Do not use one public helper to reshape all weapon visuals/ranges.
- Split future weapon presentation into per-weapon normalizers, for example:
  - `configure_weapon_curve_shot()`
  - `configure_weapon_light_bombard()`
  - `configure_weapon_heavy_bombard()`
  - `configure_weapon_flame_spray()`
- Keep “200 active entities OK” as MVP performance target. Do not reintroduce the abandoned data-swarm rewrite.

## 3. Equipments.csv Audit

Source table columns: `id,name,unlocked,icon,description,effect_keys`.

| ID | Name | effect_keys | Status | Notes / Next Work |
|---|---|---|---|---|
| E001 | 空装备 | - | ✅ | No-op. |
| E002 | 马眼罩 | `hide_enemy_hp`, `enemy_hp_random_up`, `lust_reward_up` | ✅ / 🎨 | Logic exists. Could add stronger UI warning that enemy HP bars are hidden intentionally. |
| E003 | 乳环导体 | `mana_recovery_up`, `crit_rate_down` | ✅ / 🧪 | Console shows mana multiplier and crit reduction. Re-test after skill channel fix. |
| E004 | 触手戒指 | `player_regen_down` | ✅ / 🎨 | Mechanic is only downside currently. “More aggressive sync interface” needs future positive/visual identity if desired. |
| E005 | 粘液束带 | `minute_lust_add`, `base_bio_cycle_yield_up` | ✅ / 🎨 | Console confirms minute lust and base biomass. Needs visible pulse/tooltip later. |
| E006 | 魔乳纹章 | `skill2_full_mana_required` | ✅ / 🧪 | Skill 2 full-mana gate exists. Skill 1 channel was fixed into short burst; regression test recommended. |
| E007 | 小皮鞭 | `whip_charge`, `whip_weapon_penalty` | ✅ | Input-based charge, stop-release, repeat charge works and is fun. Keep isolated. |
| E008 | 拘束服 | `player_speed_down_big`, `range_weapon_only`, `bind_area_boost` | ✅ | Forces area/range tendency and boosts area. Needs upgrade-pool regression. |
| E009 | 射液狂 | `liquid_madness` | ✅ / 🎨 | Periodic HP cost + penetrating liquid shot exists. Visual could improve. |
| E010 | 阴肛塞 | `forced_forward_move`, `player_speed_up_small` | ✅ | Forced drift/forward movement exists. Needs long-run playtest for frustration. |
| E011 | 暴露癖 | `player_hp_down_big`, `exhibitionist` | ✅ | HP down + offensive bonuses. Tune later. |
| E012 | 近战淫纹 | `melee_lifesteal` + implicit melee-only | ✅ | Forces melee tendency and lifesteal. Current test looked OK. |

### Captive Materialized Equipment

| Family | IDs | Status | Notes |
|---|---|---|---|
| Knight | `E_CPT_KNIGHT_LV0..LV3` | ✅ / 🧪 | Player damage/range/minion attack hooks. Needs multi-level dungeon materialization test. |
| Witch | `E_CPT_WITCH_LV0..LV3` | ✅ / 🧪 | Mana/attack frequency/liquid madness hooks. Needs skill/Mana regression. |
| Princess | `E_CPT_PRINCESS_LV0..LV3` | ✅ / 🧪 | Initial biomass, lust reward, base queue speed hooks. Needs base-heavy level test. |
| Priest | `E_CPT_PRIEST_LV0..LV3` | ✅ / 🧪 | Lust reward, range, player defense hooks. Needs defense damage test. |

### Equipment Known Gaps

- E004 has weak identity: it is currently mostly a regen-down downside.
- E005 and some captive equipment need obvious visual/UI feedback.
- Equipment audit should remain in console until content locks; missing effect keys must stay noisy.

## 4. TemporaryItems.csv Audit

Merchant temporary next-battle items are all simple modifier hooks and should remain simple.

| ID | effect_key | Status | Notes |
|---|---|---|---|
| TMP_ATK_001 | `player_attack_mul` | ✅ | Source breakdown prints as merchant. |
| TMP_RATE_001 | `player_attack_frequency_mul` | ✅ | Source breakdown prints as merchant. |
| TMP_AREA_001 | `player_area_mul` | ✅ | Source breakdown prints as merchant. |
| TMP_RANGE_001 | `player_range_mul` | ✅ | Source breakdown prints as merchant. |
| TMP_LUST_001 | `battle_lust_reward_mul` | ✅ | Source breakdown prints as merchant. |
| TMP_BIO_001 | `base_start_bio_add` | ✅ | Source breakdown prints as merchant. |

Rule: do not add complex behavior to TemporaryItems unless it is intentionally a special event item. Use normal equipment or upgrades for complex behavior.

## 5. Dungeon / Captive Audit

### Captives

Current captive rows:

- `CPT_KNIGHT_001` -> `E_CPT_KNIGHT`
- `CPT_WITCH_001` -> `E_CPT_WITCH`
- `CPT_PRINCESS_001` -> `E_CPT_PRINCESS`
- `CPT_PRIEST_001` -> `E_CPT_PRIEST`

Status: ✅ data exists, ✅ materialized equipment family exists, 🧪 needs full outgame-to-battle test.

### Dungeon Actions

| ID | Status | Notes |
|---|---|---|
| passive | ✅ | Captive-only passive processing. |
| train | ✅ / 🧪 | Requires actor + item + captive. Special combo events route through DungeonEvents. |
| materialize | ✅ / 🧪 | Produces next-battle captive equipment. Needs repeated save/load test. |

### Dungeon Events

Current event table is good enough for MVP, but intentionally sparse:

- Generic Knight + Dragonhead.
- Princess + Knight + Dragonhead special one-time event.
- Generic Princess + Dragonhead.
- Generic Witch + Syringe.
- Hero + Witch + Syringe special one-time event.

Status: ✅ route exists, 🟡 content sparse, 🎨 CG/AVG placeholder until art pass.

## 6. StoryEvents / Gallery Audit

Current StoryEvents rows include merchant and dungeon CG placeholders. Status:

- ✅ Story event IDs exist.
- ✅ DungeonEvents can reference StoryEvents.
- ✅ Gallery/StoryTeller route previously recovered.
- 🎨 Most paths are placeholder art/AVG resources.

Future story content should add rows first, then connect unlock source:

1. `StoryEvents.csv` row.
2. Unlock source: Level clear / DungeonEvent / Merchant event / Story flag.
3. Gallery display test.
4. Save/load test.

## 7. Level.csv Audit

Current level map has four rows:

| ID | Name | Unlock | Reward | Status |
|---|---|---|---|---|
| L001 | 海岸入口 | initially unlocked | `CPT_KNIGHT_001` | ✅ skeleton |
| L002 | 废弃码头 | unlocked, gated by `L001_CLEAR` semantics | `CPT_PRIEST_001` | ✅ skeleton |
| L003 | 潮汐洞窟 | `L001_CLEAR` | `CPT_WITCH_001`, special `CPT_PRINCESS_001` | ✅ skeleton |
| L004 | 雾中高塔 | `L002_CLEAR|L003_CLEAR` | `CPT_WITCH_001` | ✅ skeleton |

Needs next:

- Make sure each `scene_path` exists and can enter/exit.
- Make sure clear reward unlocks correct captive exactly once.
- Make sure `next_ids` and `unlock_flag` agree with GameState progress flags.
- Add 3 formal MVP stages before expanding: tutorial, base-defense, story-unlock.

## 8. Upgrade CSV Audit

### RunStatUpgrades.csv

Current run stat upgrades are simple scalar ops:

- max HP add.
- global damage add.
- bonus damage add.
- crit up.
- mana recovery multiplier.
- lust reward add.

Status: ✅ simple ops, 🧪 needs check with equipment modifiers after v22.

### WeaponUpgrades.csv

WeaponUpgrades contains many `stat_ops` and many `mechanic_id` branch ideas. Status should be considered mixed:

- ✅ scalar `stat_ops` are likely MVP-safe when mapped by existing upgrade application code.
- 🟡 / 🔴 many `mechanic_id` branches are design entries and may not have bespoke runtime behavior yet.

Important: before using weapon upgrade branches in formal progression, run a specific `mechanic_id` audit. Any row with non-empty `mechanic_id` must be treated as “not guaranteed” unless a runtime handler is confirmed.

## 9. MVP Content Production Checklist

Before adding a formal playable level:

- [ ] Scene loads from `Level.csv.scene_path`.
- [ ] Has a clear win condition.
- [ ] Battle settlement returns to outgame.
- [ ] Reward/unlock is visible in save and UI.
- [ ] Save/load after reward keeps unlock.
- [ ] Merchant/dungeon/story state remains valid.
- [ ] No `[EquipmentAudit][MissingEffect]` or missing attack JSON logs.
- [ ] Enemy count target: 100 safe, 200 acceptable, above 200 only stress/debug.

Before adding a formal story/CG:

- [ ] StoryEvents row exists.
- [ ] Unlock source exists.
- [ ] Placeholder art path is valid or intentionally fallback.
- [ ] Gallery can show it.
- [ ] Save/load keeps it unlocked.

## 10. Do Not Touch Without Reason

Avoid broad rewrites of:

- Save schema.
- BattleDirector main loop.
- Entity rendering/batching spine.
- GameState migration rules.
- Merchant/dungeon bridge.

Allowed changes:

- Add isolated weapon/equipment handler.
- Add content rows.
- Add one level scene/config.
- Add UI panel/entry button.
- Add debug/audit print.
- Add fallback visual for missing art.

# Project L AI Continuation Guide — Updated 2026-06-11

This is the updated handoff guide for continuing Project L. The old guide is now stale. Use this file as the current project memory and decision guide.

The user is a non-programmer building a Godot 4 Vampire-Survivors-like / light base-mode game with heavy AI help. They can replace files and test, but they do not want vague advice or big rewrites. Prefer concrete patches, exact paths, and small verifiable steps.

## 0. Tone and workflow

- Reply in Chinese.
- The user is tired and frustrated, but still actively designing. Be direct and useful.
- Do not suggest gutting the concept, making it AVG-only, removing the base/minion system, or “doing subtraction” in a way that kills the fantasy.
- When coding, provide replacement files or a zip patch whenever possible.
- When debugging, ask for the first red error and exact line if no source is available.
- The user now has a GitHub repo: `https://github.com/NekoPoiMeow/project-l`. Connected GitHub access worked in this conversation. Use GitHub when asked to inspect repo state.
- The user has no reliable stable version management locally. Assume many local zips/scripts may be layered and confused. Be careful to avoid reintroducing abandoned experiments.

## 1. Current high-level game identity

Project L is not pure AVG and not a full RTS. It is primarily:

- 2D top-down pixel-ish Vampire-Survivors-like combat.
- Some battle stages use a “base / node / root anchor” system.
- Outgame loop includes camp, merchant, dungeon/captives, upgrades, loadout, battle result.
- Erotic/horror/fantasy direction: tentacle suit / bio-latex / beautiful girls / mobile nest / captives / dark fantasy.
- Visuals are allowed to be rough in gameplay. Important CG and concept art can be AI-assisted and later cleaned by artist.

The user understands the game will be modest. Do not plan giant maps or AAA RTS scenes. Actual battle maps should be small symbolic arenas with a strong theme.

## 2. Current story/world direction — frozen draft

### One-line core

The story happens on a fragment of a huge abandoned artificial ecological structure, not a natural planet. Resource circulation is failing. Girl-shaped civilizations live around large bio-nodes. Tentacles are an old ecological maintenance/recycling system. The black-haired protagonist is an unstable “black-rainbow backdoor” who crudely reconnects broken interfaces through touch, desire, capture, and nest-building.

### Setting

The world is a partial shard of a giant artificial construct, possibly:

- A colony ship fragment.
- A terraforming ark module.
- A derelict orbital ecology station.
- A bio-engine room / agricultural habitat.
- A forgotten artificial waste/resource recycling zone.

People in the world mostly do not know this. They call ruins, pipelines, broken horizon walls, ecological cores, and artificial skies “the world”.

The surface culture looks like kingdoms, churches, magic academies, merchants, queens, knights, princesses. The underside is broken artificial ecology, biological recycling, root networks, outdated interfaces, and failing resource loops.

### Why all girls / why beautiful girl forms

“Beautiful girl civilization” is not natural evolution. It is a pathological mimicry produced by the old tentacle ecology after losing its original human controllers.

Old templates mixed together:

- Maid robots.
- Caregiver / medical androids.
- Companion interfaces.
- Priestess / queen / ceremony templates.
- Colony management avatars.
- Comfort/personality shells.

The tentacle system used these templates to create stable “girl shells”. These shells gave the ecology language, shame, love, roles, nations, professions, and identity. The shell is both a disease and a civilization.

Avoid making this a simple “bloodline” or “futa is the universal best answer” explanation. Sex/gender traits are unstable interface remnants, not destiny or noble lineage.

### Tentacles

Tentacles are not pure evil. They are an old maintenance/recycling ecology:

- Recycle waste and dead matter.
- Recompile biomass.
- Repair habitat functions.
- Connect root networks.
- Maintain survival nodes.
- Convert bodies, buildings, and identities when malfunctioning.

They are useful because they let everyone survive longer on a resource-limited fragment. They are feared because they violate body boundaries, identity boundaries, and social order.

### Resource logic

- **Biomass**: common ecological substrate, not just meat. It can be waste, minerals, pollen, slime, corpses, water, microbes, and residues recompiled into food, buildings, minions, nest fuel, outfits, and repairs.
- **Lust energy / 淫能**: high-density synchronization energy created by intense emotion, intimacy, dominance/submission, shame, and loosened identity boundaries. Used for outgame upgrades, dungeon synchronization, capture interface opening, temporary effects, and nest growth.
- **Node permissions**: each settlement survives around a bio-node that controls air, water, food, biomass flow, root roads, ceremony, and local identity systems.

## 3. Protagonist — current design lock

Main character is currently the strongest locked design.

### Core

- Adult but visually young/petite. Do not make her a child in adult scenes.
- Black hair is mandatory. Do not change this.
- Hair becomes “五彩斑斓黑” when emotion/lust energy rises: black like oil film / raven feather / black shell, with purple, cyan, blue, pink, gold iridescent highlights.
- Small frame, flat or small chest, not tomboy, not mature big-sister.
- Looks harmless at first but is actually a stubborn mountain gremlin / bad kid / little mad dog.
- She does not cry softly. If she cries, it is angry, unwilling, hidden, and prideful.
- She likes pretty girls, is handsy, vulgar, and chaotic, but has a hard bottom line.

### Childhood core

Do not use “tear bullet” as fixed canon unless user re-approves it. Better opening concept:

- As a kid she used a short twig and got beaten back by kids with longer sticks.
- She was bullied/excluded unconsciously because she was strange.
- She fought back and made things worse.
- She hid alone, angry and unwilling, not soft crying.
- A mysterious sickly eyepatched older sister / mountain big sister found her and took her in.

Short twig is an important symbol:

- Childhood weapon.
- Later root/tentacle weapon metaphor.
- “It was too short, so she grew longer roots.”

### Adult combat identity

She does not really use weapons. Her unstable body attacks first.

- Wants to hit far -> root/tentacle stretches.
- Wants to grab -> shadow roots move first.
- Wants protection -> bio-suit wraps her.
- Wants to drag someone home -> body searches for an interface.

Her unique ability is not holy destiny or bloodline. It is an ugly, unsafe, incompatible “backdoor”. She can reconnect broken systems because she is non-standard enough to brute-force their hooks.

Possible ability names:

- 黑虹后门
- 黑虹同步
- 野蛮握手
- 根网越权
- 全窝越权同步

## 4. Foster mother / mysterious big sister

The foster mother / “笨蛋触手老母” is not a perfect omniscient mother-brain.

She is more like an old ship engine / bio-reactor / mother-nest power core:

- Very strong.
- Ancient.
- Sickly, eyepatched, memory-broken.
- Often calls wrong interfaces.
- Can supply power, repair, grow roots, and incubate, but cannot operate new girl-personality OS cleanly.
- Looks like a beautiful sickly mature woman with eyepatch, white/pale hair, purple-white-black ornate tentacle/bio-latex design.

She should feel like:

- “I used to know this.”
- “Call failed.”
- “Parameter missing.”
- Then sleeps.

She gives the protagonist a simple bottom line, not a sermon:

> You can grab, you can make trouble, you can bring what you like back to your nest, but do not break a crying heart beyond repair.

## 5. Base mode / node war explanation

Do not call it “RTS base” in story. Call it:

- 节点战
- 扎根战
- 根锚战

### Player base

The player “base” is the mobile nest crawler / mobile mother-nest extending a temporary **root anchor** into the battlefield.

- Mobile nest stays outside or behind the scene.
- Battle base = root anchor inserted into field.
- If root anchor is destroyed, protagonist retreats.

### Enemy base

Enemy base is the local survival node, not just a building.

Examples by faction:

- Kingdom: flower-crown tree, royal grafting tree, wedding holy tree.
- Church: holy root tower, purification altar, white-flower cathedral.
- Magic academy: greenhouse mother tree, experiment root furnace, ancient interface array.
- Queen: garden fortress, throne root network, crown-branch relay.
- Resource recyclers: dismantling anchor, scan beacon, cleanup terminal.

### Units

Player minions are not full “soldiers”. They are short-lived execution bodies produced by the root anchor:

- 眷须
- 根蜂
- 工蜂
- 短命执行体
- 黑虹眷属

Enemy units are execution bodies or troops generated/organized by their local node.

This explains why gameplay can have many low-fps low-detail units. Most are not full characters. Full personality is reserved for bosses/captives/core characters.

## 6. Combat / level scale reality

The game is a modest 2D top-down pixel-ish Vampire-Survivors-like, not a large RTS.

Actual maps should be simple symbolic arenas:

- One central enemy node.
- One player root anchor.
- 2–3 spawn gates.
- A few decorative blockers/ruins.
- Themed floor tile.
- Boss/elite entry point.

A stage can imply a huge world using borders and props, but the playable area should remain small.

Recommended first node-war map:

- Theme: ruined royal wedding courtyard.
- Ground: cracked stone, petals, red carpet scraps.
- Enemy node: flower-crown tree core / wedding graft node.
- Player base: black-purple root anchor.
- Spawns: broken arch, torn wedding curtain, upper altar gate.
- Boss: giant-breasted white-rose oath knight.

## 7. Gameplay art reality

The user’s gameplay pixel art should be **large-particle simple sprites**, not detailed pixel painting.

Reference vibe: tiny VTuber running sprite like Shirakami Fubuki GIF — few frames, big readable silhouette, minimal motion.

Combat sprite rules:

- 32x32, 48x48, or 64x64 style.
- Few frames, 2–4 frames is enough.
- No real walking if too hard. Use idle-bounce / bobbing.
- Body moves 1–2 px.
- Hair / tail / tentacle / scarf moves more than legs.
- Face stable.
- Legs can be almost static.
- Attack animation can be flash, front lean, or skill effect.
- Death can be universal flower/slime/biomass burst.

For protagonist battle sprite, reduce details:

- Black hair big silhouette.
- Purple eyes as few pixels.
- White/black body block.
- 1–2 thick shadow roots/tentacles.
- Short twig/root branch if needed.
- Two iridescent hair highlights.

DALL·E is bad at consistent pixel frames. Use it for inspiration/mother designs, not production-ready frames. If trying AI, ask for one static mother sprite, then hand-edit frames.

## 8. AI art pipeline notes

DALL·E is good at:

- High-detail CG inspiration.
- Story CG drafts.
- Character design sheets.
- Atmospheric moonlit scenes.
- Complex tentacle/bio-ornament compositions.
- Scene concept art.

DALL·E is bad at:

- Consistent multi-frame pixel sprites.
- Same-face multi-CG series without manual correction.
- Precise transparent spritesheets.
- Complex material logic that must be physically consistent.

Flux / SD / image-to-image workflows may be better for:

- Consistency.
- Repainting clothing/materials.
- Latex/bio-suit material refinement.
- Adult-oriented variants or niche XP refinements outside DALL·E’s safe generation behavior.

Artist should lock:

- Final faces.
- Hands/body structure.
- Character identity marks.
- Clothing logic.
- Final production sprites/CG.

DALL·E should be used as “composition and luxury-detail lottery”, not final production guarantee.

## 9. Current generated character concepts

Current design sheets generated/liked:

- Main protagonist design sheet: black-haired petite protagonist with iridescent black hair, white/black bio-suit, shadow/tentacle elements.
- Foster mother / 紫渊之母: white/purple ornate mature tentacle mother, eyepatch/sickly old-core direction should be preserved.
- Slime merchant: cyan/blue slime girl merchant, playful, shop/travel/outfit variations.
- White rose oath knight: big-breasted white/gold knight with ceremonial wedding/rose vibe.
- Witch researcher sheet generated too refined and too elegant; user rejected this direction.

### Witch researcher correction

Do not make the witch too graceful or scholarly. User wants:

- Athletic / sports-girl research style.
- Landmine / yandere / mad-scientist energy.
- Some nurse outfit influence.
- Rough, energetic, dangerous, not elegant.
- “体育生的思维做研究”: she treats experiments roughly because she thinks like an athlete/trainer, not a calm scholar.

Safe prompt terms for generation should avoid high-risk words. Use:

> athletic dark-fantasy researcher, black-purple sports jacket, medical-white coat elements, energetic mad-scientist expression, test tubes, clipboard, greenhouse laboratory accessories, fully clothed, character design sheet

## 10. Key characters and route logic

Each major faction/character represents a way to “fix” the broken world.

### Protagonist — black-rainbow backdoor

Non-standard, crude, erotic/physical, brute-force interface reconnection.

### Queen — normalization

Forces everyone to obey a stable girl-civilization OS. Sacrifices freedom for stability.

### Church — pruning

Cuts incompatible parts. Sacrifices complexity for purity.

### Magic academy / witch — documentation calling

Reads broken ancient docs and calls old interfaces. Believes in knowledge, underestimates unknown.

### Slime merchant — external patch

Sells outside protocols, temporary buffs, disguise shells, gray-market patches. Sacrifices purity for efficiency.

### Foster mother — old engine

Huge power, outdated interfaces, broken memory.

## 11. Captives / dungeon logic

Captives are not just rewards. They are living interfaces from different girl/tentacle architectures.

Dungeon actions:

### 放置

Mobile nest automatically wraps/maintains captives and absorbs overflow emotion/lust energy.

- High lust gain.
- Low humiliation growth.
- Captive does not need active acceptance.

### 调教

High-bandwidth synchronization among protagonist, tool, and captive. Can be H, ritual, dream, memory replay, bio-suit fitting, or interface calibration.

- Low lust gain.
- Medium humiliation growth.
- Unlocks CG/events/interface.

### 物化

Captive’s architecture fragment / personality shadow / organ blueprint is temporarily grafted onto protagonist for next battle.

- No lust gain.
- High humiliation growth.
- Adds temporary mechanic/equipment-like effect.
- Captive still exists.

Humiliation level is not simply moral shame. It measures how much the captive accepts that her “identity shell” is also a connectable root/interface.

## 12. Captive writing style

Do not give every captive a deep redemption arc. Use tiers.

- Normal captive: short bio, Lv0–3 humiliation text, generic CG tag.
- Special captive: unique tool reaction, materialization effect, some event text.
- Chapter captive: complete mini-route.

Do not make every route “growth”. Mix:

- Growth type: knight learns a fighting style that fits her body, not ceremonial rules.
- Reversal type: witch becomes her own experimental subject and learns method limits without moral preaching.
- Chaos type: princess becomes sadistic dungeon assistant; no need for moral growth.

## 13. Current outgame systems implemented in patches

Several systems exist as placeholders and likely need refinement tomorrow.

### Basement / camp

- Basement has portals to outgame upgrade, dungeon, merchant.
- Existing placeholder art reused.
- Portal script: `Script/Basement/BasementPortal.gd`.
- Scene: `scenes/Basement.tscn`.

### Outgame upgrade

- Scene: `scenes/OutGame/OutGameUpgrade.tscn`
- Script: `scenes/OutGame/OutGameUpgrade.gd`
- CSV: `Config/OutGameUpgrades.csv`
- Tabs: player, base, minion, dungeon.
- Node graph with branch lines exists.
- Upgrades spend lust and call save.
- Some effect keys are hooked; many still need battle/dungeon/merchant integration.

Known previous fixes:

- `to_local()` parse issue fixed with canvas transform inverse.
- Variant-inferred-as-error line fixed by explicit float dir.
- CSV position should use `x|y`, not comma.
- Removed fake battle floating text “淫能 +20”.
- Battle reward is kill/entity based.

### Merchant

- Scene: `scenes/Merchant/Merchant.tscn`
- Script: `scenes/Merchant/Merchant.gd`
- CSV: `Config/MerchantGoods.csv`
- Tabs: temporary next-battle effects, captive goods, walk/date event placeholder.
- Purchases should save with `GameState.save_progress_now()`.
- Temporary effects stored in `next_battle_effects` and consumed/cleared after battle.
- Merchant concept: slime girl, friend-with-benefits, gray market patch seller, external protocol adapter.

### Dungeon

- Scene: `scenes/Dungeon/Dungeon.tscn`
- Script: `scenes/Dungeon/Dungeon.gd`
- CSVs: `Config/DungeonCaptives.csv`, `Config/TortureItems.csv`, `Config/Characters.csv`
- Actions: place, train/sync, materialize.
- Operations save progress.
- AVG currently only writes `pending_avg_event` metadata; actual AVG routing needs implementation.

### GameState

- File: `Script/SaveMgr/GameState.gd`
- Contains lust, loadout, upgrades, progress, unlocks, dungeon captives, next battle effects, autosave/manual save helpers.
- `save_progress_now(reason)` was added to write both autosave and manual slot.
- Debug direct-running scenes can still cause save confusion if no save is loaded; `ensure_loaded()` was improved to prefer existing Save1 when possible.

## 14. Tomorrow development priorities

The user plans to improve merchant, dungeon, and outgame upgrades with placeholders before deeper stage testing.

Recommended order:

1. **Stabilize save/load behavior across Basement -> Merchant -> Dungeon -> Outgame -> Battle -> Result.**
   - Do not overwrite progress when directly running scenes for debug.
   - Make each scene call `GameState.ensure_loaded()` safely.
   - Make all purchases/upgrades/actions call `save_progress_now()`.

2. **Create/verify chapter/progress table.**
   - Needed for merchant goods unlocks, captive unlocks, dungeon item unlocks, stage progression.
   - Add `Config/Chapters.csv` or equivalent.
   - Minimal fields: `chapter_id`, `title`, `unlock_condition`, `default_stage`, `merchant_level`, `dungeon_level`, `notes`.

3. **AVG event router placeholder.**
   - Scenes write `pending_avg_event` now.
   - Need a safe router that can either:
     - go to existing AVG scene if path known, or
     - show placeholder event page with title/text/return path.
   - Add `Config/AVGEvents.csv` mapping event_id -> title -> text -> cg path -> return scene.

4. **Outgame upgrade effect key integration.**
   - Audit `Config/OutGameUpgrades.csv` vs runtime hooks.
   - Hook missing keys or remove/rename placeholder keys.
   - Especially: `unlock_torture_item`, dungeon-related unlocks, merchant discount/reward, player cooldown/range/area, base/minion effects.

5. **Merchant placeholder polish.**
   - Make temporary buffs easy to understand.
   - Show “next battle only” clearly.
   - Show chapter requirements.
   - Captive goods should add to dungeon list and save.
   - Walk/date events should write AVG event id and save.

6. **Dungeon placeholder polish.**
   - Show captives, humiliation Lv0–3, pending/processed state.
   - Show unlocked tools only.
   - If no manual choice, “place all unprocessed” path works.
   - Materialization writes next-battle effect and marks processed.
   - Add placeholder CG event names.

7. **Battle application of outgame + merchant + dungeon effects.**
   - BattleDirector should apply permanent upgrades + next battle merchant buffs + materialized captive effects.
   - At settlement, clear next-battle effects.
   - Settlement should display base lust score, multipliers, next-battle effects consumed.

## 15. Current battle/performance notes

Old guide value `max_active_entities_soft = 72` is stale. The user dislikes hard low caps.

Performance work already tried:

- Broadphase spatial grid usage in targeting/contact/projectile/effect paths.
- AI timeslicing.
- Leader/follower swarm flow.
- Shared GIF frame cache -> Sprite2D/batch renderer attempts.
- Damage floating label merge/cap.
- Render budget/floating cap.
- Data swarm attempt abandoned.

Important conclusion:

- Do not continue data_swarm unless explicitly requested. It caused size/sort/visual issues and was abandoned.
- Stable direction is no-data-swarm, shared GIF/batch/render budget, broadphase, waves, simple units.
- Current plausible scale is a few hundred active units, not thousands on screen.
- Aim for waves, fast fragile enemies, strong player attacks, and implied mass through kills over time.

## 16. Attack visual mapping already specified by user

Assets in `BattleAssets/` should map to attacks:

- `StrongMelee.png` strong melee
- `NormalMelle.png` medium melee
- `WeakMelle.png` weak melee
- `Bullet.png` basic bullet
- `TracerBullet.png` homing/tracer bullet
- `Sniper.png` sniper bullet
- `Boomerang.png`
- `Shotgun.png` each pellet
- `Beam.png` laser
- `Poison.png` poison area
- `Thunder.png` lightning strike, vertical/stretchable
- `Spike.png` spike
- `Charm.png` charm projectile
- `Lighting.png` lightning chain between enemies; scale/rotate horizontal texture between targets, not hopping projectile
- `CurveBullet.png`
- `Flame.png` flamethrower
- `RPG.png` rocket
- `RPGArea.png` rocket explosion area/effect
- `StrongStrafe.png` heavy strafe marker/attack
- `WeakStrafe.png` light strafe marker/meteor rain
- `StrafeBox.png` rectangular bombing frame
- `GeneralBombing.gif` generic explosion placeholder

Flamethrower visual rule:

- Facing right: flame left-edge center attaches to player right-side center.
- Facing left: flame right-edge center attaches to player left-side center.
- Reuse left_center/right_center anchor logic.

## 17. Current important files

Runtime battle:

- `BattleAssets/ScriptShader/BattleDirector.gd`
- `BattleAssets/ScriptShader/BattleEntity.gd`
- `BattleAssets/ScriptShader/BattleAttackInstance.gd`
- `BattleAssets/ScriptShader/BattleEffectRunner.gd`
- `BattleAssets/ScriptShader/BattleProjectile.gd`
- `BattleAssets/ScriptShader/BattleSharedGifBatchRenderer*.gd`
- `scenes/Battle/Battle_00.tscn`
- `scenes/Battle/Battle_00.ini`

Outgame/camp:

- `Script/SaveMgr/GameState.gd`
- `Script/Basement/BasementPortal.gd`
- `scenes/Basement.tscn`
- `scenes/OutGame/OutGameUpgrade.tscn`
- `scenes/OutGame/OutGameUpgrade.gd`
- `scenes/Merchant/Merchant.tscn`
- `scenes/Merchant/Merchant.gd`
- `scenes/Dungeon/Dungeon.tscn`
- `scenes/Dungeon/Dungeon.gd`
- `Script/Chamber/chamber.gd`

Config:

- `Config/OutGameUpgrades.csv`
- `Config/MerchantGoods.csv`
- `Config/DungeonCaptives.csv`
- `Config/TortureItems.csv`
- `Config/Characters.csv`
- `Config/Weapons.csv` or uploaded `Weapons(1).csv`
- `Config/WeaponUpgrades.csv`
- `Config/Equipments.csv`
- `Config/RunStatUpgrades.csv`

## 18. Recent useful patch zips in `/mnt/data`

These may not be perfectly layered, but are useful references:

- `outgame_upgrade_loadout_save_fix5.zip`
- `merchant_scene_patch.zip`
- `dungeon_scene_patch.zip`
- `basement_navigation_patch.zip`
- `stable_next_optimization_no_dataswarm.zip`
- `standard_mode_level_attack_visual_patch.zip`
- `roguelite_tempo_standard_mode_patch.zip`

If creating a new patch, inspect the current repo/files first rather than blindly layering an old zip.

## 19. Avoid

- Do not suggest all content become AVG-only.
- Do not remove base/minion fantasy without user request.
- Do not reintroduce data_swarm.
- Do not assume AAA map scale.
- Do not generate complicated pixel animation frames and promise they are production ready.
- Do not make protagonist white-haired.
- Do not make protagonist a tomboy.
- Do not make witch researcher elegant unless user reverses direction.
- Do not make every captive a moral growth arc.
- Do not frame protagonist as soft victim.
- Do not turn the story into heavy moral lecture.

## 20. Current strongest direction summary

Project L should be remembered as:

> A black-haired, small, stubborn, vulgar tentacle-girl protagonist raised by a broken ancient mother-engine. She drives a mobile nest through a failing artificial ecology shard, steals pretty girls and survival nodes, and through crude “black-rainbow backdoor” synchronization reconnects broken girl-shell civilizations that queens, churches, witches, merchants, and recyclers all try to repair in their own flawed ways.

Gameplay expression:

> Small top-down pixel arenas, symbolic node wars, a few hundred low-detail enemies, strong player attacks, outgame merchant/dungeon/upgrades, CG moments for the key story beats.

Art expression:

> DALL·E/AI for gorgeous CG drafts and design sheets; artist/SD/Flux for consistency and production cleanup; battle sprites stay simple, chunky, and symbolic.

---

## 2026-06-12 MVP 存档结构 v3 更新

当前重点进入 MVP 收尾，存档结构要稳定。后续所有局外系统必须以 `res://Save/*.txt` 的 `SaveDataJSON` 为唯一真实状态，不要再另造全局变量或静态表状态。

### 槽位

- `Save0.txt`：0 进度模板，默认 `lust=0`，不参与正常游玩。
- `Save1.txt`：唯一手动主存档。
- `SaveAuto.txt / SaveAuto2.txt`：自动档 A/B，交替写入。
- 测试用 Auto 档可给 `economy.lust=20000`，但正式新游戏仍然从 0 开始。

### 根结构

`SaveDataJSON` 规范为：

- `meta`：槽位、章节、最后场景、自动存档代数。
- `economy`：`lust` 淫能、`humiliation` 全局屈辱统计。
- `battle_loadout`：备战选择角色/武器/装备。
- `progress`：章节/关卡进度。关卡解锁以 `progress.unlocked_levels` 为准，`level_bonus_collect` 是废弃旧字段，仅兼容保留。
- `unlocks`：和 Config CSV 对齐的解锁集合，包括 `characters/weapons/equipments/torture_items/temporary_items_seen/story_events/cg_events/narrative_events/codex`。
- `upgrades`：统一为 `player/base/minion/dungeon/merchant`。旧 `building` 迁移到 `base`，旧 `tentacle` 迁移到 `minion`。
- `dungeon`：俘虏、地窖事件、下局物化装备、最近地窖操作结果。
- `merchant`：商人购买、下局临时道具/效果、最近购买。
- `story`：剧情/CG 读取状态、待触发事件。
- `runtime`：后续传给 BattleDirector 的临时运行态。
- `flags`：特殊开关。

### 地窖规则

调教必须满足：`角色 x 调教道具 x 俘虏` 三者都存在。缺任意一项退回放置，不触发调教 CG。

`DungeonEvents.csv` 两类：

1. 特定组合第一次触发 `special_event_id`，并设置 `flag_key`。
2. 触发过后，或 `actor_id=*` 的通用组合，触发 `generic_event_id`。

CG/剧情取得需要同步：

- `unlocks.story_events`
- 若 ID 以 `CG_` 开头，写 `unlocks.cg_events`
- `story.events_seen / story.cg_seen`
- 地窖来源还写 `dungeon.events_seen / last_event_id / last_story_event_id`

### 商人和下局临时道具

商人临时道具来自 `Config/TemporaryItems.csv`，购买后写：

- `merchant.next_battle_temp_items`：UI 显示 ID。
- `merchant.next_battle_effects`：BattleDirector 读取的数值修正。
- `unlocks.temporary_items_seen`：见过/买过记录。
- `merchant.purchases`：商品购买次数。

同一 `effect_key` 每次营地只能买一个，不同 `effect_key` 不限制。战斗胜利或失败结算时清理临时状态。

### 调试

新增可选 Autoload：`Script/Debug/ProjectDebug.gd`，名字建议 `ProjectDebug`。发布版不加载。加载后打印当前场景、active slot、lust、商人临时道具、地窖物化装备、俘虏数量。

如果直接运行商人/地窖场景而没有显式 `load_slot()`，`GameState.ensure_loaded()` 会从 `Save1/SaveAuto/SaveAuto2` 中选择最像真实进度的槽位，避免误读 0 进度或旧缓存。


## MVP v7 存档与局内传递规则

- GitHub 已被用户 push 到较新状态，但补丁仍应按“用户本地可能未完全同步”处理。
- GameState 是局外进度唯一来源：淫能、关卡解锁、CG/剧情、俘虏、商人临时道具、地窖物化装备、局外升级都必须写入 SaveDataJSON。
- BattleDirector 不应分别到处读取商人/升级/地窖，而应优先走 `GameState.build_battle_modifiers()`。
- `level_bonus_collect` 是废弃兼容字段；关卡解锁用 `progress.unlocked_levels`，关卡通关用 `progress.cleared_levels`。
- 命中敌人不允许弹“淫能+20”；淫能只在战斗结算、地窖放置/调教、商人/局外消费等明确节点变化。
- 战斗结算应记录 `lust_before + lust_reward = lust_after`，避免 UI 显示全局值和本局奖励混淆。
- CG/剧情回想占位 UI 在 `res://scenes/StoryGallery/StoryGallery.tscn`，读取 `Config/StoryEvents.csv` 和 `unlocks.story_events/cg_events/narrative_events`。

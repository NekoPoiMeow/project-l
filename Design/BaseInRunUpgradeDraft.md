# Base In-Run Upgrade Draft

This is a design draft only. It should not be treated as final balance.

## Core Rules

| Topic | Draft Rule |
| --- | --- |
| Base level cap | Default cap is Lv7. Each battle can override the cap downward. |
| Lv1 base | No active/passive combat ability. Starts with 1 invincible worker. |
| Upgrade pause | When base evolution reaches the next level, pause the game and show base upgrade choices. |
| Choice shape | Each base level-up asks for 1 base/system choice and 1 minion-route choice. |
| Player separation | Base upgrades do not directly change the player. Player changes come from player level-ups, weapons, meta progression, next-run items, and captive conversion. |
| Biomass meaning | Biomass behaves like power/load instead of ore. It affects production/evolution speed, but queues still move when biomass is low. |
| Low biomass production | Minion queues still progress at 50% speed when biomass is insufficient. |
| Low biomass evolution | Base evolution still progresses at 20% speed when biomass is insufficient. |
| Minion queues | Each minion tier/type has its own production queue. Lv2 minion has one bar, Lv3 minion has another bar, etc. |

## Biomass Power States

| State | Suggested Condition | Base Evolution Speed | Minion Queue Speed | Notes |
| --- | --- | ---: | ---: | --- |
| Starved | Biomass below required upkeep | 20% | 50% | The base is still alive and evolving, but feels hungry. |
| Fed | Biomass meets upkeep | 100% | 100% | Standard flow. |
| Overfed | Biomass above a high threshold | 120% | 115% | Optional later. Creates reward for efficient delivery without making delivery mandatory every few seconds. |

## Base Level Table

| Base Level | New System Baseline | Base Ability Choice Pool | Minion Route Choice |
| --- | --- | --- | --- |
| Lv1 | No base ability. Starts with 1 invincible worker. | None | Worker only. |
| Lv2 | Unlock Tier-2 minion queue: Entangler. Base begins weak self-maintenance. | Choose 1: Biomass pulse production; weak boundary AOE; Entangler queue speed/cost support. | Choose Entangler direction. |
| Lv3 | Unlock Tier-3 minion queue: Drainer. Base gains second system slot. | Choose 1: stronger passive biomass; bigger delivery/supply radius; weak boundary AOE cooldown down; Tier-2 and Tier-3 queue support. | Choose Drainer direction. |
| Lv4 | Unlock Tier-4 minion queue: Suppressor. Base becomes able to shape nearby fights. | Choose 1: boundary AOE adds slow; base contact knockback up; all active queues gain low-biomass speed; Entangler/Drainer synergy. | Choose Suppressor direction. |
| Lv5 | Unlock Tier-5 minion queue: Ravager. Base gains a pressure-release tool. | Choose 1: periodic lure/taunt zone around base; emergency self-heal after taking damage; biomass production burst after nearby kills; Tier-4/Tier-5 queue support. | Choose Ravager direction. |
| Lv6 | Unlock Tier-6 minion queue: Matron Spawn. Base can support a chosen army identity. | Choose 1: selected minion family production speed up; selected minion family low-biomass penalty reduced; boundary AOE damage up; delivery radius and worker speed up. | Choose Matron Spawn direction. |
| Lv7 | Final base form for normal cap. No new queue required, but can transform existing army rhythm. | Choose 1 final form: Resource womb; defensive boundary; army engine; lust-mark engine. | Choose final minion doctrine. |

## Base Ability Pool

| Ability ID | Name | Earliest Level | Effect Draft | Design Purpose |
| --- | --- | ---: | --- | --- |
| B_PROD_01 | Biomass Secretion | Lv2 | Base produces 5 biomass per cycle. If chosen again or upgraded, production becomes 12 per cycle. | Reduces how often player must return to delivery zone. |
| B_AOE_01 | Boundary Tremor | Lv2 | Periodically releases weak AOE around base. Low damage, mainly clears weak enemies near the base. | Lets base clean its own edge without replacing player/minions. |
| B_QUEUE_02 | Entangler Nursery | Lv2 | Entangler queue cycle faster and biomass requirement lower. | Lets the first combat minion become reliable quickly. |
| B_RADIUS_01 | Soft Feeding Field | Lv3 | Delivery/supply radius increases. Workers and player can feed base from slightly farther away. | Reduces handoff friction. |
| B_PROD_02 | Warm Secretion | Lv3 | Passive biomass production cycle becomes stronger. | Supports multi-queue production. |
| B_AOE_02 | Sticky Boundary | Lv4 | Boundary AOE adds short slow. | Helps base survive swarms without raw damage inflation. |
| B_POWER_01 | Hungry Continuance | Lv4 | Low-biomass minion queue penalty improves from 50% to 65%. | Makes biomass shortage less punishing. |
| B_GUARD_01 | Reflex Grip | Lv5 | After base takes repeated hits, releases a short-range knockback/weak damage pulse. | Anti-crowding self-defense. |
| B_KILL_01 | Offering Reflex | Lv5 | Enemies killed near base add a small biomass burst. | Rewards fighting around base without making camping mandatory. |
| B_FOCUS_01 | Chosen Brood | Lv6 | Choose one minion family; that family gets production speed up. | Supports army identity. |
| B_WORKER_01 | Tireless Worker | Lv6 | Worker movement and delivery efficiency up; optional extra worker if cap allows. | More automation, less return pressure. |
| B_FINAL_RES | Resource Womb | Lv7 | Strong biomass production and all queues get mild speed up when fed. | Economy final form. |
| B_FINAL_DEF | Boundary Nest | Lv7 | Boundary AOE becomes wider, slows more, and triggers more safely under attack. | Defensive final form. |
| B_FINAL_ARMY | Brood Engine | Lv7 | All unlocked minion queues progress faster; selected family gets extra speed. | Army flood final form. |
| B_FINAL_LUST | Marked Offering | Lv7 | Minions generate bonus biomass from marked/controlled enemies. | Theme-heavy sustain final form. |

## Minion Route Table

| Tier | Minion | Baseline Role | Route A | Route B | Route C |
| --- | --- | --- | --- | --- | --- |
| Worker | Worker | Invincible gatherer/hauler. No attacks. | Faster pickup/delivery. | Larger pickup radius. | Extra worker later, if allowed by cap. |
| Lv2 | Entangler | Short-range melee control unit. | Hate Lure: while alive, nearby enemies prefer attacking it. AOE is small around the Entangler. | Flesh Lash: HP, attack, defense, and move speed up. | Offering Lash: a percentage of its dealt damage becomes base biomass. |
| Lv3 | Drainer | Close-mid unit focused on intimate capture pressure and sustain. | Siphon: attacks return biomass to base at a fixed ratio. | Cling: slows enemies it attacks and sticks to them longer. | Fevered Bite: higher damage against controlled/slowed enemies. |
| Lv4 | Suppressor | Control/support unit that makes enemy groups easier to handle. | Soft Bind: periodically weakens enemy move speed/attack near itself. | Focus Mark: enemies it touches take more damage from tentacle minions. | Guard Pull: slightly draws enemies away from the base core toward itself. |
| Lv5 | Ravager | Aggressive bruiser for breaking enemy lines. | Breach: higher damage to enemy buildings/elites. | Thrash: short cleave around target. | Spoil: kills made by Ravager drop extra biomass or feed the base. |
| Lv6 | Matron Spawn | Expensive support breeder that enhances other minions. | Brood Rhythm: nearby minion queues receive a production speed bonus while one exists. | Silk Shelter: nearby minions gain defense/regen. | Frenzy Scent: nearby minions attack faster against marked enemies. |
| Lv7 | Final Doctrine | Final army identity, not necessarily a new unit. | Devouring Brood: biomass-return effects improved across all minions. | Binding Brood: control duration/slow/taunt effects improved. | Flooding Brood: production speed and low-biomass queue speed improved. |

## Level-by-Level Example Choices

| Upgrade Event | Base Choice Examples | Minion Choice Examples |
| --- | --- | --- |
| Lv1 -> Lv2 | Biomass Secretion; Boundary Tremor; Entangler Nursery | Entangler: Hate Lure; Flesh Lash; Offering Lash |
| Lv2 -> Lv3 | Warm Secretion; Soft Feeding Field; Boundary Tremor cooldown down | Drainer: Siphon; Cling; Fevered Bite |
| Lv3 -> Lv4 | Sticky Boundary; Hungry Continuance; Entangler/Drainer support | Suppressor: Soft Bind; Focus Mark; Guard Pull |
| Lv4 -> Lv5 | Reflex Grip; Offering Reflex; Tier-5 queue support | Ravager: Breach; Thrash; Spoil |
| Lv5 -> Lv6 | Chosen Brood; Tireless Worker; low-biomass queue support | Matron Spawn: Brood Rhythm; Silk Shelter; Frenzy Scent |
| Lv6 -> Lv7 | Resource Womb; Boundary Nest; Brood Engine; Marked Offering | Final Doctrine: Devouring Brood; Binding Brood; Flooding Brood |

## Open Balance Questions

| Question | Current Lean |
| --- | --- |
| Does each level always unlock exactly one new minion queue? | Yes for Lv2-Lv6. Lv7 should be final doctrine instead of another normal queue. |
| Does biomass get spent by queues? | Prefer no hard spending. Treat it as power/load so queues slow down when underfed. |
| Does base evolution consume biomass? | Prefer no hard spending. Evolution speed changes by biomass state. |
| Can player ignore delivery forever? | No. Starved state should be slow enough that delivery and workers still matter. |
| Should base upgrades affect player stats? | No direct player stat changes in base upgrade choices. |
| Should theme text be explicit in data? | Keep mechanical names readable first. Flavor can be added later in UI copy. |

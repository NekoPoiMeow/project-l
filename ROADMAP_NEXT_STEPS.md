# Project-L Next Steps After MVP Rescue

## Phase 1 — Stabilize the Spine

Goal: stop firefighting broad systems.

Tasks:

- Keep current Save/GameState/BattleDirector/Merchant/Dungeon bridge stable.
- Only fix bugs with small isolated patches.
- Keep console audits for missing CSV mechanics.
- Do not rework performance beyond current render-budget/shared-GIF approach.

Exit criteria:

- One battle can start, clear, settle, autosave, return to outgame.
- Merchant temp effects apply and clear.
- Dungeon materialized equipment applies for one battle.
- Story/Gallery can show placeholder events.

## Phase 2 — Content Skeleton

Goal: make the game “exist” end-to-end.

Tasks:

- Create 3 formal battle levels:
  1. Tutorial/entry.
  2. Base-defense mainline.
  3. Story/captive unlock branch.
- Create 4-6 story/CG placeholder rows.
- Make level rewards unlock captives/story/gallery.
- Make one merchant event and one dungeon special event visible.

Exit criteria:

- New save can play from first level to at least one dungeon CG and one follow-up battle.

## Phase 3 — Content Expansion

Goal: build enough game to feel real.

Tasks:

- Expand level map to 8-12 nodes.
- Add enemy composition variants.
- Add 2-3 captive/dungeon event chains.
- Add merchant goods/event variety.
- Add visual placeholders for missing equipment feedback.

Exit criteria:

- 30-60 minutes of playable loop, even with placeholder art.

## Phase 4 — Polish Pass

Goal: improve feel without destabilizing architecture.

Tasks:

- Weapon-specific visual/range configs.
- Equipment VFX/UI feedback.
- Balance numbers.
- Replace placeholder CG/art.
- Reduce console noise for release builds.

## Isolated Breakthrough Template

When a future change feels risky, write this before editing:

```text
Problem:
Files touched:
Proposed isolated handler:
Could this be config-only? yes/no
Regression tests:
Rollback plan:
```

If the change touches more than three central files, pause and split it.

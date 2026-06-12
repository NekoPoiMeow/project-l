# MVP Bridge Patch v9 - perf/story compatibility fix

基于 v8 / 当前 GitHub 状态的增量补丁。

## 修复点

1. StoryTeller / StoryGallery 兼容
- project.godot 增加 Autoload:
  - AppConfig -> res://Script/AppConfig.gd
  - SceneLoader -> res://Script/SceneLoader.gd
- AppConfig.gd / SceneLoader.gd 改为 Node 单例兼容脚本，修复旧 StoryTeller 中 `Identifier AppConfig/SceneLoader not declared`。

2. 同屏性能恢复一层预算
- Battle_00.ini: max_active_entities_soft 从 99999 改为 360。
  99999 会让波次无限累计，导致当前版本约 200 左右卡顿。
- BattleDirector.gd: shared GIF batch threshold 从 120 降到 80，160 以上强制 follower 进入 batch。
- BattleSharedGifBatchRenderer.gd: 更激进的 density cull / draw budget。

3. 调试输出
- ProjectDebug.gd 增加周期性 BattleRuntime 打印：entities/projectiles/attack_instances/drops/batched/运行倍率。

## 期望输出
进战斗后控制台应看到：
[Battle] shared_gif_batch_renderer=ON threshold=80 force_all_at=160 draw_budget_dynamic=ON
[ProjectDebug][BattleRuntime][periodic] entities=... | batched=...

## 注意
这个补丁不是完整“昨天战斗核心三件套回滚”，而是先修当前仓库上最明显的两个问题：
- StoryTeller 编译错误
- 当前 Battle_00.ini 放开到 99999 后导致性能预算失效

如果仍然达不到昨天 300+ 的效果，下一步建议做 battle-core 回滚合并包：
以当前 GameState/商人/地窖为基底，重新合并昨天稳定版 BattleDirector_render_budget + BattleEntity_render_budget + BattleSharedGifBatchRenderer_render_budget_fixed。

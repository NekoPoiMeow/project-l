# 存档格式与调用规范

## 槽位约定

- `Save0.txt`：0 进度模板，只用于删除/重置其他槽位时复制覆盖，不参与正常游玩。
- `Save1.txt`：唯一手动主存档。手动保存、开始新游戏初始化时写这里。
- `SaveAuto.txt`：自动存档 A。
- `SaveAuto2.txt`：自动存档 B。

自动保存只在 `SaveAuto.txt` 与 `SaveAuto2.txt` 之间交替写入，不覆盖 `Save1.txt`。

## 文本结构

每个 txt 都是“可读头 + JSON 数据体”：

```ini
SaveSlotId=Save1
SaveRole=manual
SaveName=进度0
SaveTime=未开始
SaveChapterID=0
SaveChapterName=未开始
SaveFormatVersion=1
SaveReason=zero_progress
SaveDataJSON={...}
```

旧 UI 只需要读取头部字段即可显示；游戏实际进度读取 `SaveDataJSON`。

## JSON 主体

顶层字段：

- `meta`：存档版本、槽位、章节、最后场景、自动存档代数。
- `economy`：淫能、屈辱度等全局资源。
- `progress`：章节解锁、关卡通关、bonus 获取。
- `unlocks`：角色、武器、装备、调教道具、图鉴解锁。
- `upgrades`：局外升级，暂分 `player / tentacle / building`。
- `dungeon`：俘虏、地牢操作记录。
- `flags`：特殊事件开关。

## GameState 常用接口

载入/初始化：

```gdscript
GameState.load_slot("res://Save/Save1.txt")
GameState.start_new_game("res://Save/Save1.txt")
```

保存：

```gdscript
GameState.save_manual_now("manual_save")
GameState.autosave("battle_win")
```

保存成功时，`GameState` 会按当前 `chapter_id` 自动刷新同名 png：

- `Save1.txt` -> `Save1.png`
- `SaveAuto.txt` -> `SaveAuto.png`
- `SaveAuto2.txt` -> `SaveAuto2.png`

章节图查找约定：

- `res://GraphicAssets/04_Save_Select/SaveChapter1.png`
- 找不到时回退 `res://Save/Save0.png`

如果 UI 需要避开 Godot 资源缓存，直接刷新显示图：

```gdscript
GameState.apply_slot_preview_to_texture_rect(texture_rect, "res://Save/Save1.txt")
```

或者只拿贴图：

```gdscript
var tex := GameState.load_slot_preview_texture("res://Save/SaveAuto.txt")
```

进度：

```gdscript
GameState.record_level_clear("L001", 1)
GameState.unlock_level("L002")
GameState.set_chapter_progress(2, "Chapter 2", "clear_chapter_1")
```

进入营地：

```gdscript
GameState.on_basement_loaded()
```

`Basement.tscn` 每次载入都会自动调用一次。若当前章节是 0，会先变成章节 1；若已经是 1 或更高，只刷新 `last_scene` 并写入下一格 AutoSave。

资源：

```gdscript
GameState.add_lust(100)
GameState.spend_lust(50)
GameState.add_humiliation(10)
```

解锁：

```gdscript
GameState.unlock_item("weapons", "W002")
GameState.is_unlocked("characters", "C001")
```

局外升级：

```gdscript
GameState.set_upgrade_level("player", "hp_up", 1)
var lv := GameState.get_upgrade_level("player", "hp_up")
```

特殊开关：

```gdscript
GameState.set_flag("altar_first_opened", true)
var opened := GameState.get_flag("altar_first_opened", false)
```

## 触发规范

以下情况应该调用 `GameState.autosave(reason)`：

- 个室确认出击后。
- 战斗胜利结算完成后。
- 局外升级购买成功后。
- 地牢俘虏 3 选 1 操作确定后。
- 解锁角色、武器、装备、图鉴后。

以下情况才调用 `GameState.save_manual_now(reason)`：

- 玩家明确执行手动保存。
- 新游戏初始化 `Save1`。

## 进度 0

进度 0 存档并不是“文件不存在”，而是合法存档：

- `SaveChapterID=0`
- `meta.is_zero_progress=true`
- `progress / unlocks / upgrades / dungeon` 均为空或 0 值

旧界面可以把它显示为“进度0 / 未开始”。

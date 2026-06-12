MVP bridge patch v2

新增/修正：
1. Script/Debug/ProjectDebug.gd：可选 Autoload 调试器。发布时不要加载；测试时 Project Settings -> Autoload 添加 ProjectDebug，路径 res://Script/Debug/ProjectDebug.gd。会打印场景切换、淫能、商人下局道具、地窖物化装备、俘虏数量。
2. Save/SaveAuto.txt 与 Save/SaveAuto2.txt：测试用自动档，淫能 20000。Save1 不改，避免污染手动主档。
3. 地窖 UI：增加俘虏下拉框；放置/物化只显示俘虏；调教才显示角色和调教道具。调教缺角色/道具/俘虏时退回放置，不触发 CG。
4. 商人临时道具：同一 effect_key 每次营地只能买一个；打完下一局后由 BattleDirector 清空。
5. 出击准备 Chamber：详情区显示本次已购买的商人临时道具、地窖物化装备，方便出击前核实。

测试顺序：
- 从 SaveAuto 或 SaveAuto2 载入，确认淫能 20000。
- 商人买 TMP_ATK_001，再试买同类，应该禁止；可买不同 effect_key。
- Chamber 详情区应显示临时道具。
- 商人买俘虏后进地窖，地窖左侧列表和中间下拉框都能选俘虏。
- 地窖调教显示角色/道具下拉，放置/物化隐藏它们。
- 开启 ProjectDebug Autoload 后，进场景与购买/出击会在 Output 打印状态。

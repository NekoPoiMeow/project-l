extends Node

# MVP compatibility singleton.
# Older AVG/StoryTeller scenes referenced `/root/AppConfig` or `AppConfig` directly.
# Keep it tiny: no release-only behavior, only safe path/config helpers.

const BASEMENT_SCENE_PATH := "res://scenes/Basement.tscn"
const STORY_GALLERY_SCENE_PATH := "res://scenes/StoryGallery/StoryGallery.tscn"
const OUTGAME_UPGRADE_SCENE_PATH := "res://scenes/OutGame/OutGameUpgrade.tscn"
const MERCHANT_SCENE_PATH := "res://scenes/Merchant/Merchant.tscn"
const DUNGEON_SCENE_PATH := "res://scenes/Dungeon/Dungeon.tscn"

func exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)

func safe_text(value, fallback: String = "") -> String:
	var s := str(value)
	return fallback if s.strip_edges() == "" else s

func bool_value(value, fallback: bool = false) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	var s := str(value).strip_edges().to_lower()
	if s in ["true", "1", "yes", "y", "on"]:
		return true
	if s in ["false", "0", "no", "n", "off"]:
		return false
	return fallback

func get_scene_path(key: String, fallback: String = "") -> String:
	match key:
		"basement", "home", "camp":
			return BASEMENT_SCENE_PATH
		"story_gallery", "gallery", "cg":
			return STORY_GALLERY_SCENE_PATH
		"outgame", "upgrade":
			return OUTGAME_UPGRADE_SCENE_PATH
		"merchant", "shop":
			return MERCHANT_SCENE_PATH
		"dungeon":
			return DUNGEON_SCENE_PATH
		_:
			return fallback

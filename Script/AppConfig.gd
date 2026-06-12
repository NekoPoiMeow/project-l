extends RefCounted
class_name AppConfig

# Compatibility shim. Some old/test scenes referenced AppConfig as a global class.
# Keep this lightweight and non-Autoload so release builds are not affected.

static func exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)

static func safe_text(value, fallback: String = "") -> String:
	var s := str(value)
	return fallback if s.strip_edges() == "" else s

static func bool_value(value, fallback: bool = false) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	var s := str(value).strip_edges().to_lower()
	if s in ["true", "1", "yes", "y", "on"]:
		return true
	if s in ["false", "0", "no", "n", "off"]:
		return false
	return fallback

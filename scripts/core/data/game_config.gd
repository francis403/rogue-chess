class_name GameConfig
extends RefCounted
## Read-only access to the JSON files in res://config/. Pure logic, no nodes.
## Usage: GameConfig.data("match")["target_score"]

const CONFIG_DIR := "res://config/"

static var _cache: Dictionary = {}


static func data(file_name: String) -> Dictionary:
	if not _cache.has(file_name):
		var path := CONFIG_DIR + file_name + ".json"
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		assert(parsed is Dictionary, "Config file missing or invalid: " + path)
		_cache[file_name] = parsed
	return _cache[file_name]


## Shortcut: GameConfig.value("match", "target_score")
static func value(file_name: String, key: String):
	return data(file_name)[key]


static func piece_value(type: String) -> int:
	return int(data("pieces")[type]["value"])


static func card_base_cost(type: String) -> int:
	return int(data("cards")[type]["cost"])

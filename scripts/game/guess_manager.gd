extends Node

signal inventory_changed(item_id: String)

const ITEM_DIRECTORY: String = "res://data/items"
const USER_COOLDOWN_MSEC: int = 1500

var _items_by_name: Dictionary[String, String] = {}
var _hidden_item_ids: Dictionary[String, bool] = {}
var _viewer_last_guess_time: Dictionary[String, int] = {}


func _ready() -> void:
	_load_items()
	EventBus.chat_message_received.connect(_on_chat_message_received)


func _load_items() -> void:
	var directory: DirAccess = DirAccess.open(ITEM_DIRECTORY)
	if directory == null:
		push_error("GuessManager: Could not open " + ITEM_DIRECTORY)
		return

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			var item_path: String = ITEM_DIRECTORY.path_join(file_name)
			var resource: Resource = load(item_path)
			if resource is ItemData:
				var item: ItemData = resource as ItemData
				if item.id.is_empty():
					push_warning("GuessManager: Item has an empty id: " + file_name)
				else:
					_hidden_item_ids[item.id] = true
					_add_match_name(item.display_name, item.id)
					for alias: String in item.aliases:
						_add_match_name(alias, item.id)
		file_name = directory.get_next()
	directory.list_dir_end()


func _add_match_name(item_name: String, item_id: String) -> void:
	var normalized_name: String = _normalize(item_name)
	if not normalized_name.is_empty():
		_items_by_name[normalized_name] = item_id


func _on_chat_message_received(username: String, text: String) -> void:
	var normalized_guess: String = _normalize(text)
	if normalized_guess.is_empty():
		return

	var now_msec: int = Time.get_ticks_msec()
	var last_guess_msec: int = _viewer_last_guess_time.get(username, -USER_COOLDOWN_MSEC)
	if now_msec - last_guess_msec < USER_COOLDOWN_MSEC:
		return
	_viewer_last_guess_time[username] = now_msec

	if not _items_by_name.has(normalized_guess):
		return

	var item_id: String = _items_by_name[normalized_guess]
	if not _hidden_item_ids.has(item_id):
		return

	_hidden_item_ids.erase(item_id)
	inventory_changed.emit(item_id)
	EventBus.item_guessed.emit(username, item_id)


func _normalize(value: String) -> String:
	return value.strip_edges().to_lower()

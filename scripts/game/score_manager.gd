extends Node

const POINTS_PER_REVEAL: int = 10

var _scores: Dictionary[String, int] = {}


func _ready() -> void:
	EventBus.item_guessed.connect(_on_item_guessed)


func get_score(username: String) -> int:
	return int(_scores.get(username, 0))


func get_top_five() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for username: String in _scores:
		entries.append({
			"username": username,
			"score": _scores[username]
		})

	entries.sort_custom(_sort_scores)
	return entries.slice(0, mini(5, entries.size()))


func _on_item_guessed(username: String, _item_id: String) -> void:
	var total: int = get_score(username) + POINTS_PER_REVEAL
	_scores[username] = total
	EventBus.score_changed.emit(username, total)


func _sort_scores(first: Dictionary, second: Dictionary) -> bool:
	var first_score: int = int(first.get("score", 0))
	var second_score: int = int(second.get("score", 0))

	if first_score == second_score:
		return str(first.get("username", "")) < str(second.get("username", ""))

	return first_score > second_score

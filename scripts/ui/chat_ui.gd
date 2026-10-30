extends CanvasLayer

const CONFIG_PATH: String = "user://kitchen_panic.cfg"
const CONFIG_SECTION: String = "twitch"
const MAX_RECENT_LINES: int = 8

var _channel_input: LineEdit
var _connect_button: Button
var _status_label: Label
var _auth_code_label: Label
var _guesses_label: Label
var _leaderboard_label: Label

var _chat_source: TwitchChatSource
var _recent_lines: Array[String] = []
var _access_token: String = ""
var _username: String = ""
var _authorization_running: bool = false


func _ready() -> void:
	_build_ui()
	_load_config()

	EventBus.chat_message_received.connect(_on_chat_message_received)
	EventBus.item_guessed.connect(_on_item_guessed)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.connection_status_changed.connect(_on_connection_status_changed)

	EventBus.twitch_auth_code_received.connect(_on_twitch_auth_code_received)
	EventBus.twitch_auth_status_changed.connect(_on_twitch_auth_status_changed)
	EventBus.twitch_auth_completed.connect(_on_twitch_auth_completed)
	EventBus.twitch_auth_failed.connect(_on_twitch_auth_failed)


func _exit_tree() -> void:
	if _chat_source != null and is_instance_valid(_chat_source):
		_chat_source.stop()


func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(380, 500)
	add_child(panel)

	var layout: VBoxContainer = VBoxContainer.new()
	panel.add_child(layout)

	var title: Label = Label.new()
	title.text = "Kitchen Panic Twitch Chat"
	layout.add_child(title)

	_channel_input = LineEdit.new()
	_channel_input.placeholder_text = "Twitch channel name"
	layout.add_child(_channel_input)

	_connect_button = Button.new()
	_connect_button.text = "Connect with Twitch"
	_connect_button.pressed.connect(_on_connect_button_pressed)
	layout.add_child(_connect_button)

	_status_label = Label.new()
	_status_label.text = "Disconnected"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status_label)

	_auth_code_label = Label.new()
	_auth_code_label.text = ""
	_auth_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_auth_code_label)

	var guesses_title: Label = Label.new()
	guesses_title.text = "Recent guesses"
	layout.add_child(guesses_title)

	_guesses_label = Label.new()
	_guesses_label.text = "No guesses yet."
	_guesses_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_guesses_label)

	var leaderboard_title: Label = Label.new()
	leaderboard_title.text = "Leaderboard"
	layout.add_child(leaderboard_title)

	_leaderboard_label = Label.new()
	_leaderboard_label.text = "No points yet."
	layout.add_child(_leaderboard_label)


func _load_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	_channel_input.text = str(config.get_value(CONFIG_SECTION, "channel", ""))
	_username = str(config.get_value(CONFIG_SECTION, "username", ""))
	_access_token = str(config.get_value(CONFIG_SECTION, "access_token", ""))


func _save_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(CONFIG_SECTION, "channel", _channel_input.text.strip_edges().to_lower())
	config.set_value(CONFIG_SECTION, "username", _username)
	config.set_value(CONFIG_SECTION, "access_token", _access_token)

	var error: Error = config.save(CONFIG_PATH)
	if error != OK:
		push_warning("Could not save Twitch settings to user://kitchen_panic.cfg")


func _on_connect_button_pressed() -> void:
	if _authorization_running:
		TwitchAuth.cancel_authorization()
		_authorization_running = false
		_connect_button.text = "Connect with Twitch"
		return

	if _chat_source != null and is_instance_valid(_chat_source):
		_chat_source.stop()
		_chat_source.queue_free()
		_chat_source = null
		_connect_button.text = "Connect with Twitch"
		_status_label.text = "Disconnected"
		return

	var channel: String = _channel_input.text.strip_edges().to_lower().trim_prefix("#")
	if channel.is_empty():
		_status_label.text = "Enter the Twitch channel name."
		return

	_channel_input.text = channel

	if not _access_token.is_empty() and not _username.is_empty():
		_save_config()
		_connect_to_channel()
		return

	_authorization_running = true
	_auth_code_label.text = ""
	_connect_button.text = "Cancel Authorization"
	TwitchAuth.start_authorization()


func _connect_to_channel() -> void:
	var channel: String = _channel_input.text.strip_edges().to_lower().trim_prefix("#")
	if channel.is_empty():
		_status_label.text = "Enter the Twitch channel name."
		return

	_chat_source = TwitchChatSource.new()
	_chat_source.nickname = _username
	_chat_source.access_token = _access_token
	add_child(_chat_source)
	_chat_source.start(channel)
	_connect_button.text = "Disconnect"


func _on_twitch_auth_code_received(
	user_code: String,
	verification_uri: String,
	_expires_in: int
) -> void:
	_auth_code_label.text = "Authorize code: " + user_code + "\n" + verification_uri


func _on_twitch_auth_status_changed(status: String) -> void:
	_status_label.text = status


func _on_twitch_auth_completed(access_token: String, username: String) -> void:
	_authorization_running = false
	_access_token = access_token
	_username = username.to_lower()
	_save_config()
	_auth_code_label.text = "Authorized as " + _username
	_connect_to_channel()


func _on_twitch_auth_failed(message: String) -> void:
	_authorization_running = false
	_status_label.text = message
	_connect_button.text = "Connect with Twitch"


func _on_chat_message_received(username: String, text: String) -> void:
	_add_recent_line(username + ": " + text)


func _on_item_guessed(username: String, item_id: String) -> void:
	_add_recent_line(username + " revealed " + item_id)


func _add_recent_line(line: String) -> void:
	_recent_lines.push_front(line)

	while _recent_lines.size() > MAX_RECENT_LINES:
		_recent_lines.pop_back()

	_guesses_label.text = "\n".join(_recent_lines)


func _on_score_changed(_username: String, _total: int) -> void:
	var entries: Array[Dictionary] = ScoreManager.get_top_five()
	if entries.is_empty():
		_leaderboard_label.text = "No points yet."
		return

	var lines: Array[String] = []
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		lines.append(
			str(index + 1) + ". " +
			str(entry.get("username", "")) + " — " +
			str(entry.get("score", 0)) + " points"
		)

	_leaderboard_label.text = "\n".join(lines)


func _on_connection_status_changed(status: String) -> void:
	_status_label.text = status.capitalize()
	if status == "disconnected":
		_connect_button.text = "Connect with Twitch"
	elif not _authorization_running:
		_connect_button.text = "Disconnect"

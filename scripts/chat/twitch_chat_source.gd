extends ChatSource
class_name TwitchChatSource

const TWITCH_IRC_URL: String = "wss://irc-ws.chat.twitch.tv:443"
const RECONNECT_BASE_SECONDS: float = 2.0
const RECONNECT_MAX_SECONDS: float = 30.0

var nickname: String = ""
var access_token: String = ""

var _socket: WebSocketPeer = WebSocketPeer.new()
var _channel: String = ""
var _reconnect_delay: float = RECONNECT_BASE_SECONDS
var _reconnect_timer: float = 0.0
var _stopping: bool = true
var _login_sent: bool = false


func start(channel: String) -> void:
	_channel = channel.strip_edges().to_lower().trim_prefix("#")
	nickname = nickname.strip_edges().to_lower()
	access_token = access_token.strip_edges().trim_prefix("oauth:")

	if _channel.is_empty() or nickname.is_empty() or access_token.is_empty():
		_set_status("error: channel, username, and access token are required")
		return

	_stopping = false
	_login_sent = false
	_reconnect_delay = RECONNECT_BASE_SECONDS
	_reconnect_timer = 0.0
	_connect()


func stop() -> void:
	_stopping = true
	_login_sent = false
	_reconnect_timer = 0.0

	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()

	_set_status("disconnected")


func _process(delta: float) -> void:
	if _stopping:
		return

	if _reconnect_timer > 0.0:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_connect()
		return

	_socket.poll()

	var state: int = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _login_sent:
			_send_login()
		_read_packets()
	elif state == WebSocketPeer.STATE_CLOSED:
		_schedule_reconnect()


func _connect() -> void:
	if _stopping:
		return

	_login_sent = false
	_socket = WebSocketPeer.new()

	var error: Error = _socket.connect_to_url(TWITCH_IRC_URL)
	if error != OK:
		_set_status("error: WebSocket connect failed")
		_schedule_reconnect()
		return

	_set_status("connecting")


func _send_login() -> void:
	_send_raw("PASS oauth:" + access_token)
	_send_raw("NICK " + nickname)
	_login_sent = true
	_set_status("authenticating")


func _read_packets() -> void:
	while _socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = _socket.get_packet()
		var message: String = packet.get_string_from_utf8()

		for line: String in message.split("\r\n", false):
			_handle_line(line)


func _handle_line(line: String) -> void:
	if line.begins_with("PING "):
		_send_raw("PONG " + line.trim_prefix("PING "))
		return

	if line.contains(" 001 "):
		_send_raw("JOIN #" + _channel)
		_reconnect_delay = RECONNECT_BASE_SECONDS
		_set_status("connected")
		return

	if line.contains("Login authentication failed"):
		_set_status("error: Twitch rejected the token or username")
		return

	if line.contains("Improperly formatted auth"):
		_set_status("error: Twitch rejected the login format")
		return

	if line.contains(" NOTICE "):
		_set_status("Twitch notice: " + line.get_slice(" :", 1))
		return

	if line.contains(" PRIVMSG #"):
		_parse_privmsg(line)


func _parse_privmsg(line: String) -> void:
	var command_position: int = line.find(" PRIVMSG #")
	if command_position < 0:
		return

	var message_separator: int = line.find(" :", command_position)
	if message_separator < 0:
		return

	var prefix_start: int = 1
	if line.begins_with("@"):
		var tags_separator: int = line.find(" :")
		if tags_separator < 0:
			return
		prefix_start = tags_separator + 2

	var username_end: int = line.find("!", prefix_start)
	if username_end < 0:
		return

	var username: String = line.substr(prefix_start, username_end - prefix_start)
	var message_text: String = line.substr(message_separator + 2)

	if username.is_empty() or message_text.is_empty():
		return

	EventBus.chat_message_received.emit(username, message_text)


func _send_raw(message: String) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(message + "\r\n")


func _schedule_reconnect() -> void:
	if _stopping or _reconnect_timer > 0.0:
		return

	_set_status("reconnecting")
	_reconnect_timer = _reconnect_delay
	_reconnect_delay = minf(_reconnect_delay * 2.0, RECONNECT_MAX_SECONDS)


func _set_status(status: String) -> void:
	EventBus.connection_status_changed.emit(status)

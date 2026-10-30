extends Node

const CLIENT_ID: String = "y79rl1kt1efbds5p8kdrixanfab35a"
const AUTH_SCOPE: String = "chat:read"

const DEVICE_URL: String = "https://id.twitch.tv/oauth2/device"
const TOKEN_URL: String = "https://id.twitch.tv/oauth2/token"
const VALIDATE_URL: String = "https://id.twitch.tv/oauth2/validate"
const DEVICE_GRANT_TYPE: String = "urn:ietf:params:oauth:grant-type:device_code"

var _http: HTTPRequest
var _request_kind: String = ""
var _device_code: String = ""
var _poll_interval: float = 5.0
var _poll_timer: float = 0.0
var _expires_timer: float = 0.0
var _access_token: String = ""
var _authorization_running: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func _process(delta: float) -> void:
	if not _authorization_running or _request_kind != "":
		return

	_expires_timer -= delta
	if _expires_timer <= 0.0:
		_fail_authorization("Authorization code expired. Please try connecting again.")
		return

	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_request_token()


func start_authorization() -> void:
	if CLIENT_ID == "PASTE_YOUR_CLIENT_ID_HERE" or CLIENT_ID.is_empty():
		EventBus.twitch_auth_failed.emit("Add your Twitch Client ID in twitch_auth.gd first.")
		return

	if _request_kind != "":
		EventBus.twitch_auth_status_changed.emit("Authorization request is already running.")
		return

	_authorization_running = true
	_access_token = ""
	_device_code = ""
	_request_kind = "device"

	EventBus.twitch_auth_status_changed.emit("Requesting Twitch authorization code...")

	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded"
	]
	var body: String = (
		"client_id=" + CLIENT_ID.uri_encode() +
		"&scopes=" + AUTH_SCOPE.uri_encode()
	)

	var error: Error = _http.request(
		DEVICE_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_fail_authorization("Could not contact Twitch to start authorization.")


func cancel_authorization() -> void:
	_authorization_running = false
	_request_kind = ""
	_device_code = ""
	_access_token = ""
	_http.cancel_request()
	EventBus.twitch_auth_status_changed.emit("Authorization cancelled.")


func _request_token() -> void:
	_poll_timer = _poll_interval
	_request_kind = "token"

	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded"
	]
	var body: String = (
		"client_id=" + CLIENT_ID.uri_encode() +
		"&scopes=" + AUTH_SCOPE.uri_encode() +
		"&device_code=" + _device_code.uri_encode() +
		"&grant_type=" + DEVICE_GRANT_TYPE.uri_encode()
	)

	var error: Error = _http.request(
		TOKEN_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_fail_authorization("Could not check Twitch authorization.")


func _validate_token() -> void:
	_request_kind = "validate"
	var headers: PackedStringArray = [
		"Authorization: OAuth " + _access_token
	]

	var error: Error = _http.request(
		VALIDATE_URL,
		headers,
		HTTPClient.METHOD_GET
	)
	if error != OK:
		_fail_authorization("Could not validate the Twitch access token.")


func _on_request_completed(
	result: int,
	response_code: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var finished_request: String = _request_kind
	_request_kind = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_authorization("Network error while contacting Twitch.")
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail_authorization("Twitch returned an unreadable response.")
		return

	var response: Dictionary = parsed as Dictionary

	if finished_request == "device":
		_handle_device_response(response_code, response)
	elif finished_request == "token":
		_handle_token_response(response_code, response)
	elif finished_request == "validate":
		_handle_validate_response(response_code, response)


func _handle_device_response(response_code: int, response: Dictionary) -> void:
	if response_code < 200 or response_code >= 300:
		_fail_authorization("Twitch could not create an authorization code.")
		return

	_device_code = str(response.get("device_code", ""))
	var user_code: String = str(response.get("user_code", ""))
	var verification_uri: String = str(response.get("verification_uri", ""))
	var expires_in: int = int(response.get("expires_in", 0))
	_poll_interval = float(response.get("interval", 5))

	if _device_code.is_empty() or user_code.is_empty() or verification_uri.is_empty():
		_fail_authorization("Twitch did not return the authorization details.")
		return

	_expires_timer = float(expires_in)
	_poll_timer = _poll_interval

	EventBus.twitch_auth_code_received.emit(
		user_code,
		verification_uri,
		expires_in
	)
	EventBus.twitch_auth_status_changed.emit("Waiting for Twitch authorization...")

	var open_error: Error = OS.shell_open(verification_uri)
	if open_error != OK:
		EventBus.twitch_auth_status_changed.emit(
			"Open " + verification_uri + " and enter code " + user_code
		)


func _handle_token_response(response_code: int, response: Dictionary) -> void:
	if response_code >= 200 and response_code < 300:
		_access_token = str(response.get("access_token", ""))
		if _access_token.is_empty():
			_fail_authorization("Twitch did not return an access token.")
			return

		EventBus.twitch_auth_status_changed.emit("Authorization approved. Checking account...")
		_validate_token()
		return

	var error_name: String = str(response.get("message", ""))
	if error_name == "authorization_pending":
		return

	if error_name == "slow_down":
		_poll_interval += 5.0
		return

	if error_name == "access_denied":
		_fail_authorization("Twitch authorization was denied.")
		return

	if error_name == "expired_token":
		_fail_authorization("Authorization code expired. Please try again.")
		return

	_fail_authorization("Twitch could not complete authorization: " + error_name)


func _handle_validate_response(response_code: int, response: Dictionary) -> void:
	if response_code < 200 or response_code >= 300:
		_fail_authorization("Twitch rejected the access token.")
		return

	var username: String = str(response.get("login", ""))
	if username.is_empty():
		_fail_authorization("Twitch did not return the authorized account name.")
		return

	_authorization_running = false
	_device_code = ""
	EventBus.twitch_auth_completed.emit(_access_token, username)
	EventBus.twitch_auth_status_changed.emit("Twitch account authorized.")


func _fail_authorization(message: String) -> void:
	_authorization_running = false
	_request_kind = ""
	_device_code = ""
	_access_token = ""
	_http.cancel_request()
	EventBus.twitch_auth_failed.emit(message)

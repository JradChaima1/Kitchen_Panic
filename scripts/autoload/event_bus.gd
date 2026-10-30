extends Node

signal chat_message_received(username: String, text: String)
signal item_guessed(username: String, item_id: String)
signal score_changed(username: String, total: int)
signal connection_status_changed(status: String)

signal twitch_auth_code_received(user_code: String, verification_uri: String, expires_in: int)
signal twitch_auth_status_changed(status: String)
signal twitch_auth_completed(access_token: String, username: String)
signal twitch_auth_failed(message: String)

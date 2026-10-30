extends Node
class_name ChatSource

## Base interface for chat providers.
## Subclasses should override start() and stop().

func start(_channel: String) -> void:
	push_error("ChatSource.start() must be implemented by a chat source.")


func stop() -> void:
	push_error("ChatSource.stop() must be implemented by a chat source.")

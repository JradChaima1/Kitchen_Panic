class_name DiningTable
extends Node3D

@export var table_id: int = 0
@export var is_occupied: bool = false

@onready var model_anchor: Node3D = $ModelAnchor
@onready var placeholder: Node3D = $Placeholder


func _ready() -> void:
	model_anchor.child_entered_tree.connect(_on_model_child_entered_tree)
	_update_placeholder_visibility()


func _on_model_child_entered_tree(_child: Node) -> void:
	_update_placeholder_visibility()


func _update_placeholder_visibility() -> void:
	placeholder.visible = model_anchor.get_child_count() == 0

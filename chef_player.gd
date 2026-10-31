extends CharacterBody3D

@export var walk_speed := 4.0
@export var turn_speed := 10.0
@export var mouse_sensitivity := 0.003
@export var min_camera_pitch := -10

@export var max_camera_pitch := 15.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var animation_player: AnimationPlayer
var chef_model: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var model_yaw_offset := 0.0


func _ready() -> void:
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

	if animation_player == null:
		push_error("Could not find the Mixamo AnimationPlayer under CharacterBody3D.")
		return

	chef_model = animation_player.get_parent() as Node3D
	if chef_model == null:
		push_error("The AnimationPlayer's parent must be a Node3D.")
		return

	model_yaw_offset = chef_model.rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotation.y -= event.relative.x * mouse_sensitivity
		spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x,
			deg_to_rad(min_camera_pitch),
			deg_to_rad(max_camera_pitch)
		)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var horizontal := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) \
		- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var forward_input := float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) \
		- float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))

	var move_input := Vector2(horizontal, forward_input)
	if move_input.length() > 1.0:
		move_input = move_input.normalized()

	var camera_forward := -spring_arm.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()

	var camera_right := spring_arm.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

	var move_direction := camera_right * move_input.x + camera_forward * move_input.y
	if move_direction.length() > 0.001:
		move_direction = move_direction.normalized()

	velocity.x = move_direction.x * walk_speed
	velocity.z = move_direction.z * walk_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if move_direction.length_squared() > 0.001 and chef_model != null:
		var target_yaw := atan2(-move_direction.x, -move_direction.z) + model_yaw_offset
		chef_model.rotation.y = lerp_angle(
			chef_model.rotation.y,
			target_yaw,
			turn_speed * delta
		)

	move_and_slide()

	if animation_player != null:
		var wanted_animation := "mixamo_com" if move_direction.length_squared() > 0.001 else "Dwarf Idle (1)/mixamo_com"
		if animation_player.current_animation != wanted_animation:
			animation_player.play(wanted_animation, 0.15)

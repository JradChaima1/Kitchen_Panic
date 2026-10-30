class_name DiningArea
extends Node3D

const DINING_TABLE_SCENE: PackedScene = preload("res://scenes/dining_table.tscn")

@onready var table_slots: Node3D = $TableSlots

var _tables: Array[DiningTable] = []


func _ready() -> void:
	_spawn_tables()


func get_free_table() -> DiningTable:
	for table: DiningTable in _tables:
		if not table.is_occupied:
			return table
	return null


func get_seat_positions(table_id: int) -> Array[Transform3D]:
	for table: DiningTable in _tables:
		if table.table_id != table_id:
			continue

		var seats: Array[Transform3D] = []
		for seat: Node in table.get_node("SeatSlots").get_children():
			if seat is Marker3D:
				seats.append(seat.global_transform)
		return seats
	return []


func _spawn_tables() -> void:
	var table_id: int = 1
	for slot: Node in table_slots.get_children():
		if not slot is Marker3D:
			continue

		var table: DiningTable = DINING_TABLE_SCENE.instantiate() as DiningTable
		table.name = "DiningTable%d" % table_id
		table.table_id = table_id
		table.add_to_group("tables")
		add_child(table)
		table.global_transform = (slot as Marker3D).global_transform
		_tables.append(table)
		table_id += 1

extends Node3D

@export var level: PackedScene

@onready var duch: Node3D = $Ghost

func _enter_tree() -> void:
	var level_instance: Node3D = level.instantiate()
	add_child(level_instance)
	
	$Player.position = level_instance.get_node("Start").position
	$Player.position.y += 1
	$Player.rotation.y = level_instance.get_node("Start").rotation.y
	
	#%Minimap.geometry.assign(level_instance.get_node("Geometry").find_children("*", "CSGBox3D"))
	%Minimap.geometry.assign(level_instance.get_node("Geometry").get_children())

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var dp: Vector2 = %Minimap.level.pick_random() * 2
	duch.position = Vector3(dp.x + 1, 0.5, dp.y + 1)

extends Node3D

@export var level: PackedScene

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		var level_instance: Node3D = level.instantiate()
		add_child(level_instance)
		
		$Player.position = level_instance.get_node("Start").position
		$Player.position.y += 1
		
		#%Minimap.geometry.assign(level_instance.get_node("Geometry").find_children("*", "CSGBox3D"))
		%Minimap.geometry.assign(level_instance.get_node("Geometry").get_children())

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

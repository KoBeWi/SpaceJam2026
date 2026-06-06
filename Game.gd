extends Node3D

@export var level: PackedScene

@onready var duch: Node3D = $Ghost
@onready var proximer: TextureProgressBar = %Proximer

@onready var player: CharacterBody3D = $Player
@onready var duch_orbital: Marker3D = %DuchOrbital

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

func _process(delta: float) -> void:
	var dist := player.global_position.distance_to(duch_orbital.global_position)
	if dist < 3:
		proximer.value = 5
	elif dist < 7:
		proximer.value = 4
	elif dist < 10:
		proximer.value = 4
	elif dist < 14:
		proximer.value = 3
	elif dist < 18:
		proximer.value = 2
	elif dist < 24:
		proximer.value = 1
	else:
		proximer.value = 0
	

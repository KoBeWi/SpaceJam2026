extends Node3D

@export var level: PackedScene

@onready var duch: Node3D = $Ghost
@onready var proximer: TextureProgressBar = %Proximer
@onready var detector_display: TextureRect = %DetectorDisplay
@onready var catcher: HBoxContainer = %Catcher
@onready var catcher_timeout: TextureProgressBar = %CatcherTimeout

@onready var player: CharacterBody3D = $Player
@onready var duch_orbital: Marker3D = %DuchOrbital
@onready var beeper: AudioStreamPlayer = %Beeper
@onready var proximanimator: AnimationPlayer = %Proximanimator

var current_item: int

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
	
	detector_display.hide()
	catcher.hide()

var beeper_max: float
var beeper_current: float

func _process(delta: float) -> void:
	catcher_timeout.value += delta
	
	if not proximer.visible:
		return
	
	var dist := player.global_position.distance_to(duch_orbital.global_position)
	if dist < 3:
		proximer.value = 5
		beeper_max = 0.5
	elif dist < 7:
		proximer.value = 4
		beeper_max = 1.0
	elif dist < 10:
		proximer.value = 4
		beeper_max = 2.0
	elif dist < 14:
		proximer.value = 3
		beeper_max = 4.0
	elif dist < 18:
		proximer.value = 2
		beeper_max = 8.0
	elif dist < 24:
		proximer.value = 1
		beeper_max = 16.0
	else:
		proximer.value = 0
		beeper_max = INF
	
	beeper_current += delta
	if beeper_current >= beeper_max:
		proximanimator.play(&"Beep")
		beeper_current = 0

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if %Winlabel.visible:
			if k.keycode == KEY_ESCAPE:
				get_tree().change_scene_to_file("uid://bvsjr5kk2hsxi")
			return
		
		match k.keycode:
			KEY_1:
				current_item = 0
			KEY_2:
				current_item = 1
			KEY_3:
				current_item = 2
			_:
				return
		
		proximer.visible = current_item == 0
		detector_display.visible = current_item == 1
		catcher.visible = current_item == 2
	
	if current_item != 2:
		return
	
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if not is_equal_approx(catcher_timeout.value, catcher_timeout.max_value):
			return
		
		%Throw.play()
		catcher_timeout.value = 0
		var box := preload("uid://btypyodrftaco").instantiate()
		box.position = player.position
		box.velocity = -player.global_basis.z * 3 + Vector3.UP * 4
		add_child(box)

func win():
	proximer.hide()
	detector_display.hide()
	catcher.hide()
	
	var scores := ConfigFile.new()
	scores.load("user://scores.cfg")
	scores.set_value("best", level.resource_path.get_file().get_basename(), %Timer.time)
	scores.save("user://scores.cfg")
	
	set_process(false)
	player.set_physics_process(false)
	%Winlabel.show()
	%Timer.hide()
	%Winlabel.text %= [%Timer.time / 60, fmod(%Timer.time, 60)]

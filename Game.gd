extends Node3D

@export var level: PackedScene
var level_instance: Node3D

@onready var duch: Node3D = $Ghost
@onready var proximer: TextureProgressBar = %Proximer
@onready var detector_display: TextureRect = %DetectorDisplay
@onready var catcher: HBoxContainer = %Catcher

@onready var player: CharacterBody3D = $Player
@onready var duch_orbital: Marker3D = %DuchOrbital
@onready var beeper: AudioStreamPlayer = %Beeper
@onready var proximanimator: AnimationPlayer = %Proximanimator

var current_item: int

func _enter_tree() -> void:
	level_instance = level.instantiate()
	add_child(level_instance)
	
	$Player.position = level_instance.get_node("Start").position
	$Player.position.y += 1
	$Player.rotation.y = level_instance.get_node("Start").rotation.y
	
	#%Minimap.geometry.assign(level_instance.get_node("Geometry").find_children("*", "CSGBox3D"))
	%Minimap.geometry.assign(level_instance.get_node("Geometry").get_children())

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var ghostwhere: Node3D = level_instance.get_node_or_null("Ghost")
	if ghostwhere:
		duch.position = ghostwhere.position
	else:
		for i in 1000:
			var dp: Vector2 = %Minimap.level.pick_random() * 2
			duch.position = Vector3(dp.x + 1, 0.5, dp.y + 1)
			
			if duch.position.distance_to($Player.position) > 20:
				break
	
	detector_display.hide()
	catcher.hide()

var beeper_max: float
var beeper_current: float

func _process(delta: float) -> void:
	if current_item != 0:
		%Noiser.stop()
		return
	if not %Noiser.playing:
		%Noiser.play()
		
	var dot_stuff = -player.global_basis.z.dot( player.global_position.direction_to(duch.global_position) )
	var dist :float= minf(player.global_position.distance_to(duch_orbital.global_position), 29.0) 
	dist +=  -dot_stuff * dist * 0.15
	if dist < 5:
		proximer.value = 5
	elif dist < 10:
		proximer.value = 4
	elif dist < 15:
		proximer.value = 3
	elif dist < 20:
		proximer.value = 2
	elif dist < 25:
		proximer.value = 1
	else:
		proximer.value = 0
	
	beeper_max = dist / 20.0
	var log_stuff = log(dist) / log(10)
	beeper_current += delta
	%Beeper.pitch_scale = 2.2-log_stuff
	%Beeper2.pitch_scale = 2.2-log_stuff
	%Noiser.pitch_scale = 1.60-log_stuff
	%Beeper.volume_db = - log_stuff*20.0
	%Beeper2.volume_db = - log_stuff*20.0
	%Noiser.volume_db = - (log_stuff*10.0+20)
	player.set_lights(1.0/beeper_max)
	
	if beeper_current >= beeper_max:
		proximanimator.play(&"Beep")
		beeper_current = 0

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if %Winlabel.visible or %Trup.visible:
			if k.keycode == KEY_ESCAPE:
				quot()
			return
		
		if player.cranging:
			return
		
		match k.keycode:
			KEY_1:
				current_item = 0
			KEY_2:
				current_item = 1
			KEY_3:
				current_item = 2
			KEY_T:
				$TrailMeshInstance.visible = not $TrailMeshInstance.visible
				return
			KEY_ESCAPE:
				%Menu.show()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				return
			_:
				return
		player.set_item(current_item)
		
		#proximer.visible = current_item == 0
		#detector_display.visible = current_item == 1
		#catcher.visible = current_item == 2
	
	if current_item != 2:
		return
	
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if not player.has_box or player.cranging:
			return
		
		%Throw.play()
		player.is_in_face = false
		player.animation_player.play("rest_pose")
		%CTextureRect.hide()
		%CLabel.hide()
		%CLabel2.show()
		
		player.throwbox()
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
	var old_best: float = scores.get_value("best", level.resource_path.get_file().get_basename(), INF)
	if old_best > %Timer.time:
		scores.set_value("best", level.resource_path.get_file().get_basename(), %Timer.time)
		scores.save("user://scores.cfg")
	
	set_process(false)
	player.set_physics_process(false)
	%Winlabel.show()
	%Timer.hide()
	%Winlabel.text %= [%Timer.time / 60, fmod(%Timer.time, 60)]
	if old_best > %Timer.time:
		%Winlabel.text += "\nNowy best!"

func over_game():
	%Trup.show()
	set_process(false)
	player.set_physics_process(false)

func contineu():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	%Menu.hide()

func quot() -> void:
	get_tree().change_scene_to_file("uid://bvsjr5kk2hsxi")

func _on_player_gotbox() -> void:
	%CTextureRect.show()
	%CLabel.show()
	%CLabel2.hide()

extends CharacterBody3D
@export var player_handle:CharacterBody3D

var złapan: bool

func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($Orbit, ^"rotation:y", TAU, 10.0).from(0)

func _physics_process(delta: float) -> void:
	if randi_range(0, 10) == 0:
		velocity = Vector3.RIGHT.rotated(Vector3.UP, randi_range(0, 3) * (PI/2)) * 1.0
	move_and_slide()
	var player_v2 := Vector2(player_handle.global_position.x,player_handle.global_position.z) 
	%StaticBody3D.rotation.y = -Vector2(global_position.x, global_position.z).angle_to_point(player_v2)

func catch():
	if złapan:
		return
	złapan = true
	set_physics_process(false)
	
	$Sprite3D.show()
	$AudioStreamPlayer3D.play()
	%Timer.set_process(false)
	
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property($Sprite3D, "modulate:a", 0.0, 0.5)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)
	tween.tween_callback(owner.win)

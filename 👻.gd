extends CharacterBody3D

@export var player_handle:CharacterBody3D
@export var bodies: Array[Node3D]

var poltergowalne: Array[RigidBody3D]

var złapan: bool

func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($Orbit, ^"rotation:y", TAU, 10.0).from(0)
	
	var mybody = bodies.pick_random()
	$Sprite3D.texture = [preload("uid://dt3fnvecekspq"), preload("uid://bfnoffvme3xhb"), preload("uid://i57ofe5h800m"), preload("uid://12frpuotdemc")][bodies.find(mybody)]
	
	for body in bodies:
		if body != mybody:
			body.queue_free()
	
	await owner.ready
	
	poltergowalne.assign(owner.find_children("*", "RigidBody3D", true, false))

func _physics_process(delta: float) -> void:
	if randi_range(0, 10) == 0:
		velocity = Vector3.RIGHT.rotated(Vector3.UP, randi_range(0, 3) * (PI/2)) * 1.0
	
	angry -= delta
	
	move_and_slide()
	var player_v2 := Vector2(player_handle.global_position.x,player_handle.global_position.z) 
	
	if is_instance_valid(bodies[0]):
		bodies[0].rotation.y = -Vector2(global_position.x, global_position.z).angle_to_point(player_v2)
	elif is_instance_valid(bodies[1]):
		bodies[1].rotation.y = -Vector2(global_position.x, global_position.z).angle_to_point(player_v2)
	elif is_instance_valid(bodies[3]):
		bodies[3].rotation.y = -Vector2(global_position.x, global_position.z).angle_to_point(player_v2)
	elif is_instance_valid(bodies[2]):
		bodies[2].rotation.y += PI * delta

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

var angry: float

func scanned():
	angry += 1
	
	if angry >= 200:
		angry -= 200
		
		for box in poltergowalne:
			var dist := box.global_position.distance_to(player_handle.global_position)
			var dir := box.global_position.direction_to(player_handle.global_position) + Vector3.UP
			box.apply_impulse(dir * (10.0 / dist))

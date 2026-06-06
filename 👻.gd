extends CharacterBody3D

func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($Orbit, ^"rotation:y", TAU, 10.0).from(0)

func _physics_process(delta: float) -> void:
	if randi_range(0, 10) == 0:
		velocity = Vector3.RIGHT.rotated(Vector3.UP, randi_range(0, 3) * (PI/2)) * 4
	move_and_slide()

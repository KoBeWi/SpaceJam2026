extends OmniLight3D


var target_energy := 1.0

func _physics_process(_delta: float) -> void:
	light_energy = move_toward(light_energy, target_energy, 0.3)


func _on_timer_timeout() -> void:
	target_energy = 0.8 + randf() * 0.4
	%Timer.start(0.2 + randf() * 0.1)

extends MeshInstance3D

var lifetime:= 1.0
var decay := 1.0

func _ready() -> void:
	pass # Replace with function body.

func setup(in_dist:float)->void:
	
	var reduced_lifetime = (40.0 - in_dist) / 40.0
	decay = 1.0 / reduced_lifetime
	material_override.albedo_color = Color.from_hsv(reduced_lifetime * 0.8, 0.8, 0.9)

func _process(delta: float) -> void:
	lifetime -= delta * decay
	material_override.albedo_color.a = lifetime
	if lifetime <= 0.0:
		queue_free()

extends MeshInstance3D

var lifetime:= 15.0

func _ready() -> void:
	pass # Replace with function body.

func setup(in_dist:float)->void:
	var reduced_lifetime = (lifetime - in_dist) / 15.0
	material_override.albedo_color = Color.from_hsv(reduced_lifetime * 0.8, 0.8, 0.9)
	lifetime = reduced_lifetime * 5.0

func _process(delta: float) -> void:
	lifetime -= delta
	material_override.albedo_color.a = lifetime
	if lifetime <= 0.0:
		queue_free()

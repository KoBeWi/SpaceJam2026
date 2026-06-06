extends Panel

var geometry: Node

func _draw() -> void:
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5))
	
	for node: CSGBox3D in geometry.get_children():
		if node.size.y > 1:
			var pos2d := Vector2(node.position.x, node.position.z)
			var size2d := Vector2(node.size.x, node.size.z) * 0.5
			
			if size2d.x > size2d.y:
				size2d.y = 0
				draw_line(pos2d - size2d, pos2d + size2d, Color.GREEN)
			else:
				size2d.x = 0
				draw_line(pos2d - size2d, pos2d + size2d, Color.GREEN)

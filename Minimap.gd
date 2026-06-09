extends TextureRect

const TILE_SIZE = 10

@export var player: Node3D

@onready var player_icon: Sprite2D = $PlayerIcon

var geometry: Array[Node]

var level: Array[Vector2]
var level_shift: Vector2

func _ready() -> void:
	var minv := Vector2.INF
	var maxv := -Vector2.INF
	
	for node in geometry:
		if node.name.begins_with("RoomTile"):
			var pos2d := Vector2(node.position.x, node.position.z)
			pos2d -= Vector2.ONE
			pos2d /= 2
			
			minv = minv.min(pos2d)
			maxv = maxv.max(pos2d + Vector2.ONE)
			
			level.append(pos2d)
	
	#level_shift = size * 0.5 - (maxv + minv) * 0.5 * TILE_SIZE
	#level_shift = (maxv - minv) * 0.5
	var sc := size / TILE_SIZE
	level_shift = sc / 2 - (maxv - minv) * 0.5 - minv

func _process(_delta: float) -> void:
	player_icon.position = (Vector2(player.position.x, player.position.z) * 0.5 + level_shift) * TILE_SIZE
	player_icon.rotation = -player.rotation.y

func _draw() -> void:
	#draw_set_transform(level_shift)
	
	for coords in level:
		draw_rect(Rect2((coords + level_shift) * TILE_SIZE, Vector2.ONE * TILE_SIZE), Color.SEA_GREEN)
	
	#draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5))
	#
	#for node in geometry:
		#if node.size.y > 1:
			#var pos2d := Vector2(node.global_position.x, node.global_position.z) * SCALE
			#var size2d := Vector2(node.size.x, node.size.z) * 0.5 * SCALE
			#size2d = size2d.rotated(node.rotation.y)
			#
			#if size2d.x > size2d.y:
				#size2d.y = 0
				#draw_line(pos2d - size2d, pos2d + size2d, Color.GREEN)
			#else:
				#size2d.x = 0
				#draw_line(pos2d - size2d, pos2d + size2d, Color.GREEN)

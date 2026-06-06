extends Node3D

const MARKER_3D = preload("res://Scanner/marker_3d.tscn")

@onready var ray_sound: AudioStreamPlayer = %RaySound
@onready var detector_display: TextureRect = %DetectorDisplay

@export var ray_length: float = 10.0
@export var trail_fade_seconds: float = 1.5

@export var trail_mesh_instance:MeshInstance3D
@export var player_handle:CharacterBody3D
var trail_mesh:ImmediateMesh

var ray_max_distance := 40.0
var ray_dispersion := 0.1
var ray_spread := 0.1
var trail_segments: Array[Dictionary] = []
var trail_material: StandardMaterial3D

var pitch_array :PackedInt32Array
var array_iterator := 0

func _ready() -> void:
	trail_mesh = trail_mesh_instance.mesh
	pitch_array.resize(40)
	pitch_array.fill(0)
	_setup_material()

func _physics_process(delta: float) -> void:
	#_update_trail(delta)
	for i in 3:
		array_iterator = (array_iterator+1) % 40
		pitch_array[array_iterator] = 0
		_fire_ray_and_record()
		
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pitch_array.fill(0)

func _fire_ray_and_record() -> void:
	var vector_forward := -player_handle.global_basis.z
	var ray_start :Vector3= player_handle.camera_3d.global_position 
	ray_start += player_handle.global_basis.x * randf_range(-ray_spread, ray_spread) 
	ray_start += player_handle.global_basis.y * randf_range(-ray_spread, ray_spread)

	var direction:= vector_forward + Vector3.UP.rotated(vector_forward, randf() * TAU) * randf() * ray_dispersion
	var ray_end := ray_start + direction.normalized() * ray_max_distance

	var ray := Vector3.FORWARD
	var distance := 0.0
	var bounce := 0
	while bounce < 5 :
		ray = ray_end - ray_start
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 14)
		var collision := get_world_3d().direct_space_state.intersect_ray(query)
		var segment_end := ray_end

		if not collision.is_empty():
			distance += ray_start.distance_to(collision.position)
			if distance > ray_max_distance:
				return
			if collision.collider.name == "Detector":
				
				spawn_marker(collision.collider.to_local(collision.position), distance)
			segment_end = collision.position
			ray = ray.bounce(collision.normal)
			

		#trail_segments.append({
			#"start": ray_start,
			#"end": segment_end,
			#"age": 0.0,
			#"idx": bounce
		#})
		ray_start = segment_end
		ray_end = ray_start + ray
		bounce += 1

	_rebuild_trail_mesh()


func _update_trail(delta: float) -> void:
	if trail_segments.is_empty():
		return

	for segment in trail_segments:
		segment.age += delta

	trail_segments = trail_segments.filter(func(segment: Dictionary) -> bool:
		return segment.age < trail_fade_seconds
	)

	_rebuild_trail_mesh()


func _rebuild_trail_mesh() -> void:
	trail_mesh.clear_surfaces()

	if trail_segments.is_empty():
		return

	trail_mesh.surface_begin(Mesh.PRIMITIVE_LINES, trail_material)

	for segment in trail_segments:
		var alpha :float = 1.0 - (segment.age / trail_fade_seconds)
		var color := Color.from_hsv(segment.idx/7.0,1.0,1.0)
		color.a = clamp(alpha, 0.0, 1.0)
		#var color := Color(1.0, 0.75, 0.2, clamp(alpha, 0.0, 1.0))
		trail_mesh.surface_set_color(color)
		trail_mesh.surface_add_vertex(segment.start)
		color = Color.from_hsv((segment.idx+1)/7.0,1.0,1.0)
		color.a = clamp(alpha, 0.0, 1.0)
		trail_mesh.surface_set_color(color)
		trail_mesh.surface_add_vertex(segment.end)
	trail_mesh.surface_end()

func spawn_marker(in_position: Vector3, in_distance:float) -> void:
	if detector_display.visible:
		var idx :int = floori(in_distance)
		if not pitch_array[idx]:
			pitch_array[idx] = 1
			ray_sound.pitch_scale = 20.0 / in_distance
			ray_sound.play()
	
	var marker = MARKER_3D.instantiate()
	marker.position = Vector3( in_position.x, in_position.z,0.0)
	marker.setup(in_distance)
	%SubViewport.add_child(marker)

func _setup_material() -> void:
	trail_material = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo = true
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.no_depth_test = true

extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var fleshlight_movement:Vector2
var cumulator := 0.0
var is_walking :bool = false
var lerp_target := 0.0
var is_scaner_in_face:= false
var pk_emiter_lights_value:=0.0
var pk_emiter_mat:Material
var pk_emiter_mat1:Material
var pk_emiter_mat2:Material
var radar_slider_mat:Material
var has_box: bool = true
var cranging: bool
var current_item_id :int = 0


@onready var items_camera_3d: Camera3D = %ItemsCamera3D

@onready var radar: MeshInstance3D = $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/Radar
@onready var radar_slider := $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/Radar/Radar_slider
@onready var pk_detector: MeshInstance3D = $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/PK_Detector

@onready var pk_l_arm: MeshInstance3D = $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/PK_Detector/PK_L_arm
@onready var pk_r_arm: MeshInstance3D = $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/PK_Detector/PK_R_arm

@onready var trap: MeshInstance3D = $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/Trap
@onready var trap_handle: MeshInstance3D = $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/Trap/Trap_handle
@onready var trap_switch := $CanvasLayer/SubVpContainer/ItemViewport/ItemsCamera3D/Scanner/Trap/Trap_switch

@onready var animation_player: AnimationPlayer = %AnimationPlayer

@export var detector_vp:SubViewport
@export var minimap_vp:SubViewport

@onready var camera_3d: Camera3D = %Camera3D
@onready var flashlight: SpotLight3D = %Flashlight

@export var duch: Node3D

signal gotbox

func _ready() -> void:
	var mat :Material= radar.get_surface_override_material(1)
	pk_emiter_mat = pk_detector.get_surface_override_material(2)
	pk_emiter_mat1 = pk_l_arm.get_surface_override_material(0)
	pk_emiter_mat2 = pk_r_arm.get_surface_override_material(0)
	
	radar_slider_mat = radar_slider.get_surface_override_material(0)

	var pk_emiter_mat_body = pk_detector.get_surface_override_material(1)
	pk_emiter_mat_body.albedo_texture = minimap_vp.get_texture()
	pk_emiter_mat_body.emission_texture = minimap_vp.get_texture()
	mat.albedo_texture = detector_vp.get_texture()
	mat.emission_texture = detector_vp.get_texture()

func set_item(in_id:int)->void:
	current_item_id = in_id
	match in_id:
		0:
			trap.hide()
			radar.hide()
			pk_detector.show()
			pk_l_arm.show()
			pk_r_arm.show()
		1:
			trap.hide()
			radar.show()
			pk_detector.hide()
			pk_l_arm.hide()
			pk_r_arm.hide()
		2:
			trap.visible = has_box
			radar.hide()
			pk_detector.hide()
			pk_l_arm.hide()
			pk_r_arm.hide()
			#%AnimationPlayer.play("ChargeTrap")


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", &"forward", &"backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		cumulator += delta * 10.0
		cumulator = fmod(cumulator, TAU)
		is_walking = true
	else:
		if is_walking:
			is_walking = false
			if cumulator < PI*0.5:
				lerp_target = 0.0
			elif cumulator < PI*1.5:
				lerp_target = PI
			else:
				lerp_target = TAU
			
		cumulator = lerp(cumulator, lerp_target, 0.1)
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	flashlight.position.y = abs(sin(cumulator))*0.1
	flashlight.position.x = cos(cumulator)*0.1
	
	var dist := duch.global_position.distance_to(global_position)
	if dist < 3:
		flashlight.visible = randf_range(0, 3) < dist
	else:
		flashlight.visible = true
	
	move_and_slide()
	if get_slide_collision_count() > 0:
		var box = get_slide_collision(0).get_collider()
		if box.get(&"can_pickup"):
			box.queue_free()
			has_box = true
			set_item(2)
			cranging = true
			owner.current_item = 2
			$AnimationPlayer.play(&"ChargeTrap")
			await $AnimationPlayer.animation_finished
			if owner.current_item == 2:
				trap.show()
			cranging = false
			gotbox.emit()
	
	pk_emiter_mat1.uv1_offset.x -= pk_emiter_lights_value * delta
	pk_emiter_mat2.uv1_offset.x -= pk_emiter_lights_value * delta

	items_camera_3d.global_transform = camera_3d.global_transform
	
func set_lights(in_value:float, in_dot_to_ghost:float):
	pk_emiter_lights_value = 5.0 * in_value
	pk_emiter_mat1.emission_energy_multiplier = pk_emiter_lights_value
	pk_emiter_mat2.emission_energy_multiplier = pk_emiter_lights_value
	pk_l_arm.rotation.z = -pk_emiter_lights_value*0.3
	pk_r_arm.rotation.z = pk_emiter_lights_value*0.3 
	pk_emiter_mat.uv1_offset.y = ((in_dot_to_ghost*0.1+0.1)+in_value)*0.1
	

func _input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		rotation.y -= mm.relative.x * (1.0 / TAU ** 3)
		camera_3d.rotation.x = clampf(camera_3d.rotation.x - mm.relative.y * (1.0 / TAU ** 3),-PI * 0.49,PI * 0.49)
	
	var mb := event as InputEventMouseButton
	if mb: 
		if mb.button_index == MOUSE_BUTTON_RIGHT and not cranging:
			if mb.pressed:
				is_scaner_in_face = not is_scaner_in_face
		
			if is_scaner_in_face:
				%AnimationPlayer.play("in_face")
			else:
				%AnimationPlayer.play("rest_pose")
	
		if current_item_id == 1:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				update_slider(1)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				update_slider(-1)
				
				

func update_slider(in_value:int):
	var new_ray_max_distance :int= get_parent().ray_draw.ray_max_distance +  in_value
	new_ray_max_distance = clampi(new_ray_max_distance, 10, 40)
	if not get_parent().ray_draw.ray_max_distance == new_ray_max_distance:
		%ClicksStreamPlayer3D.pitch_scale = 0.85 + new_ray_max_distance / 15.0
		%ClicksStreamPlayer3D.play()
		get_parent().ray_draw.update_ray_max_distance(new_ray_max_distance)
		%Label3D.text = str("Range: ",new_ray_max_distance,"m")
		radar_slider.position.x = get_parent().ray_draw.ray_max_distance * 0.03 - 0.3
		radar_slider_mat.uv1_offset.x = radar_slider.position.x

func throwbox():
	has_box = false
	trap.hide()

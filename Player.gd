extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var fleshlight_movement:Vector2
var cumulator := 0.0
var is_walking :bool = false
var lerp_target := 0.0
var is_scaner_in_face:= false
var pk_emiter_lights_value:=0.0
var pk_emiter_mat1:Material
var pk_emiter_mat2:Material

@onready var radar: MeshInstance3D = $Camera3D/Scanner/Radar

@onready var pk_detector: MeshInstance3D = $Camera3D/Scanner/PK_Detector

@onready var pk_l_arm: MeshInstance3D = $Camera3D/Scanner/PK_L_arm
@onready var pk_r_arm: MeshInstance3D = $Camera3D/Scanner/PK_R_arm

@export var detector_vp:SubViewport
@export var minimap_vp:SubViewport

@onready var camera_3d: Camera3D = %Camera3D
@onready var flashlight: SpotLight3D = %Flashlight

@export var duch: Node3D


func _ready() -> void:
	var mat :Material= radar.get_surface_override_material(1)
	pk_emiter_mat1 = %Scanner.get_node("PK_L_arm").get_surface_override_material(0)
	pk_emiter_mat2 = %Scanner.get_node("PK_R_arm").get_surface_override_material(0)

	var pk_emiter_mat_body = %Scanner.get_node("PK_Detector").get_surface_override_material(1)
	pk_emiter_mat_body.albedo_texture = minimap_vp.get_texture()
	pk_emiter_mat_body.emission_texture = minimap_vp.get_texture()
	mat.albedo_texture = detector_vp.get_texture()
	mat.emission_texture = detector_vp.get_texture()

func set_item(in_id:int)->void:
	match in_id:
		0:
			radar.hide()
			pk_detector.show()
			pk_l_arm.show()
			pk_r_arm.show()
		1:
			radar.show()
			pk_detector.hide()
			pk_l_arm.hide()
			pk_r_arm.hide()
		2:
			radar.hide()
			pk_detector.hide()
			pk_l_arm.hide()
			pk_r_arm.hide()
		
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
		
	flashlight.position.y = sin(cumulator)*0.1
	flashlight.position.x = abs(cos(cumulator)*0.1)
	
	var dist := duch.global_position.distance_to(global_position)
	if dist < 3:
		flashlight.visible = randf_range(0, 3) < dist
	else:
		flashlight.visible = true
	
	move_and_slide()
	
	pk_emiter_mat1.uv1_offset.x -= pk_emiter_lights_value * delta * 1.0
	pk_emiter_mat2.uv1_offset.x -= pk_emiter_lights_value * delta * 1.0
	pk_l_arm.rotation.z = -min(pk_emiter_lights_value*0.2, 1.5)
	pk_r_arm.rotation.z = pk_l_arm.rotation.z
	
func set_lights(in_value:float):
	pk_emiter_lights_value = in_value
	

func _input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		rotation.y -= mm.relative.x * (1.0 / TAU ** 3)
		
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			is_scaner_in_face = not is_scaner_in_face
	
		if is_scaner_in_face:
			%AnimationPlayer.play("in_face")
		else:
			%AnimationPlayer.play("rest_pose")

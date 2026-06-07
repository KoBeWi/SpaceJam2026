extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var fleshlight_movement:Vector2
var cumulator := 0.0
var is_walking :bool = false
var lerp_target := 0.0
var is_scaner_in_face:= false

@export var detector_vp:SubViewport

@onready var camera_3d: Camera3D = %Camera3D
@onready var flashlight: SpotLight3D = %Flashlight

@export var duch: Node3D

func _ready() -> void:
	var scanner :MeshInstance3D= %Scanner.get_node("Cube")
	var mat :Material= scanner.get_surface_override_material(1)
	mat.albedo_texture = detector_vp.get_texture()
	mat.emission_texture = detector_vp.get_texture()
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if not is_scaner_in_face:
			is_scaner_in_face = true
			%AnimationPlayer.play("in_face")
	elif is_scaner_in_face:
		is_scaner_in_face = false
		%AnimationPlayer.play("rest_pose")
		
	

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

func _input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		rotation.y -= mm.relative.x * (1.0 / TAU ** 3)

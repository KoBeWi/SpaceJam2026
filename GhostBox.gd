extends RigidBody3D

@onready var shoot_sfx: AudioStreamPlayer3D = $ShootSFX
@onready var hit_sfx: AudioStreamPlayer3D = $HitSFX

func shoot(vel: Vector3):
	shoot_sfx.volume_db = vel.length() - 20
	shoot_sfx.play()
	apply_impulse(vel)


func _on_body_entered(body: Node) -> void:
	if linear_velocity.length() > 0.1:
		#hit_sfx.play()
		%AnimationPlayer.play(str("Hit_",randi()%5+1))
		

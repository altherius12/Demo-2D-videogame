extends CharacterBody2D

@export var speed: float = 150.0
@export var max_walk_frames: int = 0
@export var walk_animation: StringName = &"idle_Right"
@export var idle_animation: StringName = &"idle_Right"
@export var forehead_animation: StringName = &"idle_forehead"
@export var flip_with_mouse_when_idle: bool = false

@export_group("Weapon Settings")
@export var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@export var fire_rate: float = 0.2
@export var bullet_speed: float = 420.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var muzzle: Marker2D

var _is_resetting_frame: bool = false
var _is_looking_front: bool = false
var _fire_cooldown: float = 0.0
var _weapon_base_x: float = 11.0

func _ready() -> void:
	_setup_weapon()
	if animated_sprite:
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
		_play_idle()

func _physics_process(delta: float) -> void:
	var pressing_s := Input.is_action_pressed("move_down") or Input.is_physical_key_pressed(KEY_S)
	var direction := Input.get_axis("move_left", "move_right")

	if pressing_s:
		# Al pulsar la tecla S, el robot se detiene y mira de frente (idle_forehead)
		_is_looking_front = true
		velocity.x = 0.0
		if animated_sprite:
			animated_sprite.flip_h = false
			_play_forehead()
	elif direction != 0.0:
		# Al moverse con A o D, deja de mirar de frente y camina sincronizando los ojos con el mouse
		_is_looking_front = false
		velocity.x = direction * speed
		if animated_sprite:
			# Sprite_Right_Sync mira hacia la izquierda sin voltear (flip_h = false)
			animated_sprite.flip_h = direction > 0.0
			_play_walk()
	else:
		# Detenido: mantiene idle_forehead si se pulsó S, o idle_Right sincronizado con el mouse
		velocity.x = 0.0
		if _is_looking_front:
			_play_forehead()
		else:
			if flip_with_mouse_when_idle and animated_sprite:
				var ref_pos := weapon_pivot.global_position if weapon_pivot else animated_sprite.global_position
				animated_sprite.flip_h = get_global_mouse_position().x > ref_pos.x
			_play_idle()

	move_and_slide()
	_update_weapon(delta)

func _setup_weapon() -> void:
	weapon_pivot = get_node_or_null("WeaponPivot") as Node2D
	if not weapon_pivot:
		weapon_pivot = Node2D.new()
		weapon_pivot.name = "WeaponPivot"
		weapon_pivot.position = Vector2(0, -22)
		add_child(weapon_pivot)

	weapon_sprite = weapon_pivot.get_node_or_null("WeaponSprite") as Sprite2D
	if not weapon_sprite:
		weapon_sprite = Sprite2D.new()
		weapon_sprite.name = "WeaponSprite"
		weapon_sprite.position = Vector2(_weapon_base_x, 0)
		weapon_pivot.add_child(weapon_sprite)

	if not weapon_sprite.texture:
		weapon_sprite.texture = _create_weapon_texture()

	muzzle = weapon_pivot.get_node_or_null("Muzzle") as Marker2D
	if not muzzle:
		muzzle = Marker2D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector2(20, -1)
		weapon_pivot.add_child(muzzle)

func _update_weapon(delta: float) -> void:
	if not weapon_pivot:
		return

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	# Apuntar el arma hacia el cursor del ratón
	var mouse_pos := get_global_mouse_position()
	weapon_pivot.look_at(mouse_pos)

	# Voltear verticalmente el sprite del arma al apuntar hacia la izquierda
	if weapon_sprite:
		var aiming_left := cos(weapon_pivot.rotation) < 0.0
		weapon_sprite.flip_v = aiming_left
		muzzle.position.y = 1.0 if aiming_left else -1.0
		# Recuperar suavemente la posición tras el retroceso del disparo
		weapon_sprite.position.x = move_toward(weapon_sprite.position.x, _weapon_base_x, 35.0 * delta)

	# Disparar con Clic Izquierdo o barra espaciadora
	var wants_to_shoot := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_action_pressed("ui_accept") \
		or Input.is_physical_key_pressed(KEY_SPACE)

	if wants_to_shoot and _fire_cooldown <= 0.0:
		_shoot()

func _shoot() -> void:
	if not bullet_scene or not muzzle or not weapon_pivot:
		return

	_fire_cooldown = fire_rate

	var bullet := bullet_scene.instantiate() as Area2D
	if not bullet:
		return

	var shoot_dir := Vector2.RIGHT.rotated(weapon_pivot.global_rotation)
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = weapon_pivot.global_rotation
	bullet.set("direction", shoot_dir)
	bullet.set("speed", bullet_speed)

	var parent_scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent_scene.add_child(bullet)

	# Pequeño efecto de retroceso (recoil) en el arma al disparar
	if weapon_sprite:
		weapon_sprite.position.x = _weapon_base_x - 3.5

func _create_weapon_texture() -> Texture2D:
	if ResourceLoader.exists("res://weapon.png"):
		var loaded := load("res://weapon.png") as Texture2D
		if loaded:
			return loaded

	var img := Image.create(18, 9, false, Image.FORMAT_RGBA8)
	var c_black := Color8(0, 0, 0, 255)
	var c_metal := Color8(138, 111, 48, 255)
	var c_cyan := Color8(25, 245, 255, 255)
	var c_pink := Color8(255, 25, 239, 255)
	var rows := [
		"....BBBBBBBBBB....",
		"...BMMMMMMMMMMBB..",
		"..BMCCCCCCCCCCMMB.",
		"..BMMBBBBBBBBMMCPB",
		"..BMMMMMMMMMMMMCPB",
		"...BBBBMMMMBBBBBB.",
		"....BMMM..BMB.....",
		"...BMMB....BB.....",
		"...BBB............"
	]
	for y in range(9):
		for x in range(18):
			var ch: String = rows[y][x]
			match ch:
				"B": img.set_pixel(x, y, c_black)
				"M": img.set_pixel(x, y, c_metal)
				"C": img.set_pixel(x, y, c_cyan)
				"P": img.set_pixel(x, y, c_pink)
	return ImageTexture.create_from_image(img)

func _play_forehead() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	var anim_to_play := _get_forehead_animation_name()
	if anim_to_play != &"":
		if not animated_sprite.is_playing() or animated_sprite.animation != anim_to_play:
			animated_sprite.play(anim_to_play)

func _play_walk() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	if walk_animation == &"idle_Right":
		var synced_anim := _get_mouse_synced_idle_animation_name()
		_play_animation(synced_anim, true)
		return

	var anim_to_play := _get_walk_animation_name()
	if anim_to_play != &"":
		_play_animation(anim_to_play, false)

func _play_idle() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	var anim_to_play := _get_idle_animation_name()
	if anim_to_play != &"":
		_play_animation(anim_to_play, anim_to_play.begins_with("idle_Right"))
	else:
		if animated_sprite.is_playing():
			animated_sprite.stop()
		animated_sprite.frame = 0

func _play_animation(anim_to_play: StringName, preserve_frame: bool) -> void:
	if anim_to_play == &"" or not animated_sprite or not animated_sprite.sprite_frames:
		return
	if not animated_sprite.sprite_frames.has_animation(anim_to_play):
		return

	if animated_sprite.animation != anim_to_play:
		var prev_frame := animated_sprite.frame
		var prev_progress := animated_sprite.frame_progress
		animated_sprite.play(anim_to_play)
		if preserve_frame:
			var frame_count := animated_sprite.sprite_frames.get_frame_count(anim_to_play)
			if frame_count > 0:
				animated_sprite.set_frame_and_progress(prev_frame % frame_count, prev_progress)
	elif not animated_sprite.is_playing():
		animated_sprite.play(anim_to_play)

func _get_forehead_animation_name() -> StringName:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return &""

	if animated_sprite.sprite_frames.has_animation(forehead_animation) \
	and animated_sprite.sprite_frames.get_frame_count(forehead_animation) > 0:
		return forehead_animation

	if animated_sprite.sprite_frames.has_animation(&"idle_forehead") \
	and animated_sprite.sprite_frames.get_frame_count(&"idle_forehead") > 0:
		return &"idle_forehead"

	for anim in animated_sprite.sprite_frames.get_animation_names():
		if "forehead" in anim.to_lower() and animated_sprite.sprite_frames.get_frame_count(anim) > 0:
			return anim

	return &""

func _get_idle_animation_name() -> StringName:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return &""

	if idle_animation == &"idle_Right":
		var synced_anim := _get_mouse_synced_idle_animation_name()
		if synced_anim != &"":
			return synced_anim

	if animated_sprite.sprite_frames.has_animation(idle_animation) \
	and animated_sprite.sprite_frames.get_frame_count(idle_animation) > 0:
		return idle_animation

	if animated_sprite.sprite_frames.has_animation(&"Idle_stay") \
	and animated_sprite.sprite_frames.get_frame_count(&"Idle_stay") > 0:
		return &"Idle_stay"
	
	if animated_sprite.sprite_frames.has_animation(&"Idle_quiet") \
	and animated_sprite.sprite_frames.get_frame_count(&"Idle_quiet") > 0:
		return &"Idle_quiet"

	for anim in animated_sprite.sprite_frames.get_animation_names():
		if "idle" in anim.to_lower() and animated_sprite.sprite_frames.get_frame_count(anim) > 0:
			return anim
	
	return &""

func _get_mouse_synced_idle_animation_name() -> StringName:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return &""

	var origin := weapon_pivot.global_position if weapon_pivot else animated_sprite.global_position
	var aim := get_global_mouse_position() - origin
	# Sprite_Right_Sync mira hacia la izquierda cuando flip_h = false
	if animated_sprite.flip_h:
		aim.x = -aim.x

	var angle_deg := rad_to_deg(atan2(aim.y, aim.x))
	var target_anim: StringName
	if absf(angle_deg) >= 150.0:
		target_anim = &"idle_Right"
	elif angle_deg >= -150.0 and angle_deg < -105.0:
		target_anim = &"idle_Right_up_forward"
	elif angle_deg >= -105.0 and angle_deg < -30.0:
		target_anim = &"idle_Right_up"
	elif absf(angle_deg) <= 30.0:
		target_anim = &"idle_Right_back"
	elif angle_deg > 30.0 and angle_deg <= 105.0:
		target_anim = &"idle_Right_down"
	else:
		target_anim = &"idle_Right_down_forward"

	if animated_sprite.sprite_frames.has_animation(target_anim) \
	and animated_sprite.sprite_frames.get_frame_count(target_anim) > 0:
		return target_anim

	if animated_sprite.sprite_frames.has_animation(&"idle_Right") \
	and animated_sprite.sprite_frames.get_frame_count(&"idle_Right") > 0:
		return &"idle_Right"

	return &""

func _get_walk_animation_name() -> StringName:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return &""
	
	if animated_sprite.sprite_frames.has_animation(walk_animation):
		return walk_animation
	
	for anim in animated_sprite.sprite_frames.get_animation_names():
		if "walk" in anim.to_lower() or "move" in anim.to_lower() or "new" in anim.to_lower():
			if animated_sprite.sprite_frames.get_frame_count(anim) > 0:
				return anim

	return &""

func _on_frame_changed() -> void:
	if _is_resetting_frame or not animated_sprite:
		return

	if velocity.x != 0.0 and max_walk_frames > 0 and animated_sprite.frame >= max_walk_frames:
		_is_resetting_frame = true
		animated_sprite.frame = 0
		_is_resetting_frame = false

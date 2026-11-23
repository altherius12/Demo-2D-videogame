extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal died

@export var speed: float = 150.0
@export var max_walk_frames: int = 0
@export var walk_animation: StringName = &"idle_Right"
@export var idle_animation: StringName = &"idle_Right"
@export var forehead_animation: StringName = &"idle_forehead"
@export var flip_with_mouse_when_idle: bool = false
@export var forehead_center_deadzone: float = 16.0

@export_group("Health Settings")
@export var max_health: int = 100
@export var invulnerability_time: float = 0.6

@export_group("Weapon Settings")
@export_enum("Revolver", "Submachine") var starting_weapon: int = 1
@export var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@export var fire_rate: float = 0.11
@export var bullet_speed: float = 340.0

const WEAPON_CONFIGS := [
	{
		"name": "Revolver",
		"texture_path": "res://weapon.png",
		"fire_rate": 0.55,
		"bullet_speed": 240.0,
		"muzzle_offset": Vector2(22.0, -3.0),
	},
	{
		"name": "Submachine",
		"texture_path": "res://Weapons/Submachine_gun_01.png",
		"fire_rate": 0.11,
		"bullet_speed": 340.0,
		"muzzle_offset": Vector2(22.0, -2.0),
	},
]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_fill: ColorRect = get_node_or_null("HealthBarBg/HealthBarFill") as ColorRect
@onready var health_label: Label = get_node_or_null("HealthBarBg/HealthLabel") as Label

var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var weapon_sprites: Array[Sprite2D] = []
var muzzle: Marker2D

enum FacingMode { SIDE, FRONT }

var _is_resetting_frame: bool = false
var _facing_mode: FacingMode = FacingMode.SIDE
var _fire_cooldown: float = 0.0
var _weapon_base_x: float = 11.0
var _current_weapon_index: int = 1
var _muzzle_offset: Vector2 = Vector2(22.0, -2.0)
var _health: int = 100
var _invulnerability_timer: float = 0.0
var _health_bar_width: float = 194.0
var _is_dead: bool = false

func _ready() -> void:
	_health = maxi(max_health, 1)
	if health_fill:
		_health_bar_width = health_fill.size.x
	_update_health_bar()
	_setup_weapon()
	if animated_sprite:
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
		_play_idle()

func _physics_process(delta: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta
	if _is_dead:
		return
	var pressing_w := Input.is_action_pressed("move_up") or Input.is_physical_key_pressed(KEY_W)
	var pressing_s := Input.is_action_pressed("move_down") or Input.is_physical_key_pressed(KEY_S)
	var move_x := Input.get_axis("move_left", "move_right")
	var move_y := (-1.0 if pressing_w else 0.0) + (1.0 if pressing_s else 0.0)
	var input_vector := Vector2(move_x, move_y)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	velocity = input_vector * speed

	if move_y != 0.0:
		# Al pulsar W o S, avanza arriba/abajo usando la animación sincronizada idle_forehead
		_facing_mode = FacingMode.FRONT
		if animated_sprite:
			animated_sprite.flip_h = false
			_play_forehead()
	elif move_x != 0.0:
		# Al moverse con A o D, avanza lateralmente sincronizando los ojos con el mouse
		_facing_mode = FacingMode.SIDE
		if animated_sprite:
			# Sprite_Right_Sync mira hacia la izquierda sin voltear (flip_h = false)
			animated_sprite.flip_h = move_x > 0.0
			_play_walk()
	else:
		# Detenido: conserva la última orientación (idle_forehead o idle_Right)
		match _facing_mode:
			FacingMode.FRONT:
				_play_forehead()
			FacingMode.SIDE:
				if flip_with_mouse_when_idle and animated_sprite:
					var ref_pos := weapon_pivot.global_position if weapon_pivot else animated_sprite.global_position
					animated_sprite.flip_h = get_global_mouse_position().x > ref_pos.x
				_play_idle()

	move_and_slide()
	_update_weapon(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			_equip_weapon(0)
		KEY_2:
			_equip_weapon(1)
		KEY_Q:
			_equip_weapon((_current_weapon_index + 1) % WEAPON_CONFIGS.size())

func _setup_weapon() -> void:
	weapon_pivot = get_node_or_null("WeaponPivot") as Node2D
	if not weapon_pivot:
		weapon_pivot = Node2D.new()
		weapon_pivot.name = "WeaponPivot"
		weapon_pivot.position = Vector2(0, -22)
		add_child(weapon_pivot)

	weapon_sprites.clear()
	for cfg in WEAPON_CONFIGS:
		var node_name: String = cfg["name"]
		var tex_path: String = cfg["texture_path"]
		var node := weapon_pivot.get_node_or_null(node_name) as Sprite2D
		if not node:
			node = Sprite2D.new()
			node.name = node_name
			node.position = Vector2(_weapon_base_x, 0)
			weapon_pivot.add_child(node)
		if not node.texture and ResourceLoader.exists(tex_path):
			var loaded := load(tex_path) as Texture2D
			if loaded:
				node.texture = loaded
		if not node.texture:
			node.texture = _create_weapon_texture()
		weapon_sprites.append(node)

	muzzle = weapon_pivot.get_node_or_null("Muzzle") as Marker2D
	if not muzzle:
		muzzle = Marker2D.new()
		muzzle.name = "Muzzle"
		muzzle.position = _muzzle_offset
		weapon_pivot.add_child(muzzle)

	_equip_weapon(starting_weapon)

func _equip_weapon(index: int) -> void:
	var clamped_idx := clampi(index, 0, WEAPON_CONFIGS.size() - 1)
	_current_weapon_index = clamped_idx
	var cfg: Dictionary = WEAPON_CONFIGS[clamped_idx]
	fire_rate = cfg["fire_rate"]
	bullet_speed = cfg["bullet_speed"]
	_muzzle_offset = cfg["muzzle_offset"]

	for i in range(weapon_sprites.size()):
		var node := weapon_sprites[i]
		node.visible = (i == clamped_idx)
		node.position.x = _weapon_base_x
		if i == clamped_idx:
			weapon_sprite = node

	if muzzle:
		muzzle.position = _muzzle_offset

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
		if muzzle:
			muzzle.position.x = _muzzle_offset.x
			muzzle.position.y = absf(_muzzle_offset.y) if aiming_left else -absf(_muzzle_offset.y)
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
		_play_animation(anim_to_play, anim_to_play.begins_with("idle_forehead"))

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

	if forehead_animation == &"idle_forehead":
		var synced_anim := _get_mouse_synced_forehead_animation_name()
		if synced_anim != &"":
			return synced_anim

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

	return _pick_available_animation(target_anim, &"idle_Right")

func _get_mouse_synced_forehead_animation_name() -> StringName:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return &""

	var origin := weapon_pivot.global_position if weapon_pivot else animated_sprite.global_position
	var aim := get_global_mouse_position() - origin
	if aim.length() < forehead_center_deadzone:
		return _pick_available_animation(&"idle_forehead", &"idle_forehead")

	var angle_deg := rad_to_deg(atan2(aim.y, aim.x))
	var target_anim: StringName
	if absf(angle_deg) > 157.5:
		target_anim = &"idle_forehead_left"
	elif angle_deg >= -157.5 and angle_deg < -112.5:
		target_anim = &"idle_forehead_up_left"
	elif angle_deg >= -112.5 and angle_deg < -67.5:
		target_anim = &"idle_forehead_up"
	elif angle_deg >= -67.5 and angle_deg < -22.5:
		target_anim = &"idle_forehead_up_right"
	elif absf(angle_deg) <= 22.5:
		target_anim = &"idle_forehead_right"
	elif angle_deg > 22.5 and angle_deg <= 67.5:
		target_anim = &"idle_forehead_down_right"
	elif angle_deg > 67.5 and angle_deg <= 112.5:
		target_anim = &"idle_forehead_down"
	else:
		target_anim = &"idle_forehead_down_left"

	return _pick_available_animation(target_anim, &"idle_forehead")

func _pick_available_animation(target_anim: StringName, fallback_anim: StringName) -> StringName:
	if animated_sprite.sprite_frames.has_animation(target_anim) \
	and animated_sprite.sprite_frames.get_frame_count(target_anim) > 0:
		return target_anim

	if animated_sprite.sprite_frames.has_animation(fallback_anim) \
	and animated_sprite.sprite_frames.get_frame_count(fallback_anim) > 0:
		return fallback_anim

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

func take_damage(amount: int = 20) -> void:
	if _is_dead or _invulnerability_timer > 0.0 or amount <= 0:
		return

	_health = maxi(_health - amount, 0)
	_invulnerability_timer = invulnerability_time
	health_changed.emit(_health, max_health)
	_update_health_bar()

	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.18)

	if _health <= 0:
		_die()

func _update_health_bar() -> void:
	var max_hp := maxi(max_health, 1)
	var ratio := clampf(float(_health) / float(max_hp), 0.0, 1.0)
	if health_fill:
		health_fill.size.x = _health_bar_width * ratio
		if ratio > 0.5:
			health_fill.color = Color(0.2, 0.95, 0.35, 1.0)
		elif ratio > 0.25:
			health_fill.color = Color(1.0, 0.8, 0.15, 1.0)
		else:
			health_fill.color = Color(1.0, 0.25, 0.25, 1.0)
	if health_label:
		health_label.text = "%d / %d" % [_health, max_hp]

func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	died.emit()
	if is_inside_tree() and get_tree().current_scene:
		var timer := get_tree().create_timer(0.35)
		timer.timeout.connect(_reload_after_death)

func _reload_after_death() -> void:
	if is_inside_tree() and get_tree().current_scene:
		get_tree().reload_current_scene()

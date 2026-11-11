extends CharacterBody2D

@export var speed: float = 150.0
@export var max_walk_frames: int = 4
@export var walk_animation: StringName = &"new_animation"
@export var idle_animation: StringName = &"Idle_stay"
@export var forehead_animation: StringName = &"idle_forehead"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_resetting_frame: bool = false
var _is_looking_front: bool = false

func _ready() -> void:
	if animated_sprite:
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
		_play_idle()

func _physics_process(_delta: float) -> void:
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
		# Al moverse con A o D, deja de mirar de frente y camina hacia los lados
		_is_looking_front = false
		velocity.x = direction * speed
		if animated_sprite:
			animated_sprite.flip_h = direction < 0.0
			_play_walk()
	else:
		# Detenido: mantiene idle_forehead si se pulsó S, o Idle_stay si venía caminando
		velocity.x = 0.0
		if _is_looking_front:
			_play_forehead()
		else:
			_play_idle()

	move_and_slide()

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
	
	var anim_to_play := _get_walk_animation_name()
	if anim_to_play == &"":
		return

	if not animated_sprite.is_playing() or animated_sprite.animation != anim_to_play:
		animated_sprite.play(anim_to_play)

func _play_idle() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	var anim_to_play := _get_idle_animation_name()
	if anim_to_play != &"":
		if not animated_sprite.is_playing() or animated_sprite.animation != anim_to_play:
			animated_sprite.play(anim_to_play)
	else:
		if animated_sprite.is_playing():
			animated_sprite.stop()
		animated_sprite.frame = 0

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

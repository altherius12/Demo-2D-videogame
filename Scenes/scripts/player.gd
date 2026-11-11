extends CharacterBody2D

## Velocidad de movimiento del personaje (puedes ajustarla desde el Inspector)
@export var speed: float = 150.0

## Cantidad de frames a reproducir al moverse (por defecto 4: frames 0, 1, 2 y 3)
## Puedes cambiar este valor a 2 en el Inspector si prefieres usar solo los 2 primeros frames
@export var max_walk_frames: int = 4

## Nombre de la animación al caminar / moverse
@export var walk_animation: StringName = &"new_animation"

## Nombre de la animación en reposo
@export var idle_animation: StringName = &"Idle_quiet"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_resetting_frame: bool = false

func _ready() -> void:
	if animated_sprite:
		# Conectar la señal de cambio de fotograma
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
		_play_idle()

func _physics_process(_delta: float) -> void:
	# Detecta si se pulsa 'A' (move_left) o 'D' (move_right)
	var direction := Input.get_axis("move_left", "move_right")

	if direction != 0.0:
		velocity.x = direction * speed
		if animated_sprite:
			# Orientar el sprite a la dirección correspondiente
			animated_sprite.flip_h = direction < 0.0
			_play_walk()
	else:
		# Detener el movimiento inmediatamente al soltar las teclas
		velocity.x = 0.0
		_play_idle()

	move_and_slide()

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
		# Reproducir la animación de reposo continuamente
		if not animated_sprite.is_playing() or animated_sprite.animation != anim_to_play:
			animated_sprite.play(anim_to_play)
	else:
		# Si no hay animación de idle, detener en frame 0
		if animated_sprite.is_playing():
			animated_sprite.stop()
		animated_sprite.frame = 0

func _get_idle_animation_name() -> StringName:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return &""
	
	# 1. Comprobar la configurada en el inspector (por defecto Idle_quiet)
	if animated_sprite.sprite_frames.has_animation(idle_animation) \
	and animated_sprite.sprite_frames.get_frame_count(idle_animation) > 0:
		return idle_animation
	
	# 2. Comprobar si existe "Idle_quiet"
	if animated_sprite.sprite_frames.has_animation(&"Idle_quiet") \
	and animated_sprite.sprite_frames.get_frame_count(&"Idle_quiet") > 0:
		return &"Idle_quiet"

	# 3. Comprobar si existe "Idle_stay"
	if animated_sprite.sprite_frames.has_animation(&"Idle_stay") \
	and animated_sprite.sprite_frames.get_frame_count(&"Idle_stay") > 0:
		return &"Idle_stay"

	# 4. Buscar cualquier animación que contenga "idle" y tenga fotogramas
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

	# Solo limitar los frames cuando se esté moviendo para evitar que ruede la llanta
	# En reposo (idle), la animación se reproduce completa de forma natural
	if velocity.x != 0.0 and max_walk_frames > 0 and animated_sprite.frame >= max_walk_frames:
		_is_resetting_frame = true
		animated_sprite.frame = 0
		_is_resetting_frame = false

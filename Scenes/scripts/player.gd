extends CharacterBody2D

## Velocidad de movimiento del personaje (puedes ajustarla desde el Inspector)
@export var speed: float = 150.0

## Cantidad de frames a reproducir al moverse (por defecto 4: frames 0, 1, 2 y 3)
## Puedes cambiar este valor a 2 en el Inspector si prefieres usar solo los 2 primeros frames
@export var max_walk_frames: int = 4

## Nombre de la animación al caminar / moverse
@export var walk_animation: StringName = &"new_animation"

## Nombre de la animación en reposo (opcional)
@export var idle_animation: StringName = &"Idle_stay"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_resetting_frame: bool = false

func _ready() -> void:
	if animated_sprite:
		# Conectar la señal de cambio de fotograma de forma segura
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
	
	# Determinar qué animación usar de forma segura
	var anim_to_play := walk_animation
	if not animated_sprite.sprite_frames.has_animation(anim_to_play):
		# Si no existe walk_animation, usar la animación actualmente asignada al nodo
		if animated_sprite.animation != &"" and animated_sprite.sprite_frames.has_animation(animated_sprite.animation):
			anim_to_play = animated_sprite.animation
		else:
			return

	if not animated_sprite.is_playing() or animated_sprite.animation != anim_to_play:
		animated_sprite.play(anim_to_play)

func _play_idle() -> void:
	if not animated_sprite:
		return

	# Si la animación de reposo existe y tiene fotogramas, reproducirla
	if animated_sprite.sprite_frames \
	and animated_sprite.sprite_frames.has_animation(idle_animation) \
	and animated_sprite.sprite_frames.get_frame_count(idle_animation) > 0:
		if not animated_sprite.is_playing() or animated_sprite.animation != idle_animation:
			animated_sprite.play(idle_animation)
	else:
		# De lo contrario, simplemente detener y mantener el fotograma 0
		if animated_sprite.is_playing():
			animated_sprite.stop()
		animated_sprite.frame = 0

func _on_frame_changed() -> void:
	if _is_resetting_frame or not animated_sprite:
		return

	# Si se está moviendo y alcanza el límite de frames configurado, vuelve al frame 0
	# Esto evita que se reproduzcan los frames posteriores donde rueda la llanta
	if velocity.x != 0.0 and max_walk_frames > 0 and animated_sprite.frame >= max_walk_frames:
		_is_resetting_frame = true
		animated_sprite.frame = 0
		_is_resetting_frame = false

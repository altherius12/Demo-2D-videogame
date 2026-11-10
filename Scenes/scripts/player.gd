extends CharacterBody2D

## Velocidad de movimiento del personaje (puedes ajustarla desde el Inspector)
@export var speed: float = 150.0

## Cantidad de frames a reproducir al moverse (por defecto 4: frames 0, 1, 2 y 3)
## Puedes cambiar este valor a 2 en el Inspector si prefieres usar solo los 2 primeros frames
@export var max_walk_frames: int = 4

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_resetting_frame: bool = false

func _ready() -> void:
	# El robot empieza quieto sin reproducir la animación
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.frame = 0
		animated_sprite.frame_changed.connect(_on_frame_changed)

func _physics_process(_delta: float) -> void:
	# Detecta si se pulsa 'A' (move_left) o 'D' (move_right)
	var direction := Input.get_axis("move_left", "move_right")

	# Si se pulsa A o D
	if direction != 0.0:
		velocity.x = direction * speed
		# Orientar el sprite a la dirección correspondiente
		animated_sprite.flip_h = direction < 0.0
		
		# Reproducir la animación mientras se mueva
		if not animated_sprite.is_playing():
			animated_sprite.play("idle_down")
	else:
		# Detener el movimiento inmediatamente al soltar las teclas
		velocity.x = 0.0
		
		# Detener la animación y volver a la pose de reposo (frame 0)
		if animated_sprite.is_playing():
			animated_sprite.stop()
			animated_sprite.frame = 0

	move_and_slide()

func _on_frame_changed() -> void:
	if _is_resetting_frame:
		return

	# Si se está moviendo y alcanza el límite de frames, vuelve al frame 0
	# Esto evita que se reproduzcan los frames posteriores donde rueda la llanta
	if velocity.x != 0.0 and animated_sprite.frame >= max_walk_frames:
		_is_resetting_frame = true
		animated_sprite.frame = 0
		_is_resetting_frame = false

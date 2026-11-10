extends CharacterBody2D

## Velocidad de movimiento del personaje (puedes ajustarla desde el Inspector)
@export var speed: float = 150.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# El robot empieza quieto sin reproducir la animación
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.frame = 0

func _physics_process(_delta: float) -> void:
	# Detecta si se pulsa 'A' (move_left) o 'D' (move_right)
	var direction := Input.get_axis("move_left", "move_right")

	# Si se pulsa A o D
	if direction != 0.0:
		velocity.x = direction * speed
		# Orientar el sprite a la dirección correspondiente
		animated_sprite.flip_h = direction < 0.0
		
		# Reproducir la animación de caminar mientras se mueva
		if not animated_sprite.is_playing():
			animated_sprite.play("idle_down")
	else:
		# Detener el movimiento inmediatamente al soltar las teclas
		velocity.x = 0.0
		
		# Detener la animación y volver a la pose de reposo
		if animated_sprite.is_playing():
			animated_sprite.stop()
			animated_sprite.frame = 0

	move_and_slide()

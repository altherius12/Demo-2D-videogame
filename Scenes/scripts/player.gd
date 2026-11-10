extends CharacterBody2D

## Velocidad de movimiento del personaje (puedes ajustarla desde el Inspector)
@export var speed: float = 150.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Inicia la animación de tu personaje al comenzar el juego
	if animated_sprite:
		animated_sprite.play("idle_down")

func _physics_process(_delta: float) -> void:
	# Obtener la dirección horizontal (-1 izquierda, 1 derecha, 0 quieto)
	# Usamos las acciones 'move_left' (tecla A) y 'move_right' (tecla D) que configuraste
	var direction := Input.get_axis("move_left", "move_right")

	# Si no se presiona A/D, permitimos también usar las flechas del teclado
	if direction == 0.0:
		direction = Input.get_axis("ui_left", "ui_right")

	# Aplicar velocidad según la dirección
	if direction != 0.0:
		velocity.x = direction * speed
		# Voltear el sprite horizontalmente al cambiar de dirección
		animated_sprite.flip_h = direction < 0.0
	else:
		# Frenar suavemente cuando no se presione ninguna tecla
		velocity.x = move_toward(velocity.x, 0.0, speed)

	# Mover el CharacterBody2D usando el motor de físicas de Godot
	move_and_slide()

extends Area2D

@export var speed: float = 420.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if sprite and not sprite.texture:
		sprite.texture = _create_bullet_texture()
	
	# Destruir el proyectil automáticamente después de su tiempo de vida
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	# Evitar que colisione con el propio jugador
	if body.name == "player" or body is CharacterBody2D:
		return
	queue_free()

func _create_bullet_texture() -> Texture2D:
	if ResourceLoader.exists("res://bullet.png"):
		var loaded := load("res://bullet.png") as Texture2D
		if loaded:
			return loaded
			
	var img := Image.create(10, 5, false, Image.FORMAT_RGBA8)
	var c_black := Color8(0, 0, 0, 255)
	var c_cyan := Color8(25, 245, 255, 255)
	var c_white := Color8(255, 255, 255, 255)
	var c_pink := Color8(255, 25, 239, 255)
	var rows := [
		"..BBBBBB..",
		".BCCCCCCB.",
		"BCWWWWWWPB",
		".BCCCCCCB.",
		"..BBBBBB.."
	]
	for y in range(5):
		for x in range(10):
			var ch: String = rows[y][x]
			match ch:
				"B": img.set_pixel(x, y, c_black)
				"C": img.set_pixel(x, y, c_cyan)
				"W": img.set_pixel(x, y, c_white)
				"P": img.set_pixel(x, y, c_pink)
	return ImageTexture.create_from_image(img)

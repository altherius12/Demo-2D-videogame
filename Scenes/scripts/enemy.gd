extends CharacterBody2D

signal died

@export var speed: float = 75.0
@export var stop_distance: float = 18.0
@export var follow_offset: Vector2 = Vector2(0, -22)
@export var max_health: int = 3
@export var contact_damage: int = 20
@export var attack_cooldown: float = 0.8
@export var hover_amplitude: float = 2.0
@export var hover_speed: float = 4.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_fill: ColorRect = $HealthBarBg/HealthBarFill
@onready var hitbox: Area2D = get_node_or_null("Hitbox") as Area2D

var _target: Node2D
var _health: int
var _hover_time: float = 0.0
var _base_sprite_y: float = 0.0
var _health_bar_width: float = 18.0
var _attack_timer: float = 0.0

func _ready() -> void:
	_health = maxi(max_health, 1)
	add_to_group("enemies")
	if sprite:
		_base_sprite_y = sprite.position.y
		sprite.play(&"idle")
	if health_fill:
		_health_bar_width = health_fill.size.x
	_update_health_bar()
	_find_target()

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta

	if not is_instance_valid(_target):
		_find_target()
		if not is_instance_valid(_target):
			velocity = Vector2.ZERO
			_update_hover(delta)
			return

	var target_pos := _target.global_position + follow_offset
	var to_target := target_pos - global_position
	var distance := to_target.length()

	if distance > stop_distance:
		var direction := to_target / distance
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	if sprite and absf(to_target.x) > 1.0:
		# enemy.png mira hacia la derecha sin voltear (flip_h = false)
		sprite.flip_h = to_target.x < 0.0

	move_and_slide()
	_try_contact_damage()
	_update_hover(delta)

func _try_contact_damage() -> void:
	if _attack_timer > 0.0 or not hitbox:
		return
	for body in hitbox.get_overlapping_bodies():
		if (body.name == "player" or body.is_in_group("player")) and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			_attack_timer = attack_cooldown
			return

func _update_hover(delta: float) -> void:
	if not sprite:
		return
	_hover_time += delta * hover_speed
	sprite.position.y = _base_sprite_y + sin(_hover_time) * hover_amplitude

func _find_target() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node2D
	if not _target and get_tree().current_scene:
		_target = get_tree().current_scene.find_child("player", true, false) as Node2D

func _update_health_bar() -> void:
	if not health_fill:
		return
	var max_hp := float(maxi(max_health, 1))
	var ratio := clampf(float(_health) / max_hp, 0.0, 1.0)
	health_fill.size.x = _health_bar_width * ratio
	if ratio > 0.5:
		health_fill.color = Color(0.2, 0.95, 0.35, 1.0)
	elif ratio > 0.25:
		health_fill.color = Color(1.0, 0.8, 0.15, 1.0)
	else:
		health_fill.color = Color(1.0, 0.25, 0.25, 1.0)

func take_damage(amount: int = 1) -> void:
	if _health <= 0:
		return
	_health = maxi(_health - amount, 0)
	_update_health_bar()
	if sprite:
		sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if _health <= 0:
		died.emit()
		queue_free()

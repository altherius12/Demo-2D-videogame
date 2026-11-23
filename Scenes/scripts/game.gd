extends Node2D

@export var enemy_scene: PackedScene = preload("res://Scenes/enemy.tscn")
@export var max_enemies: int = 2
@export var respawn_delay: float = 2.0
@export var spawn_distance_x: float = 110.0
@export var spawn_offset_y_range: Vector2 = Vector2(-45.0, 10.0)
@export var arena_bounds: Rect2 = Rect2(-116.0, -148.0, 216.0, 168.0)

func _ready() -> void:
	randomize()
	var existing := 0
	for child in get_children():
		if child.is_in_group("enemies"):
			_register_enemy(child)
			existing += 1

	for _i in range(maxi(0, max_enemies - existing)):
		_spawn_enemy()

func _register_enemy(enemy: Node) -> void:
	if enemy.has_signal("died"):
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
	elif not enemy.tree_exited.is_connected(_on_enemy_died):
		enemy.tree_exited.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	if not is_inside_tree():
		return
	var timer := get_tree().create_timer(respawn_delay)
	timer.timeout.connect(_on_respawn_timeout)

func _on_respawn_timeout() -> void:
	if not is_inside_tree():
		return
	var active_count := get_tree().get_nodes_in_group("enemies").size()
	if active_count < max_enemies:
		_spawn_enemy()

func _spawn_enemy() -> void:
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate() as Node2D
	if not enemy:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var center := player.global_position if player else global_position
	var side := -1.0 if randf() < 0.5 else 1.0
	if center.x - spawn_distance_x < arena_bounds.position.x:
		side = 1.0
	elif center.x + spawn_distance_x > arena_bounds.end.x:
		side = -1.0
	var offset_y := randf_range(spawn_offset_y_range.x, spawn_offset_y_range.y)
	var spawn_x := clampf(center.x + side * spawn_distance_x, arena_bounds.position.x, arena_bounds.end.x)
	var spawn_y := clampf(center.y + offset_y, arena_bounds.position.y, arena_bounds.end.y)
	enemy.global_position = Vector2(spawn_x, spawn_y)

	add_child(enemy)
	_register_enemy(enemy)

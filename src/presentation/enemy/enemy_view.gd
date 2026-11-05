class_name EnemyView extends Node2D
## Drawer 3: enemy keylines first, then bodies (heavy, normal, fast order from the model).

var model: EnemyViewModel = null


func _draw() -> void:
	if model == null:
		return
	for i: int in range(model.count):
		draw_circle(model.positions[i], ViewStyles.ENEMY_RADIUS + 2.0, ViewStyles.KEYLINE)
	for i: int in range(model.count):
		draw_circle(model.positions[i], ViewStyles.ENEMY_RADIUS, model.colors[i])

class_name Interactable
extends StaticBody3D
## Basit etkileşim noktası. Oyuncu bakınca prompt gösterilir, E/butonla action çağrılır.

var prompt_func: Callable
var action: Callable


static func create(parent: Node3D, size: Vector3, pos: Vector3, prompt: Callable, act: Callable) -> Interactable:
	var it := Interactable.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	it.add_child(cs)
	it.position = pos
	it.prompt_func = prompt
	it.action = act
	it.set_meta("interact", it)
	# 2. katman: oyuncunun bakış ışını görür ama yürümeyi ve müşteri yolunu kapatmaz
	it.collision_layer = 2
	it.collision_mask = 0
	parent.add_child(it)
	return it


func get_prompt() -> String:
	return prompt_func.call() if prompt_func.is_valid() else ""


func interact(player: Node) -> void:
	if action.is_valid():
		action.call(player)

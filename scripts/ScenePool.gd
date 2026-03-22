extends RefCounted
class_name ScenePool

var scene: PackedScene
var storage_root: Node
var inactive: Array[Node] = []


func _init(packed_scene: PackedScene, storage_node: Node) -> void:
	scene = packed_scene
	storage_root = storage_node


func warmup(count: int) -> void:
	for _index in count:
		var instance := _create_instance()
		release(instance)


func acquire(active_parent: Node) -> Node:
	if active_parent == null or not is_instance_valid(active_parent):
		return null

	var instance: Node = null
	while not inactive.is_empty():
		var candidate = inactive.pop_back()
		if candidate != null and is_instance_valid(candidate):
			instance = candidate
			break
	if instance == null:
		instance = _create_instance()

	if instance.get_parent() != null:
		instance.get_parent().remove_child(instance)
	active_parent.add_child(instance)
	if instance.has_method("on_pool_acquire"):
		instance.call("on_pool_acquire")
	return instance


func release(instance: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	if storage_root == null or not is_instance_valid(storage_root):
		return
	if instance.get_parent() != null:
		instance.get_parent().remove_child(instance)
	if instance.get_parent() != storage_root:
		storage_root.add_child(instance)
	if inactive.has(instance):
		return
	if instance.has_method("on_pool_release"):
		instance.call("on_pool_release")
	inactive.append(instance)


func _create_instance() -> Node:
	var instance: Node = scene.instantiate()
	return instance

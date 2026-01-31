extends SceneTree

# 这个脚本继承自 SceneTree，可以直接作为 Godot 的入口执行
func _init():
	print("--- 专用服务器启动脚本 ---")
	
	# 加载主场景
	var main_scene_resource = load("res://scene/main.tscn")
	var main_scene = main_scene_resource.instantiate()
	
	# 将主场景添加到根节点
	root.add_child.call_deferred(main_scene)
	
	# 启动服务器逻辑
	# 延迟调用确保 main_scene 的 _ready 已运行
	main_scene.call_deferred("start_dedicated_server")
	
	print("服务器逻辑已载入")

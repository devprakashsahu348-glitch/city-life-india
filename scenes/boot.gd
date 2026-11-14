extends Node
## Boot: restores the last guest/dev session if any, then routes to menu or login.

func _ready() -> void:
	if AuthManager.restore_session():
		Game.go_to.call_deferred(Game.SCENE_MENU)
	else:
		Game.go_to.call_deferred(Game.SCENE_LOGIN)

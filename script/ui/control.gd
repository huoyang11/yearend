extends TouchScreenButton
@export var text = ""

func _ready() -> void:
	$Control.text = text

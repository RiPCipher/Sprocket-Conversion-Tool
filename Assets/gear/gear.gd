extends Node3D

func _ready():
	pass

func _process(delta):
	# Loops gear animation
	rotation.y -= delta * TAU * 0.05

@tool
extends Node3D

@export var grid_size: int = 10
@export var grid_divisions: int = 10
@export var primary_grid_color: Color = Color(0.5, 0.5, 0.5, 0.4)
@export var secondary_grid_color: Color = Color(0.3, 0.3, 0.3, 0.2)
@export var x_axis_color: Color = Color(1, 0.3, 0.3, 1.0)
@export var y_axis_color: Color = Color(0.3, 1.0, 0.3, 1.0)
@export var z_axis_color: Color = Color(0.3, 0.3, 1.0, 1.0)
var axis_line_width: float = 3.0
var visible_in_game: bool = true

@onready var grid_mesh = $GridMesh
@onready var x_axis = $XAxis
@onready var y_axis = $YAxis
@onready var z_axis = $ZAxis

func _ready():
	update_grid()
	visible = visible_in_game

func update_grid():
	var grid_material = StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.vertex_color_use_as_albedo = true
	grid_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, grid_material)

	for i in range(-grid_size, grid_size + 1):
		var color = primary_grid_color if i % (grid_size / grid_divisions) == 0 else secondary_grid_color
		if i == 0:
			continue
			
		# X axis lines
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(i, 0, -grid_size))
		mesh.surface_add_vertex(Vector3(i, 0, grid_size))
		
		# Z axis lines
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(-grid_size, 0, i))
		mesh.surface_add_vertex(Vector3(grid_size, 0, i))
	
	mesh.surface_end()
	grid_mesh.mesh = mesh
	
	update_axis(x_axis, Vector3(-grid_size, 0, 0), Vector3(grid_size, 0, 0), x_axis_color)
	update_axis(y_axis, Vector3(0, -grid_size, 0), Vector3(0, grid_size, 0), y_axis_color)
	update_axis(z_axis, Vector3(0, 0, -grid_size), Vector3(0, 0, grid_size), z_axis_color)

func update_axis(axis_node, start, end, color):
	var mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	
	material.render_priority = 1
	
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	
	axis_node.mesh = mesh

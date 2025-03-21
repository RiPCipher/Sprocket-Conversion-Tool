class_name BlueprintConverter
extends Node

signal conversion_complete(result)
signal progress_updated(value: float)

# Threading
var _thread: Thread
var _mutex: Mutex
var _semaphore: Semaphore
var _exit_thread := false
var _current_task := {}

# Status flags
var _conversion_in_progress := false
var _status_message := ""

# Hard limits
var max_vertices := 8000
var max_faces := 4000
var max_edges := 12000

func _init():
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()

func _exit_tree():
	_exit_thread = true
	if _thread and _thread.is_started():
		_semaphore.post()
		_thread.wait_to_finish()

# Start a worker thread for processing
func _start_worker_thread():
	if _thread and _thread.is_started():
		return
		
	_thread = Thread.new()
	_thread.start(Callable(self, "_thread_function"))

func _thread_function():
	while true:
		_semaphore.wait()
		
		_mutex.lock()
		if _exit_thread:
			_mutex.unlock()
			break
			
		var task = _current_task.duplicate()
		_mutex.unlock()
		
		if task.is_empty():
			continue
		
		var result = {}
		
		if task.type == "obj_to_blueprint":
			result = _process_obj_to_blueprint(
				task.obj_path, 
				task.blueprint_name, 
				task.blueprint_dir,
				task.vertex_limit,
				task.face_limit,
				task.edge_limit
			)
		elif task.type == "blueprint_to_obj":
			result = _process_blueprint_to_obj(
				task.blueprint_path,
				task.output_path
			)
			
		# Send result back to main thread
		call_deferred("_on_thread_completed", result)

func _on_thread_completed(result):
	_conversion_in_progress = false
	emit_signal("conversion_complete", result)

# Update progress
func _update_progress(progress: float):
	call_deferred("emit_signal", "progress_updated", progress)
	print(progress) # For Debug

# Convert OBJ to Blueprint
func convert_OBJToBlueprint(obj_path: String, blueprint_name: String, blueprint_dir: String, 
							vertex_limit: int = -1, face_limit: int = -1, edge_limit: int = -1) -> Dictionary:
	# Prevent multiple conversions at once
	if _conversion_in_progress:
		return {"error": "A conversion is already in progress"}
	
	# Validate inputs
	if obj_path.is_empty():
		return {"error": "Please select an input OBJ file"}
		
	if blueprint_dir.is_empty() or !DirAccess.dir_exists_absolute(blueprint_dir):
		return {"error": "Invalid blueprint directory"}
	
	# Use default limits if not specified
	if vertex_limit <= 0:
		vertex_limit = max_vertices
	if face_limit <= 0:
		face_limit = max_faces
	if edge_limit <= 0:
		edge_limit = max_edges
	
	_conversion_in_progress = true
	
	# Start the worker thread if it's not already running
	_start_worker_thread()
	
	# Set up the task for the worker thread
	_mutex.lock()
	_current_task = {
		"type": "obj_to_blueprint",
		"obj_path": obj_path,
		"blueprint_name": blueprint_name,
		"blueprint_dir": blueprint_dir,
		"vertex_limit": vertex_limit,
		"face_limit": face_limit,
		"edge_limit": edge_limit
	}
	_mutex.unlock()
	
	# Signal the worker thread to start processing
	_semaphore.post()
	
	return {"status": "processing"}

# Process OBJ to Blueprint in worker thread
func _process_obj_to_blueprint(obj_path: String, blueprint_name: String, blueprint_dir: String,
							  vertex_limit: int, face_limit: int, edge_limit: int) -> Dictionary:
	_update_progress(0.1)
	
	# Read OBJ file
	var file = FileAccess.open(obj_path, FileAccess.READ)
	if file == null:
		return {"error": "Failed to open OBJ file - " + str(FileAccess.get_open_error())}
	
	var file_size = file.get_length()
	var bytes_processed = 0
	
	# Pre-allocate arrays for vertices and faces
	var obj_vertices = []
	var obj_faces = []
	
	# Process in chunks for better memory usage
	var chunk_size = 8192
	var line_buffer = ""
	
	# Parse OBJ file in chunks
	while not file.eof_reached():
		var chunk = file.get_buffer(chunk_size)
		bytes_processed += chunk.size()
		
		# Convert buffer to string and append to line buffer
		var chunk_text = chunk.get_string_from_utf8()
		line_buffer += chunk_text
		
		# Process complete lines
		var lines = Array(line_buffer.split("\n"))
		if lines.size() > 0:
			line_buffer = lines.pop_back()
		else:
			line_buffer = ""
		
		for line in lines:
			line = line.strip_edges()
			
			if line.begins_with("v "):
				var parts = line.split(" ", false)
				if parts.size() >= 4:
					# Store original OBJ vertices
					obj_vertices.append([
						float(parts[1]),      # X
						float(parts[2]),      # Y
						float(parts[3])       # Z
					])
			elif line.begins_with("f "):
				var parts = line.split(" ", false)
				if parts.size() >= 3:
					var face_indices = []
					for i in range(1, parts.size()):
						var vert_parts = parts[i].split("/")
						face_indices.append(int(vert_parts[0]) - 1)
					obj_faces.append(face_indices)
		
		# Update progress
		_update_progress(0.1 + 0.3 * float(bytes_processed) / file_size)
	
	file.close()
	
	# Check for enough data
	if obj_vertices.size() < 3:
		return {"error": "Not enough vertices in OBJ file"}
	if obj_faces.size() < 1:
		return {"error": "No faces found in OBJ file"}
	
	# Display original mesh stats
	var original_vertex_count = obj_vertices.size()
	var original_face_count = obj_faces.size()
	
	# Check if mesh exceeds the limits
	if original_vertex_count > vertex_limit:
		return {"error": "Mesh exceeds vertex limit (" + str(original_vertex_count) + " > " + str(vertex_limit) + 
				"). This may cause performance issues or crashes in Sprocket. Try a simpler model or disable limits."}
	
	if original_face_count > face_limit:
		return {"error": "Mesh exceeds face limit (" + str(original_face_count) + " > " + str(face_limit) + 
				"). This may cause performance issues or crashes in Sprocket. Try a simpler model or disable limits."}
	
	_update_progress(0.4)
	
	# Create flat list of vertices with coordinate system conversion
	var vertices = PackedFloat32Array()
	vertices.resize(obj_vertices.size() * 3)
	
	for i in range(obj_vertices.size()):
		var vertex = obj_vertices[i]
		vertices[i*3] = vertex[0]        # X remains X
		vertices[i*3+1] = vertex[1]      # Y becomes Y (forward in Blender becomes up in Sprocket)
		vertices[i*3+2] = vertex[2]      # Z becomes Z (up in Blender becomes forward in Sprocket)
		
		# Update progress
		if i % 5000 == 0:
			_update_progress(0.4 + 0.1 * float(i) / obj_vertices.size())
	
	_update_progress(0.5)
	
	# First pass / create faces
	var faces = []
	
	for face_index in range(obj_faces.size()):
		var face = obj_faces[face_index]
		
		# Keep original face structure but limit to quads
		var face_vertices = []
		var face_size = min(face.size(), 4)
		
		for i in range(face_size):
			face_vertices.append(face[i])
		
		# Set properties based on face type
		var is_triangle = face_size == 3
		var tm_value = 65793 if is_triangle else 16843009
		var t_values = [5, 5, 5] if is_triangle else [5, 5, 5, 5]
		
		# Add the face with proper properties
		faces.append({
			"v": face_vertices,
			"t": t_values,
			"tm": tm_value,
			"te": 0
		})
		
		# Update progress
		if face_index % 1000 == 0:
			_update_progress(0.5 + 0.1 * float(face_index) / obj_faces.size())
	
	_update_progress(0.6)
	
	# Second pass / create edges with optimizations
	var edges = []
	var edge_flags = []
	var edge_map = {}
	
	# Process each face for edges with edge count limit
	for face_index in range(faces.size()):
		var face = faces[face_index]
		var face_vertices = face.v
		var face_size = face_vertices.size()
		
		# Create edges for all face boundaries
		for i in range(face_size):
			var v1 = face_vertices[i]
			var v2 = face_vertices[(i + 1) % face_size]
			
			# Always ensure v1 < v2 for consistent edge keys
			if v1 > v2:
				var temp = v1
				v1 = v2
				v2 = temp
			
			var edge_key = v1 * 100000 + v2
			
			# Only add each unique edge once 
			if !edge_map.has(edge_key):
				edges.append(v1)
				edges.append(v2)
				edge_flags.append(0)
				edge_map[edge_key] = true
		
		# Update progress occasionally
		if face_index % 1000 == 0:
			_update_progress(0.6 + 0.1 * float(face_index) / faces.size())
	
	# Check if edge count exceeds the limit
	if edges.size() / 2 > edge_limit:
		return {"error": "Mesh generates too many edges (" + str(edges.size() / 2) + " > " + str(edge_limit) + 
				"). This could cause performance issues in Sprocket. Disable limits to try again."}
	
	_update_progress(0.7)
	
	# Ensure output directory exists
	if !DirAccess.dir_exists_absolute(blueprint_dir):
		var dir_access = DirAccess.open(blueprint_dir.get_base_dir())
		if dir_access == null:
			return {"error": "Cannot access blueprint directory"}
		dir_access.make_dir(blueprint_dir.get_file())
	
	# Save converted blueprint / write JSON directly to file
	var output_file_path = blueprint_dir + "/" + blueprint_name + ".blueprint"
	var output_file = FileAccess.open(output_file_path, FileAccess.WRITE)
	if output_file == null:
		return {"error": "Failed to write output file - " + str(FileAccess.get_open_error())}
	
	# Write the JSON structure directly to file
	output_file.store_line("{")
	output_file.store_line('  "v": "0.2",') 
	output_file.store_line('  "name": "' + blueprint_name + '",')
	output_file.store_line('  "smoothAngle": 0,')
	output_file.store_line('  "gridSize": 1,')
	output_file.store_line('  "format": "freeform",')
	output_file.store_line('  "mesh": {')
	output_file.store_line('    "majorVersion": 0,')
	output_file.store_line('    "minorVersion": 3,')
	
	# Vertices / small chunks to avoid memory issues
	output_file.store_string('    "vertices": [')
	var write_chunk_size = 1000
	
	for i in range(0, vertices.size(), write_chunk_size):
		var end = min(i + write_chunk_size, vertices.size())
		var vertex_chunk = ""
		
		for j in range(i, end):
			var value = vertices[j]
			var formatted_value = str(value)
			
			if j > 0:
				vertex_chunk += ", "
				
			vertex_chunk += formatted_value
		
		output_file.store_string(vertex_chunk)
		
		# Update progress for large vertex arrays
		if vertices.size() > 100000:
			_update_progress(0.7 + 0.05 * float(end) / vertices.size())
	
	output_file.store_line("\n    ],")
	
	# Edges
	output_file.store_string('    "edges": [')
	
	for i in range(0, edges.size(), write_chunk_size):
		var end = min(i + write_chunk_size, edges.size())
		var edge_chunk = ""
		
		for j in range(i, end):
			if j > 0:
				edge_chunk += ", "
				
			edge_chunk += str(edges[j])
		
		output_file.store_string(edge_chunk)
		
		# Update progress for large edge arrays
		if edges.size() > 100000:
			_update_progress(0.75 + 0.05 * float(end) / edges.size())
	
	output_file.store_line("\n    ],")
	
	# Edge flags
	output_file.store_string('    "edgeFlags": [')
	
	for i in range(0, edge_flags.size(), write_chunk_size):
		var end = min(i + write_chunk_size, edge_flags.size())
		var flag_chunk = ""
		
		for j in range(i, end):
			if j > 0:
				flag_chunk += ", "
				
			flag_chunk += str(edge_flags[j])
		
		output_file.store_string(flag_chunk)
		
		# Update progress for large edge flag arrays
		if edge_flags.size() > 100000:
			_update_progress(0.8 + 0.05 * float(end) / edge_flags.size())
	
	output_file.store_line("\n    ],")
	
	# Faces
	output_file.store_line('    "faces": [')
	
	for i in range(0, faces.size(), 100):
		var end = min(i + 100, faces.size())
		
		for j in range(i, end):
			var face = faces[j]
			var is_triangle = face.v.size() == 3
			
			output_file.store_line("      {")
			
			if is_triangle:
				output_file.store_line('        "v": [' + str(face.v[0]) + ", " + str(face.v[1]) + ", " + str(face.v[2]) + "],")
				output_file.store_line('        "t": [' + str(face.t[0]) + ", " + str(face.t[1]) + ", " + str(face.t[2]) + "],")
			else:
				output_file.store_line('        "v": [' + str(face.v[0]) + ", " + str(face.v[1]) + ", " + str(face.v[2]) + ", " + str(face.v[3]) + "],")
				output_file.store_line('        "t": [' + str(face.t[0]) + ", " + str(face.t[1]) + ", " + str(face.t[2]) + ", " + str(face.t[3]) + "],")
			
			output_file.store_line('        "tm": ' + str(face.tm) + ",")
			output_file.store_line('        "te": ' + str(face.te))
			
			if j < faces.size() - 1:
				output_file.store_line("      },")
			else:
				output_file.store_line("      }")
		
		# Update progress
		if faces.size() > 50000:
			_update_progress(0.85 + 0.1 * float(end) / faces.size())
	
	output_file.store_line("    ]")
	output_file.store_line("  },")
	
	# Rivets
	output_file.store_line('  "rivets": {')
	output_file.store_line('    "profiles": [')
	output_file.store_line('      {')
	output_file.store_line('        "model": 0,')
	output_file.store_line('        "spacing": 0.19,')
	output_file.store_line('        "diameter": 0.03,')
	output_file.store_line('        "height": 0.020,')
	output_file.store_line('        "padding": 0.04')
	output_file.store_line('      }')
	output_file.store_line('    ],')
	output_file.store_line('    "nodes": []')
	output_file.store_line('  }')
	output_file.store_line("}")
	
	output_file.close()
	
	_update_progress(1.0)
	
	return {
		"success": true,
		"name": blueprint_name,
		"output_path": output_file_path,
		"vertex_count": obj_vertices.size(),
		"face_count": obj_faces.size(),
		"edge_count": edges.size() / 2
	}

# Convert Blueprint to OBJ
func convert_BlueprintToOBJ(blueprint_path: String, output_path: String = "") -> Dictionary:
	# Prevent multiple conversions at once
	if _conversion_in_progress:
		return {"error": "A conversion is already in progress"}
	
	# Validate inputs
	if blueprint_path.is_empty():
		return {"error": "Please select an input Blueprint file"}
		
	if output_path.is_empty():
		output_path = blueprint_path.get_base_dir() + "/" + blueprint_path.get_file().get_basename() + ".obj"
	
	_conversion_in_progress = true
	
	# Start the worker thread if it's not already running
	_start_worker_thread()
	
	# Set up task for the worker thread
	_mutex.lock()
	_current_task = {
		"type": "blueprint_to_obj",
		"blueprint_path": blueprint_path,
		"output_path": output_path
	}
	_mutex.unlock()
	
	# Signal the worker thread to start processing
	_semaphore.post()
	
	return {"status": "processing"}

# Process Blueprint to OBJ in worker thread
func _process_blueprint_to_obj(blueprint_path: String, output_path: String) -> Dictionary:
	_update_progress(0.1)
	
	# Read blueprint file
	var file = FileAccess.open(blueprint_path, FileAccess.READ)
	if file == null:
		return {"error": "Failed to open blueprint file - " + str(FileAccess.get_open_error())}
	
	var json_string = file.get_as_text()
	file.close()
	
	_update_progress(0.3)
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return {"error": "Failed to parse blueprint JSON: " + json.get_error_message() + " at line " + str(json.get_error_line())}
	
	var blueprint_data = json.get_data()
	
	# Check if this is a valid blueprint
	if !blueprint_data.has("mesh") or !blueprint_data.mesh.has("vertices") or !blueprint_data.mesh.has("faces"):
		return {"error": "Invalid blueprint format - missing required fields"}
	
	_update_progress(0.4)
	
	# Extract mesh data
	var mesh = blueprint_data.mesh
	var flat_vertices = mesh.vertices
	var faces = mesh.faces
	
	# Pre-allocate arrays for better performance
	var obj_vertices = []
	obj_vertices.resize(flat_vertices.size() / 3)
	
	# Convert flat vertex array to OBJ format with coordinate conversion
	for i in range(0, flat_vertices.size(), 3):
		if i + 2 < flat_vertices.size():
			var vertex_index = i / 3
			obj_vertices[vertex_index] = {
				"x": flat_vertices[i],       # X remains X 
				"y": flat_vertices[i+1],     # Y becomes Y (up in Blender becomes forward)
				"z": flat_vertices[i+2]      # Z becomes Z (forward in Sprocket becomes up in Blender)
			}
			
			# Update progress
			if i % 10000 == 0:
				_update_progress(0.4 + float(i) / flat_vertices.size() * 0.3)
	
	_update_progress(0.7)
	
	# Build OBJ file content
	var obj_lines = []
	obj_lines.append("# Exported from Sprocket Blueprint: " + blueprint_data.name)
	obj_lines.append("# Exported on " + Time.get_datetime_string_from_system())
	obj_lines.append("")
	
	# Write vertices
	for i in range(obj_vertices.size()):
		var vertex = obj_vertices[i]
		obj_lines.append("v " + str(vertex.x) + " " + str(vertex.y) + " " + str(vertex.z))
		
		# Update progress
		if i % 10000 == 0:
			_update_progress(0.7 + float(i) / obj_vertices.size() * 0.15)
	
	obj_lines.append("\n# Faces")
	
	# Write faces
	for i in range(faces.size()):
		var face = faces[i]
		if face.v.size() == 3:
			obj_lines.append("f " + str(face.v[0] + 1) + " " + str(face.v[1] + 1) + " " + str(face.v[2] + 1))
		elif face.v.size() == 4:
			obj_lines.append("f " + str(face.v[0] + 1) + " " + str(face.v[1] + 1) + " " + str(face.v[2] + 1) + " " + str(face.v[3] + 1))
		
		# Update progress
		if i % 10000 == 0:
			_update_progress(0.85 + float(i) / faces.size() * 0.15)
	
	# Write OBJ file
	var output_file = FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		return {"error": "Failed to write OBJ file - " + str(FileAccess.get_open_error())}
	
	output_file.store_string("\n".join(obj_lines))
	output_file.close()
	
	var result = {
		"success": true,
		"obj_path": output_path,
		"vertex_count": obj_vertices.size(),
		"face_count": faces.size()
	}
	
	_update_progress(1.0)
	return result

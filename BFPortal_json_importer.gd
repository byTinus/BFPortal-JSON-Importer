@tool
extends Node3D

# Path to the JSON file
@export var json_file_path: String = "res://MP_Dumbo_race_v1.0.spatial.json"

@export_tool_button("Run") var x = go
@export_tool_button("IsInScene") var y = test

var allFiles: PackedStringArray

func test():
	print("Is inside tree: ", is_inside_tree())

func go():
	print("start reading the json")
	allFiles = get_all_files("res://objects/")
	load_objects_from_json(json_file_path)


func load_objects_from_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON file: " + path)
		return

	var file_contents := file.get_as_text()
	file.close()

	var data = JSON.parse_string(file_contents)
	if data == null:
		push_error("Error parsing JSON from file: " + path)
		return

	# Expecting either a top-level array or a top-level object with entries
	var objects := []
	if data is Array:
		objects = data[0]
	elif data is Dictionary:
		objects = data["Portal_Dynamic"]  # Handle if it's keyed by something
	else:
		push_error("Unexpected JSON structure in file: " + path)
		return
	print("Done parsing JSON. Found objects: ", objects.size())
	for obj_data in objects:
		if obj_data is Dictionary:
			create_object_from_data(obj_data)

func get_all_files(path: String, depth: int = 0) -> PackedStringArray: 
	#print("recursion depth: ", depth, " - ",path)
	var totalFiles: PackedStringArray
	var files: PackedStringArray = ResourceLoader.list_directory(path)
	for file in files:
		if file.contains('.tscn'):
			totalFiles.append(path + file)
		elif file.ends_with('/'):
			totalFiles.append_array(get_all_files(path + file, depth + 1))
	print(totalFiles.size(), " files found in ", path)
	return totalFiles

func get_path_to_prefab(prefab_type: String) -> String: 
	for filePath in allFiles:
		if filePath.ends_with(prefab_type + ".tscn"):
			return filePath
	return "";

func create_object_from_data(obj_data: Dictionary):
	if not obj_data.has("type"):
		push_warning("Skipping object without 'type' field.")
		return

	var prefab_type: String = obj_data["type"]
	print("Searching for prefab ", prefab_type)
	var scene_path = get_path_to_prefab(prefab_type)
	print("Found ", scene_path)
	if scene_path == "": return
	var scene_res := load(scene_path)
	if scene_res == null:
		push_error("Prefab not found for type: " + prefab_type + " (" + scene_path + ")")
		return

	var instance: Node3D = scene_res.instantiate()
	print("prefab found. Adding to scene...")
	addChild.call_deferred(instance, obj_data)
	
func addChild(instance: Node3D, obj_data: Dictionary):
	self.add_child(instance)
	instance.owner = get_tree().edited_scene_root

	# Set name if provided
	if obj_data.has("name"):
		instance.name = str(obj_data["name"])

	# Set position (3D)
	if obj_data.has("position"):
		var pos = obj_data["position"]
		if pos.has("x") and pos.has("y") and pos.has("z"):
			instance.position = Vector3(pos["x"], pos["y"], pos["z"])
	
	# Set rotation annd scale
	if obj_data.has("right") and obj_data.has("up") and obj_data.has("front"):
		var right = Vector3(obj_data["right"]["x"], obj_data["right"]["y"], obj_data["right"]["z"])
		var up = Vector3(obj_data["up"]["x"], obj_data["up"]["y"], obj_data["up"]["z"])
		var front = Vector3(obj_data["front"]["x"], obj_data["front"]["y"], obj_data["front"]["z"])
		var scale: Vector3 = Vector3(right.length(), up.length(), front.length())
		var rotation = Basis(right, up, front).get_euler()
		instance.rotation = rotation
		instance.scale = scale

	# Apply any additional custom properties that exist in the object
	for key in obj_data.keys():
		if key in ["type", "position", "up", "front", "right", "name", "id"]:
			continue  # skip transform and metadata keys

		# If the property exists on the instance, set it
		if key in instance:
			instance.set(key, obj_data[key])
		elif instance.has_method("set_" + key):
			instance.call("set_" + key, obj_data[key])

@tool
extends EditorImportPlugin

var sprite: String

func _get_preset_count() -> int:
	return 0

func _get_import_options(path: String, preset_index: int) -> Array:
	return []

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _get_importer_name() -> String:
	return "MoxieGaming.SpriteFrameImporter"

func _get_visible_name() -> String:
	return "SpriteFrames"
	
func _get_recognized_extensions() -> PackedStringArray:
	return ["mg_json"]

func _get_save_extension() -> String:
	return "tres"

func _get_resource_type() -> String:
	return "SpriteFrames"

func _get_dependencies(source_file: String, add_types: bool) -> PackedStringArray:
	var deps := PackedStringArray()

	var dir = source_file.get_base_dir()

	var files = DirAccess.get_files_at(dir)

	for file in files:
		if file.get_extension() == "png":
			deps.append(dir.path_join(file))

	return deps
	
func _import(
	source_file: String, 
	save_path: String,
	options: Dictionary, 
	r_platform_variants: Array[String], 
	r_gen_files: Array[String]
) -> Error:
	var folder = source_file.get_base_dir()
	sprite = folder.get_basename().get_file()
	var file = FileAccess.open(source_file, FileAccess.READ)
	
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		push_error("Failed to parse JSON")
		
	var tags = data["meta"]["frameTags"]
	var layers = data["meta"]["layers"]
	
	for layer in layers:
		if "opacity" not in layer or layer["opacity"] == 0.0:
			continue
			
		if "group" in layer:
			create_spriteframes(folder, layer["group"], layer["name"], tags, save_path)
		else:
			create_spriteframes(folder, "", layer["name"], tags, save_path)
	
	return OK

func create_spriteframes(folder: String, group: String, layer: String, tags: Array, save_path: String) -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	
	var base_path = folder + "/"
	
	if group != "":
		base_path = base_path + group + "/" + layer
	else:
		base_path = base_path + layer
	
	for tag in tags:
		# get animation name
		var anim_name = tag["name"]
		sprite_frames.add_animation(anim_name)
		
		# get frames for animation
		var json_path = base_path + "/" + anim_name + "-meta.json"
		var frames = _get_frames(json_path)

		# load animation texture
		var png_path = base_path.path_join(anim_name + ".png")
		var texture = load(png_path)

		var frame_count = frames.size()
		var i = 0

		while i < frame_count:
			var frame_data = frames[_get_frame_name(layer, anim_name, i)]

			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				int(frame_data["frame"]["x"]),
				int(frame_data["frame"]["y"]),
				int(frame_data["frame"]["w"]),
				int(frame_data["frame"]["h"])
			)
			
			var duration = float(frame_data["duration"])
			
			while i + 1 < frame_count:
				var next_data = frames[_get_frame_name(layer, anim_name, i + 1)]
				if _is_same_frame(frame_data["frame"], next_data["frame"]):
					duration = duration + float(next_data["duration"])
					i = i + 1
				else:
					break

			var duration_seconds = duration / 100.0

			sprite_frames.add_frame(
				anim_name,
				atlas,
				duration_seconds
			)

			i = i + 1

	var save_file = ""
	if group != "":
		save_file = "%s/animations/%s/%s.%s" % [folder, group, layer, _get_save_extension()]
	else:
		save_file = "%s/animations/%s.%s" % [folder, layer, _get_save_extension()]
	
	_save_spriteframes(sprite_frames, save_file)

func _get_frames(json_path: String) -> Dictionary:
	if !FileAccess.file_exists(json_path):
		push_error("Cannot find file: " + json_path)
		
	var file = FileAccess.open(json_path, FileAccess.READ)

	var data = JSON.parse_string(file.get_as_text())
	
	if data == null:
		push_error("Failed to parse JSON")
		return {}
		
	return data["frames"]

func _get_frame_name(layer: String, anim_name: String, index: int) -> String:
	return sprite + " (" + layer + ") #" + anim_name + " " + str(index) + ".aseprite"

func _is_same_frame(this_frame: Dictionary, next_frame: Dictionary) -> bool:
	if int(this_frame["x"]) != int(next_frame["x"]):
		return false
	if int(this_frame["y"]) != int(next_frame["y"]):
		return false
	return true

func _save_spriteframes(sprite_frames: SpriteFrames, path: String) -> void:
	# check to make sure directory exists
	var dir_path = path.get_base_dir()
	
	var error = DirAccess.make_dir_recursive_absolute(dir_path)
	
	if error == OK:
		var save_result = ResourceSaver.save(sprite_frames, path)
		if save_result == OK:
			print("Generated SpriteFrame resource: " + path)
		else:
			push_error("Failed to save resource. Error code: " + save_result)
	else:
		push_error("Failed to create directory for resource. Error code: " + error)

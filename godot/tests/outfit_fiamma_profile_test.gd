extends SceneTree

const Spawn = preload("res://src/character/athlete_spawn.gd")
const Catalogue = preload("res://src/character/outfit_catalogue.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Catalogue.entries().size() == 26, "Catalogue count unchanged")
	var a = Spawn.make(&"fiamma", &"base")
	var b = Spawn.make(&"fiamma", &"legend")
	root.add_child(a)
	root.add_child(b)
	var original = a.get_mesh_instance().get_surface_override_material(0)
	var original_texture = original.albedo_texture
	var bones: int = a.get_skeleton().get_bone_count()
	var nodes: int = a.get_child_count()
	var other_material = b.get_catalogue_surface()
	var other_target = other_material.get_shader_parameter("target_torso_a")
	check(Catalogue.apply(a, &"fiamma", &"circuit"), "Circuit applies")
	var material = a.get_catalogue_surface()
	check(material != other_material, "Rig material isolation")
	check(material.get_shader_parameter("region_mask") == other_material.get_shader_parameter("region_mask"), "Immutable mask shared")
	check(material.get_shader_parameter("normal_tex") == a.get_base_material().normal_texture, "Normal map retained")
	check(material.get_shader_parameter("roughness_tex") == a.get_base_material().roughness_texture, "Roughness map retained")
	for cycle in 8:
		for id in [&"circuit", &"legend", &"signature"]:
			check(Catalogue.apply(a, &"fiamma", id), "Apply " + String(id))
			check(a.get_catalogue_surface() == material, "Switch reuses same material")
			check(b.get_catalogue_surface().get_shader_parameter("target_torso_a") == other_target, "Other rig unchanged")
		check(Catalogue.apply(a, &"fiamma", &"base"), "Restore base")
		check(a.get_mesh_instance().get_surface_override_material(0) == original, "Exact original material restored")
		check(original.albedo_texture == original_texture, "Original texture unchanged")
	check(a.get_skeleton().get_bone_count() == bones and a.get_child_count() == nodes, "No extra nodes or skeleton changes")
	check(Catalogue.apply(a, &"fiamma", &"mythic"), "Unauthored known outfit preserves safe fallback")
	check(a.is_base_surface(), "Mythic does not retain last supported appearance")
	check(not Catalogue.apply(a, &"fiamma", &"invalid"), "Unknown outfit rejected")
	check(a.is_base_surface(), "Invalid selection leaves material intact")
	var c = Spawn.make(&"colosso", &"signature")
	check(c != null and c.get_catalogue_surface() == null, "Other dedicated athlete unchanged")
	c.free()
	a.free()
	b.free()
	print("OUTFIT_FIAMMA_PROFILE_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

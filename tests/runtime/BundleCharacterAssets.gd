extends SceneTree

func Digest(Bytes: PackedByteArray) -> String:
    var Hash := HashingContext.new()
    Hash.start(HashingContext.HASH_SHA256)
    Hash.update(Bytes)
    return Hash.finish().hex_encode()

func Describe(Mesh: ArrayMesh) -> Dictionary:
    var Surfaces := []
    for Index in Mesh.get_surface_count():
        var Material := Mesh.surface_get_material(Index) as StandardMaterial3D
        assert(Material != null and Material.albedo_texture != null)
        var Image := Material.albedo_texture.get_image()
        assert(Image != null and not Image.is_empty())
        Surfaces.append({"Arrays": Digest(var_to_bytes(Mesh.surface_get_arrays(Index))), "Texture": Digest(Image.get_data()), "Width": Image.get_width(), "Height": Image.get_height()})
    return {"Surfaces": Surfaces, "Bounds": str(Mesh.get_aabb())}

func _initialize() -> void:
    var Directory := "res://GodotLuau/assets/avatars/r6/"
    var Records := {}
    for Name in DirAccess.get_files_at(Directory):
        if not Name.ends_with(".obj"): continue
        var Mesh := load(Directory + Name) as ArrayMesh
        assert(Mesh != null)
        var Target := "res://.godot/imported/Sanitizer-" + Name + ".tres"
        var Before := Describe(Mesh)
        # Imported CompressedTexture2D stores an external file path. Embed the
        # decoded original image in an ImageTexture so the exported mesh has
        # no template-loader dependency on a generic Texture2D type hint.
        for Index in Mesh.get_surface_count():
            var Material := Mesh.surface_get_material(Index) as StandardMaterial3D
            Material.albedo_texture = ImageTexture.create_from_image(Material.albedo_texture.get_image())
        assert(Describe(Mesh) == Before)
        assert(ResourceSaver.save(Mesh, Target, ResourceSaver.FLAG_BUNDLE_RESOURCES) == OK)
        var After := Describe(ResourceLoader.load(Target, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE))
        assert(Before == After)
        Records[Directory + Name] = {"Path": Target, "Identity": Before}
    assert(Records.size() == 6)
    var File := FileAccess.open("res://bundled-assets.json", FileAccess.WRITE)
    File.store_string(JSON.stringify(Records))
    File.close()
    print("[Runtime:CharacterAssets] PASS six meshes; geometry, bounds and texture bytes preserved")
    quit()

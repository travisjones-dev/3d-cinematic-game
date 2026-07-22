extends GutTest
## Zone 02 shore (Pass D3): the scene loads. The cinematic itself is human-tested.

const SHORE: PackedScene = preload("res://scenes/zones/zone_02_shore.tscn")

func test_shore_scene_loads() -> void:
	assert_not_null(SHORE, "shore scene parses and loads")

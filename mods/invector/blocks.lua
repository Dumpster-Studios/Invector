-- Invector, License MIT, Author Jordach

local mega_pad = {
	type = "fixed",
	fixed = {
		{-1.5, -0.5, -1.5, 1.5, 0.5, 1.5}
	}
}

minetest.register_node("invector:smoke_node", {
	description = "don't use me",
	tiles = {"invector_smoke.png"},
	drawtype = "glasslike",
	groups = {not_in_builder_inv=1},
})

minetest.register_node("invector:boost_1_node", {
	description = "don't use me",
	tiles = {"invector_boost_small.png"},
	drawtype = "glasslike",
	groups = {not_in_builder_inv=1},
})

minetest.register_node("invector:boost_2_node", {
	description = "don't use me",
	tiles = {"invector_boost_medium.png"},
	drawtype = "glasslike",
	groups = {not_in_builder_inv=1},
})

minetest.register_node("invector:boost_3_node", {
	description = "don't use me",
	tiles = {"invector_boost_big.png"},
	drawtype = "glasslike",
	groups = {not_in_builder_inv=1},
})

minetest.register_node("invector:boost_pad", {
	description = "Boost Pad",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		{
			name = "boost_pad_holo_anim.png",
			backface_culling = false,
			animation = {
				aspect_w = 32,
				aspect_h = 32,
				length = 1.5,
				type = "vertical_frames"
			},
		}
	},
	paramtype2 = "facedir",
	light_source = 14,
	use_texture_alpha = "blend",
	drawtype = "mesh",
	mesh = "invector_pad.b3d",
	groups = {invector = 1, booster = 1, track = 1},
	on_place = solarsail.util.functions.sensible_facedir_simple
})

minetest.register_node("invector:boost_pad_mega", {
	description = "Boost Pad Mega [3x3]",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		{
			name = "boost_pad_holo_anim.png",
			backface_culling = false,
			animation = {
				aspect_w = 32,
				aspect_h = 32,
				length = 1.5,
				type = "vertical_frames"
			},
		}
	},
	paramtype2 = "facedir",
	light_source = 14,
	use_texture_alpha = "blend",
	drawtype = "mesh",
	mesh = "invector_pad_mega.b3d",
	selection_box = mega_pad,
	collision_box = mega_pad,
	groups = {invector = 1, booster = 2, track = 1},
	on_place = solarsail.util.functions.sensible_facedir_simple
})

local function reset_item_pad_small(pos, elapsed)
	local timer = minetest.get_node_timer(pos)
	timer:stop()
	minetest.swap_node(pos, {name="invector:item_pad_online"})
end

minetest.register_node("invector:item_pad_offline", {
	description = "Item Pad Offline",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		"transparent.png"
	},
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	drawtype = "mesh",
	mesh = "invector_pad.b3d",
	groups = {invector = 1, not_in_builder_inv=1, track = 1},
	on_place = solarsail.util.functions.sensible_facedir_simple,
	on_timer = reset_item_pad_small
})

minetest.register_node("invector:item_pad_online", {
	description = "Item Pad Online",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		{
			name = "item_pad_holo_anim.png",
			backface_culling = false,
			animation = {
				aspect_w = 32,
				aspect_h = 32,
				length = 0.6,
				type = "vertical_frames"
			},
		}
	},
	paramtype2 = "facedir",
	light_source = 14,
	use_texture_alpha = "blend",
	drawtype = "mesh",
	mesh = "invector_pad.b3d",
	groups = {invector = 1, item = 1},
	_swap_to = "invector:item_pad_offline",
	on_place = solarsail.util.functions.sensible_facedir_simple
})

local function reset_item_pad_mega(pos, elapsed)
	local timer = minetest.get_node_timer(pos)
	timer:stop()
	minetest.swap_node(pos, {name="invector:item_pad_mega_online"})
end

minetest.register_node("invector:item_pad_mega_offline", {
	description = "Item Pad Mega Offline [3x3]",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		"transparent.png"
	},
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	drawtype = "mesh",
	mesh = "invector_pad_mega.b3d",
	selection_box = mega_pad,
	collision_box = mega_pad,
	groups = {invector = 1, not_in_builder_inv=1},
	on_place = solarsail.util.functions.sensible_facedir_simple,
	on_timer = reset_item_pad_mega
})

minetest.register_node("invector:item_pad_mega_online", {
	description = "Item Pad Mega [3x3]",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		{
			name = "item_pad_holo_anim.png",
			backface_culling = false,
			animation = {
				aspect_w = 32,
				aspect_h = 32,
				length = 0.6,
				type = "vertical_frames"
			},
		}
	},
	paramtype2 = "facedir",
	light_source = 14,
	use_texture_alpha = "blend",
	drawtype = "mesh",
	mesh = "invector_pad_mega.b3d",
	selection_box = mega_pad,
	collision_box = mega_pad,
	groups = {invector = 1, item = 1},
	_swap_to = "invector:item_pad_mega_offline",
	on_place = solarsail.util.functions.sensible_facedir_simple
})

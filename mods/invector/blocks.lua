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

local inv_wall = {
	description = "invisible wall",
	paramtype = "light",
	groups = {invector = 1}
}
if minetest.settings:get_bool("creative_mode") then
	inv_wall.drawtype = "glasslike"
	inv_wall.tiles = {"core_azan_leaves.png"}
else
	inv_wall.drawtype = "airlike"
end
minetest.register_node("invector:invisible_wall", inv_wall)

minetest.register_node("invector:starting_grid_marker", {
	description = "Decorative starting grid, useful for people wanting layout",
	tiles = {"invector_grid_start.png"},
	groups = {invector=1, track=1},
	drawtype = "mesh",
	mesh = "starting_grid_markers.b3d",
	paramtype = "light",
	walkable = false,

	after_place_node = function(pos)
		local x_offset = 3
		local z_offset = 4
		for x=1, 2 do
			for z=0,5 do
				if x==1 then
					if z==0 then
					else
						local place_pos = vector.new(pos.x, pos.y, pos.z + (z_offset * z))
						minetest.set_node(place_pos, {name="invector:starting_grid_marker"})
					end
				else
					if z==0 then
						local place_pos = vector.new(pos.x+x_offset, pos.y, pos.z + 1)
						minetest.set_node(place_pos, {name="invector:starting_grid_marker"})
					else
						local place_pos = vector.new(pos.x+x_offset, pos.y, (pos.z + 1) + (z_offset * z))
						minetest.set_node(place_pos, {name="invector:starting_grid_marker"})
					end
				end
			end
		end
	end,
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
	groups = {invector = 1, booster = 0.5, track = 1},
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
	groups = {invector = 1, booster = 1, track = 1},
	on_place = solarsail.util.functions.sensible_facedir_simple
})

minetest.register_node("invector:jump_pad", {
	description = "Jump Pad",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		{
			name = "jump_pad_holo_anim.png",
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
	groups = {invector = 1, jump = 7, track = 1},
	on_place = solarsail.util.functions.sensible_facedir_simple
})

minetest.register_node("invector:jump_pad_mega", {
	description = "Jump Pad",
	tiles = {
		"invector_pad_top.png",
		"invector_pad_bottom.png",
		"invector_pad_side.png",
		{
			name = "jump_pad_holo_anim.png",
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
	groups = {invector = 1, jump = 14, track = 1},
	on_place = solarsail.util.functions.sensible_facedir_simple
})

local function reset_item_pad_small(pos, elapsed)
	local timer = minetest.get_node_timer(pos)
	timer:stop()
	minetest.swap_node(pos, {name="invector:item_pad_online"})
	minetest.sound_play("item_pad_online", {pos=pos, max_hear_distance=16}, true)
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
	groups = {invector = 1, track = 1, item = 1},
	_swap_to = "invector:item_pad_offline",
	on_place = solarsail.util.functions.sensible_facedir_simple
})

local function reset_item_pad_mega(pos, elapsed)
	local timer = minetest.get_node_timer(pos)
	timer:stop()
	minetest.swap_node(pos, {name="invector:item_pad_mega_online"})
	minetest.sound_play("item_pad_online", {pos=pos, max_hear_distance=16}, true)
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
	groups = {invector = 1, track = 1, not_in_builder_inv=1},
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
	groups = {invector = 1, track = 1, item = 1},
	_swap_to = "invector:item_pad_mega_offline",
	on_place = solarsail.util.functions.sensible_facedir_simple
})

-- Enable or disable visibility of hidden waypoint nodes on the track

local node_params = {
	walkable = false,
	pointable = true,
	paramtype = "light",
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	},
	groups = {invector = 1, track = 1}
}

-- Waypoint nodes
if minetest.settings:get_bool("creative_mode") then
	node_params.tiles = {"invector_track_waypoint.png"}
	node_params.drawtype = "glasslike"
else
	node_params.drawtype = "airlike"
end

for i=1, 100 do
	local nparams = table.copy(node_params)
	nparams.after_place_node = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "AI/Position Waypoint N: "..i)
	end

	nparams.on_destruct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "")
	end

	nparams.groups.waypoint = i
	minetest.register_node("invector:waypoint_"..i, nparams)
	invector.ai.known_node_targets[i] = "invector:waypoint_"..i
end

-- Start/finish line/sector marker
local nparams = table.copy(node_params)
if minetest.settings:get_bool("creative_mode") then
	nparams.tiles = {"invector_track_sector.png"}
	nparams.drawtype = "glasslike"

	nparams.after_place_node = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Sector/Start Line Waypoint")
	end
	
	nparams.on_destruct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "")
	end
else
	nparams.drawtype = "airlike"
end

nparams.groups.sector = 1
nparams.groups.waypoint = 101
minetest.register_node("invector:sector_marker", nparams)
invector.ai.known_node_targets[101] = "invector:sector_marker"

-- Utilities

minetest.register_craftitem("invector:kart_stick", {
	inventory_image = "invector_drift_big.png",
	description = "Spawns unusable karts where you point it.",
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.under
		pos.y = pos.y+0.5
		local ent = minetest.add_entity(pos, "invector:kart")
		local entlua = ent:get_luaentity()
	end,
})

minetest.register_craftitem("invector:ai_kart_stick", {
	inventory_image = "invector_drift_small.png",
	description = "Spawns AI karts where you point it.",
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.under
		pos.y = pos.y+0.5
		local racer_id = 2
		local ent = minetest.add_entity(pos, "invector:kart")
		ent:set_yaw(6.284)
		ent:set_acceleration(vector.new(0, -9.71, 0))
		invector.racers[racer_id].kart_ref = ent
		local entlua = ent:get_luaentity()
		entlua._is_ai = invector.racers[racer_id].is_ai
		entlua._position = invector.racers[racer_id].position
		entlua._racer_id = racer_id
		entlua._ai_reaction_timing.min = invector.racers[racer_id].ai_difficulty.tmin
		entlua._ai_reaction_timing.max = invector.racers[racer_id].ai_difficulty.tmax
		entlua._ai_button_press_success = invector.racers[racer_id].ai_difficulty.frate
	end,
})

minetest.register_craftitem("invector:laser_pointer", {
	inventory_image = "invector_drift_med.png",
	description = "Prints to console the location of the node that was clicked.",
	on_place = function(itemstack, placer, pointed_thing)
		print(dump(pointed_thing.under))
	end,
})

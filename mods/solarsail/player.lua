-- SolarSail Engine Player Handling:
-- Author: Jordach
-- License: Reserved

solarsail.player.model = {}

--[[ solarsail.player.model.entity_name[player_name]
	Read only, set only by authoritative content.
	
Example values:
	solarsail.player.model.entity_name[player_name] = "solarplains:starsuit"
	solarsail.player.model.entity_name[player_name] = "anathema:model"
]]
solarsail.player.model.entity_name = {}

solarsail.player.model.entity_ref = {}
--[[ solarsail.player.set_model(player_ref, model_name, anim, framerate, 
								eye_offset, eye_offset_3r, attach_bone,
								attach_relative, attach_rotation)

model_name = "model:name" 
				(See minetest.register_entity() for more information.)

anim:
	anim.x = 123, The start position of the animation loop
	anim.y = 456, The end position of the animation loop
	Setting anim = nil will result in anim.x, anim.y = 0

framerate = 60, Sets the framerate of the animation, 
				can be configured upto about 300fps.
				framerate = nil will default to 60.

eye_offset and eye_offset_3r:
	x = 1, Position on the X axis where the "player's camera" will sit
	y = 2, Position on the Y axis where the "player's camera" will sit
	z = 3, Position on the Z axis where the "player's camera" will sit

	Setting either table to nil will default to x, y, z = 0.

attach_bone = "bonename", Make sure the bone exists in the exported model. 
							(Can include . : , etc)
	Setting attach_bone to nil will default to ""

attach_relative:
	x = 1, Position on the X axis where the 
			"Minetest Player Entity" is attached
	y = 2, Position on the Y axis where the 
			"Minetest Player Entity" is attached
	z = 3, Position on the Z axis where the 
			"Minetest Player Entity" is attached
	Setting attach_relative = nil will default to x, y, z = 0.

attach_rotation:
	x = 1, Rotation on the X axis in degrees
			(of either the entity or player, documentation unclear)
	y = 2, Rotation on the Y axis in degrees
			(of either the entity or player, documentation unclear)
	z = 3, Rotation on the Z axis in degrees
			(of either the entity or player, documentation unclear)
	Setting attach_rotation = nil will default to x, y, z = 0.
]]

function solarsail.player.set_model(player_ref, model_name, anim, framerate,
			eye_offset, eye_offset_3rv, attach_bone, relative_pos, relative_rotation)
	-- Prevent impossible situations where the model may not exist.
	if model_name == nil or type(model_name) ~= "string" then
		error("model_name must be a string.")
	end

	-- Construct a player entity at the player's position:
	local pos = player_ref:get_pos()
	solarsail.player.model.entity_ref[player_ref:get_player_name()] = minetest.add_entity(pos, model_name)

	-- Get LuaObject:
	local entity_lua = solarsail.player.model.entity_ref[player_ref:get_player_name()]:get_luaentity()

	-- Add the player_ref to the model, as it may be needed to ensure they player is still attached.
	-- Set this to nil to detach the "player camera" from the "player model"
	entity_lua.attached_player = player_ref

	-- Set the idle animation:
	solarsail.player.model.entity_ref[player_ref:get_player_name()]:set_animation(anim, framerate, 0)
	-- Remove all normal MT HUD from the player:
	player_ref:hud_set_flags({
		crosshair = false,
		hotbar = false,
		healthbar = false,
		wielditem = false,
		breathbar = false
	})

	-- Set the eye offset for the "player camera"
	player_ref:set_eye_offset(eye_offset, eye_offset_3rv)
	-- Attach the "Minetest player" to the "solarsail player"
	player_ref:set_attach(entity_lua.object, attach_bone, relative_pos, relative_rotation)
end

-- Wrapper for Lua_SAO:set_properties()
function solarsail.player.set_properties(player_name, changes)
	solarsail.player.model.entity_ref[player_name]:set_properties(changes)
end

-- Wrapper for Lua_SAO:get_properties()
function solarsail.player.get_properties(player_name)
	return solarsail.player.model.entity_ref[player_name]:get_properties()
end

--store PI for quicker use:
local pi = math.pi

-- Supply a boolean value to go backwards, otherwise, forwards
function solarsail.util.functions.yaw_to_vec(rads, mult, backwards)
	local z = math.cos(rads) * mult
	local x = (math.sin(rads) * -1) * mult
	
	if backwards then
		return -x, -z
	else
		return x, z
	end
end

-- Get left or right direction, supply a boolean to go left.
function solarsail.util.functions.yaw_to_vec_side(rads, mult, left)
	local nrads = rads + pi/2
	if left then
		nrads = rads - pi/2
	end
	local x = (math.cos(nrads) * -1) * mult
	local z = math.sin(nrads) * mult
	return z, x
end

-- Convert our x, z vectors to a nice radian:
function solarsail.util.functions.vec_to_rad(x, z)
	return math.atan2(z, x)
end

-- Quickly convert degrees to radians:
function solarsail.util.functions.deg_to_rad(deg)
	return deg * (pi/180)
end
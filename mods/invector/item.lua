-- Invector, License MIT, Author Jordach
local tick_speed = 0.03

-- Global table.
invector.items = {}
invector.items.pad_timer = 4.25

-- TNT ID 1

local tnt_ent = {
	visual = "mesh",
	mesh = "item_tnt.b3d",
	makes_footstep_sound = false,
	textures = {"item_tnt.png"},
	visual_size = {x=5, y=5},
	collision_box = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	physical = true,
	collide_with_objects = true,
	pointable = false,

	_timer = 0
}

function tnt_ent:explode()
	local pos = self.object:get_pos()
	local radius = minetest.get_objects_inside_radius(pos, 5)
	for key, entity in pairs(radius) do
		local entity_lua = entity:get_luaentity()

		if entity_lua == nil then
		elseif entity_lua._is_kart == nil then
		elseif entity_lua._is_kart then
			if entity_lua._immune_timer > 0 then -- Ignore karts with Nanite Regen
			elseif entity_lua._stun_timer > 0 then -- Ignore karts that are already stunned
			elseif not entity_lua._shields then -- Remove shields from karts
				entity_lua._stun_timer = 2
				entity_lua:clear_boost()
			else
				entity_lua._shields = false
				local textures = entity:get_properties().textures
				textures[3] = "transparent.png"
				entity:set_properties({textures = textures})
			end
		end
	end

	minetest.add_particlespawner({
		amount = 200,
		vertical = false,
		collisiondetection = false,
		minexptime = 0.5,
		maxexptime = 0.95,
		minpos = vector.new(pos.x-0.5, pos.y+0, pos.z-0.5),
		maxpos = vector.new(pos.x+0.5, pos.y+0.5, pos.z+0.5),
		minvel = vector.new(-4, 0, -4),
		maxvel = vector.new( 4, 4,  4),
		time = 0.05,
		glow = 0,
		node = {name = "invector:smoke_node"},
		minsize = 2,
		maxsize = 3
	})
	self.object:remove()
	return
end

function tnt_ent:on_step(dtime, moveresult)
	self._timer = self._timer + dtime
	local tick_scaling = solarsail.util.functions.remap(dtime, tick_speed/4, tick_speed*4, 0.25, 4)
	local ratio_tick = solarsail.util.functions.remap(tick_scaling, 0.25, 4, 0, 1)
	local vel = self.object:get_velocity()
	-- Handle air and ground friction
	if moveresult.touching_ground then
		vel.x = (vel.x * 0.25) * tick_scaling
		vel.z = (vel.z * 0.25) * tick_scaling
	end
	-- Give it some bounce
	if moveresult.collisions[1] == nil then
	elseif moveresult.collisions[1].axis == "x" then
		vel.x = -vel.x * 0.98
	elseif moveresult.collisions[1].axis == "z" then
		vel.z = -vel.z * 0.98
	end
	self.object:set_velocity(vel)

	local texture = self.object:get_properties().textures
	if math.floor(self._timer) % 2 == 0 then
		if texture[1] == "item_tnt.png^[brighten" then
			self.object:set_properties({textures="item_tnt.png"})
		end
	else
		if texture[1] == "item_tnt.png" then
			self.object:set_properties({textures="item_tnt.png^[brighten"})
		end
	end

	if self._timer > 5 then
		self:explode()
	end
end

minetest.register_entity("invector:item_tnt", tnt_ent)

-- Prox TNT ID 2
local prox_ent = {
	visual = "mesh",
	mesh = "item_tnt.b3d",
	makes_footstep_sound = false,
	textures = {"item_prox.png"},
	visual_size = {x=5, y=5},
	collision_box = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	physical = true,
	collide_with_objects = true,
	pointable = false,

	_timer = 0
}

function prox_ent:explode()
	if self.object == nil then return end
	local pos = self.object:get_pos()
	if pos == nil then return end
	local radius = minetest.get_objects_inside_radius(pos, 5)

	for key, entity in pairs(radius) do
		local entity_lua = entity:get_luaentity()

		if entity_lua == nil then
		elseif entity_lua._is_kart == nil then
		elseif entity_lua._is_kart then
			if entity_lua._shields then -- Remove shields from karts
				entity_lua._shields = false
				local textures = entity:get_properties().textures
				textures[3] = "transparent.png"
				entity:set_properties({textures = textures})
			else
				entity_lua._stun_timer = 2
				entity_lua:clear_boost()
			end
		end
	end

	minetest.add_particlespawner({
		amount = 200,
		vertical = false,
		collisiondetection = false,
		minexptime = 0.25,
		maxexptime = 0.45,
		minpos = vector.new(pos.x-0.5, pos.y+0, pos.z-0.5),
		maxpos = vector.new(pos.x+0.5, pos.y+0.5, pos.z+0.5),
		minvel = vector.new(-2, 0, -2),
		maxvel = vector.new(2, 2, 2),
		time = 0.05,
		glow = 0,
		node = {name = "invector:smoke_node"},
		minsize = 2,
		maxsize = 3
	})
	self.object:remove()
	return
end

function prox_ent:on_step(dtime, moveresult)
	self._timer = self._timer + dtime
	local tick_scaling = solarsail.util.functions.remap(dtime, tick_speed/4, tick_speed*4, 0.25, 4)
	local ratio_tick = solarsail.util.functions.remap(tick_scaling, 0.25, 4, 0, 1)
	local vel = self.object:get_velocity()
	local pos = self.object:get_pos()
	-- Handle air and ground friction
	if moveresult.touching_ground then
		vel.x = (vel.x * 0.25) * tick_scaling
		vel.z = (vel.z * 0.25) * tick_scaling
	end
	-- Give it some bounce
	if moveresult.collisions[1] == nil then
	elseif moveresult.collisions[1].axis == "x" then
		vel.x = -vel.x * 0.98
	elseif moveresult.collisions[1].axis == "z" then
		vel.z = -vel.z * 0.98
	end
	self.object:set_velocity(vel)
	
	-- Scan for karts
	if self._timer > 1.75 then
		local ents = minetest.get_objects_inside_radius(pos, 3)

		for key, entity in pairs(ents) do
			local entity_lua = entity:get_luaentity()
	
			if entity_lua == nil then
			elseif entity_lua._is_kart == nil then
			elseif entity_lua._is_kart then
				self:explode()
			end
		end
	end
	if self._timer > 15 then
		self:explode()
	end
end

minetest.register_entity("invector:item_ptnt", prox_ent)

-- Rocket ID 3

invector.items.rocket_particle_trail = {
	amount = 25,
	vertical = false,
	collisiondetection = false,
	minexptime = 0.25,
	maxexptime = 0.5,
	node = {name="invector:smoke_node"},
	minpos = vector.new(0,0,0),
	maxpos = vector.new(0,0,0),
	minvel = vector.new(0,0.25,0),
	maxvel = vector.new(0,1,0),
}

local rocket_ent = {
	visual = "mesh",
	mesh = "item_rocket.b3d",
	makes_footstep_sound = false,
	textures = {"item_rocket_body.png", "item_rocket_detail.png"},
	collision_box = {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25},
	physical = true,
	collide_with_objects = true,
	pointable = false,
	visual_size = {x=5.5, y=5.5},
	_timer = 0
}

function rocket_ent:explode()
	local pos = self.object:get_pos()
	local radius = minetest.get_objects_inside_radius(pos, 2)
	for key, entity in pairs(radius) do
		local entity_lua = entity:get_luaentity()

		if entity_lua == nil then
		elseif entity_lua._is_kart == nil then
		elseif entity_lua._is_kart then
			if entity_lua._immune_timer > 0 then -- Ignore karts with Nanite Regen
			elseif entity_lua._stun_timer > 0 then -- Ignore karts that are already stunned
			elseif not entity_lua._shields then -- Remove shields from karts
				entity_lua._stun_timer = 2
				entity_lua:clear_boost()
			else
				entity_lua._shields = false
				local textures = entity:get_properties().textures
				textures[3] = "transparent.png"
				entity:set_properties({textures = textures})
			end
		end
	end

	minetest.add_particlespawner({
		amount = 200,
		vertical = false,
		collisiondetection = false,
		minexptime = 0.5,
		maxexptime = 0.95,
		minpos = vector.new(pos.x-0.5, pos.y+0, pos.z-0.5),
		maxpos = vector.new(pos.x+0.5, pos.y+0.5, pos.z+0.5),
		minvel = vector.new(-4, 0, -4),
		maxvel = vector.new( 4, 4,  4),
		time = 0.05,
		glow = 0,
		node = {name = "invector:smoke_node"},
		minsize = 2,
		maxsize = 3
	})
	self.object:remove()
end

function rocket_ent:on_step(dtime, moveresult)
	self._timer = self._timer + dtime

	-- Explode on any X or Z facing collision
	if moveresult.collisions[1] == nil then
	elseif moveresult.collisions[1].axis == "x" then
		self:explode()
	elseif moveresult.collisions[1].axis == "z" then
		self:explode()
	end

	-- Remove after flying too long
	if self._timer > 15 then
		self:explode()
	end
end

minetest.register_entity("invector:item_rocket", rocket_ent)

-- Missile ID 4

-- Shield ID 5

-- ION Cannon ID 6

-- Pocket Sand ID 7

local sand_ent = {
	visual = "mesh",
	mesh = "item_sand.b3d",
	makes_footstep_sound = false,
	textures = {"item_sand.png"},
	visual_size = {x=5, y=5},
	collision_box = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	physical = true,
	collide_with_objects = true,
	pointable = false,

	_timer = 0
}

function sand_ent:on_step(dtime, moveresult)
	local tick_scaling = solarsail.util.functions.remap(dtime, tick_speed/4, tick_speed*4, 0.25, 4)
	self._timer = self._timer + dtime
	
	local vel = self.object:get_velocity()
	-- Handle air and ground friction
	if moveresult.touching_ground then
		vel.x = (vel.x * 0.25) * tick_scaling
		vel.z = (vel.z * 0.25) * tick_scaling
	end
	-- Give it some bounce
	if moveresult.collisions[1] == nil then
	elseif moveresult.collisions[1].axis == "x" then
		vel.x = -vel.x * 0.98
	elseif moveresult.collisions[1].axis == "z" then
		vel.z = -vel.z * 0.98
	end
	self.object:set_velocity(vel)

	if self._timer > 10 then
		self.object:remove()
	end
end

minetest.register_entity("invector:item_sand", sand_ent)

-- Mese Crystal ID 8

-- Mese Shards ID 9

-- Nanite Boosters ID 10

-- Time saver for converting an ID to texture.
invector.items.id_to_textures = {
	[1]  = "invector_ui_tnt.png",
	[2]  = "invector_ui_prox_tnt.png",
	[3]  = "invector_ui_rocket.png",
	[4]  = "invector_ui_missile.png",
	[5]  = "invector_ui_shield.png",
	[6]  = "invector_ui_ion_cannon.png",
	[7]  = "invector_ui_sand.png",
	[8]  = "invector_ui_mese_crystal.png",
	[9]  = "invector_ui_mese_shards.png",
	[10] = "invector_ui_nanite_boosters.png",
}

-- [kart position][0-99] = item ID
invector.items.chance = {}

-- Item distribution stats based on position;
local function item_distributor(position, item_defs)
	invector.items.chance[position] = {}
	for id, range in pairs(item_defs) do
		for i=range.min, range.max do
			invector.items.chance[position][i] = id
		end
	end
end

item_distributor(1,
	{
		[1] = {min = 0, max = 24},
		[2] = {min = 25, max = 35},
		[3] = {min = 36, max = 56},
		[5] = {min = 57, max = 67},
		[7] = {min = 68, max = 100},
		--[9] = {min = 90, max = 100}
	}
)

item_distributor(2,
	{
		[1] = {min = 0, max = 9},
		[2] = {min = 10, max = 19},
		[3] = {min = 20, max = 39},
		--[4] = {min = 40, max = 49},
		[5] = {min = 40, max = 54},
		--[6] = {min = 55, max = 64},
		[7] = {min = 55, max = 74},
		[8] = {min = 75, max = 100},
		--[9] = {min = 90, max = 100}
	}
)

item_distributor(3,
	{
		[1] = {min = 0, max = 4}, --TNT
		[2] = {min = 5, max = 9}, --PTNT
		[3] = {min = 10, max = 24}, --Rocket
		--[4] = {min = 25, max = 49}, --Missile
		[5] = {min = 25, max = 59}, --Shield
		--[6] = {min = 60, max = 64}, -- ION Cannon
		[7] = {min = 60, max = 74}, -- Pocket Sand
		[8] = {min = 75, max = 100}, -- Mese Crystal
		--[9] = {min = 95, max = 100} -- Mese Shards
	}
)

item_distributor(4,
	{
		[3] = {min = 0, max = 24}, --Rocket
		--[4] = {min = 25, max = 34}, --Missile
		[5] = {min = 25, max = 44}, --Shield
		--[6] = {min = 45, max = 49}, -- ION Cannon
		[7] = {min = 45, max = 59}, -- Pocket Sand
		[8] = {min = 60, max = 100}, -- Mese Crystal
		--[9] = {min = 95, max = 100} -- Mese Shards
	}
)

item_distributor(5,
	{
		[3] = {min = 0, max = 24}, --Rocket
		--[4] = {min = 25, max = 34}, --Missile
		[5] = {min = 25, max = 44}, --Shield
		--[6] = {min = 45, max = 49}, -- ION Cannon
		[7] = {min = 45, max = 59}, -- Pocket Sand
		[8] = {min = 60, max = 100}, -- Mese Crystal
	    --[9] = {min = 95, max = 100} -- Mese Shards
	}
)

item_distributor(6,
	{
		[3] = {min = 0, max = 24}, --Rocket
		--[4] = {min = 25, max = 34}, --Missile
		[5] = {min = 25, max = 44}, --Shield
		--[6] = {min = 45, max = 49}, -- ION Cannon
		[7] = {min = 45, max = 59}, -- Pocket Sand
		[8] = {min = 60, max = 100}, -- Mese Crystal
		--[9] = {min = 95, max = 100} -- Mese Shards
	}
)

item_distributor(7,
	{
		[3] = {min = 0, max = 4}, --Rocket
		--[4] = {min = 5, max = 34}, --Missile
		--[6] = {min = 35, max = 49}, -- ION Cannon
		[8] = {min = 5, max = 99}, -- Mese Crystal
	}
)

item_distributor(8,
	{
		[3] = {min = 0, max = 4}, --Rocket
		--[4] = {min = 5, max = 34}, --Missile
		--[6] = {min = 35, max = 49}, -- ION Cannon
		[8] = {min = 5, max = 99}, -- Mese Crystal
	}
)

item_distributor(9,
	{
		[3] = {min = 0, max = 4}, --Rocket
		--[4] = {min = 5, max = 34}, --Missile
		--[6] = {min = 35, max = 49}, -- ION Cannon
		[8] = {min = 5, max = 99}, -- Mese Crystal
	}
)

item_distributor(10,
	{
		--[4] = {min = 0, max = 29}, --Missile
		--[6] = {min = 30, max = 49}, -- ION Cannon
		[8] = {min = 0, max = 74}, -- Mese Crystal
		[10] = {min = 75, max = 99}, -- Nanite Regenerators
	}
)

item_distributor(11,
	{
		--[4] = {min = 0, max = 29}, --Missile
		[8] = {min = 0, max = 69}, -- Mese Crystal
		[10] = {min = 70, max = 99}, -- Nanite Regenerators
	}
)

item_distributor(12,
	{
		[8] = {min = 0, max = 69}, -- Mese Crystal
		[10] = {min = 70, max = 99}, -- Nanite Regenerators
	}
)

-- Debug position all items have equal chance
item_distributor(13, {
	[1] = {min = 0, max = 9},
	[2] = {min = 10, max = 19},
	[3] = {min = 20, max = 39},
	--[4] = {min = 30, max = 39},
	[5] = {min = 40, max = 49},
	--[6] = {min = 50, max = 59},
	[7] = {min = 50, max = 69},
	[8] = {min = 70, max = 79},
	[9] = {min = 80, max = 89},
	[10] = {min = 90, max = 99}
})

-- Give items;
function invector.items.give_item(kart_ref)
	local rand = math.random(0, 99)
	local item_id
	if kart_ref._position == nil or kart_ref._position == -1 then
		item_id = invector.items.chance[13][rand]
	else
		item_id = invector.items.chance[kart_ref._position][rand]
	end
	return item_id
end
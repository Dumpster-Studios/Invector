-- Invector, License MIT, Author Jordach

-- Fake third person but works like third person
local default_eye_offset = vector.new(0,0,0)
local ground_eye_offset = vector.new(0,1.7,-30)
local ground_eye_offset_3r = vector.new(0,-10,0)
local player_relative = vector.new(0,0,0)
local player_rot = vector.new(0,0,0)

-- Update rate, don't touch me
local tick_speed = 0.03

-- Bone rotation things;
local kart_root_pos = vector.new(0,0,0)
local kart_root_rot = vector.new(0,0,0)

-- Particle effect things
local rear_left_tyre_pos_min = vector.new(-0.55,0.1,-0.7)
local rear_left_tyre_pos_max = vector.new(-0.4,0.2,-0.7)
local rear_right_tyre_pos_min = vector.new(0.4,0.1,-0.7)
local rear_right_tyre_pos_max = vector.new(0.55,0.2,-0.7)
local rear_left_exhaust_pos_min =  vector.new(-0.35,0.65,-1.05)
local rear_left_exhaust_pos_max =  vector.new(-0.4, 0.65,-1.05)
local rear_right_exhaust_pos_min = vector.new(0.35, 0.65,-1.05)
local rear_right_exhaust_pos_max = vector.new(0.4,  0.65,-1.05)

-- Handling specs
local turning_radius = 0.0472665
local drifting_radius = turning_radius * 1.75
local drifting_radius_lesser = drifting_radius * 0.5
local drifting_radius_greater = drifting_radius * 1.5
local reverse_radius = 0.0204533

-- Speed specs
local max_speed_boost = 13
local max_speed_norm = 7
local forwards_accel = 3
local reverse_accel = -0.55
local braking_factor = 0.75

-- Friction settings
local friction_track = 0.92
local friction_off_track = 0.50
local friction_air = 0

-- Drift time needed to boost
local small_drift_time = 1
local med_drift_time = 2
local big_drift_time = 3

-- Boost specs
local small_boost_time = 0.25
local med_boost_time = 0.5
local big_boost_time = 1.25

-- Empty controls
local controls = {
	up = false,
	down = false,
	left = false,
	right = false,
	jump = false,
	aux1 = false,
	sneak = false,
	LMB = false,
	RMB = false,
}

local drift_particle_def = {
	amount = 50,
	vertical = false,
	collisiondetection = false,
	minexptime = 0.25,
	maxexptime = 0.5,
	glow = 14
}

local exhaust_particle_def = {
	amount = 50,
	vertical = false,
	collisiondetection = false,
	minexptime = 0.15,
	maxexptime = 0.35
}

local nanite_particle_def = {
	amount = 1000,
	time = 10,
	vertical = false,
	collisiondetection = false,
	glow = 14,
	minexptime = 0.5,
	maxexptime = 0.9,
	minvel = vector.new(0,1,0),
	maxvel = vector.new(0,1.5,0),
	minpos = vector.new(-0.5, 0, -0.5),
	maxpos = vector.new(0.5, 0.8, 0.5),
	minsize = 3,
	maxsize = 6,
	texture = "invector_ui_nanite_boosters.png"
}

local kart = {
	visual = "mesh",
	mesh = "default_kart.b3d",
	use_texture_alpha = true,
	backface_culling = false,
	makes_footstep_sound = false,
	textures = {
		"blue_kart_neo.png",
		"blue_skin.png",
		"transparent.png",
		"transparent.png"
	},
	visual_size = {x=1, y=1},
	collisionbox = {-0.61, 0.0, -0.61, 0.61, 1.4, 0.61},
	physical = true,
	collide_with_objects = true,
	pointable = false,
	stepheight = 0.5/16,

	-- Custom fields:
	_attached_player = nil,
	_timer = 0,
	_boost_timer = 0,
	_ai_timer = 0,
	_drift_timer = 0,
	_stun_timer = 0,
	_immune_timer = 0,
	_collision_timer = 0,
	_collision_mod = vector.new(0,0,0),
	_dvel = 0,
	_is_drifting = 0, -- 1 = left, -1 = right
	_drift_level = 0, -- 0 = not drifting, 1 = small, 2 = medium, 3 = big / infinite
	_boost_type = 0, -- 0 = regular smoke, 1 = small boost, 2 = medium boost, 3 = big boost/boost pad
	_is_kart = true, -- Useful for homing weapons or AOE weapons
	_is_creative = minetest.settings:get_bool("creative_mode"),

	-- Set DURING INIT
	_is_ai = false,
	_position = -1, -- Set at race start and during a race
	_racer_id = -1, -- Set on race start since it's likely singleplayer.
	_ai_reaction_timing = {min = 2, max = 25}, -- divided by 10 due to math.random() shenanigans
	_ai_reaction_time = 0,
	_ai_button_press_success = 35, -- Any number rolled lower than X is considered a failure
	_ai_last_waypoint = -1,
	_ai_dist_rand = math.random(1, 250) / 100,
	_track_sector = 1, -- Lap / track sector for non circuits
	_waypoint = 0, -- Similar purpose to _position
	_held_item = 0,
	_shields = false, -- Can take an extra hit without being stunned, can be bypassed by certain weapons
	_last_control = table.copy(controls), -- Memorises the last held button for AI to not make things go wrong

	-- Particle ID holders
	_rear_left_tyre_spawner = nil,
	_rear_right_tyre_spawner = nil,
	_exhaust_left_spawner = nil,
	_exhaust_right_spawner = nil,

	_deo = default_eye_offset,
	_geo = ground_eye_offset,
	_geo3r = ground_eye_offset_3r,
	_prel = player_relative,
	_prot = player_rot
}

-- Things like rockets, missiles, ION Cannon
function kart:spawn_item_forwards()
	local ent
	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()
	local vel = self.object:get_velocity()
	local xm, zm = solarsail.util.functions.yaw_to_vec(yaw, 1)
	local spawn_pos = vector.add(pos, {x=xm*2, y=1.25, z=zm*2})
	local spawn_vel = vector.add(vel, vector.new(xm*15, 0, zm*15))
	if self._held_item == 3 then
		ent = minetest.add_entity(spawn_pos, "invector:item_rocket")
		local particle = table.copy(invector.items.rocket_particle_trail)
		particle.attached = ent
		minetest.add_particlespawner(particle)
		ent:set_velocity(spawn_vel)
	elseif self._held_item == 4 then
		--ent = minetest.add_entity(spawn_pos, "invector:item_missile")
		--local particle = table.copy(invector.items.rocket_particle_trail)
		--particle.attached = ent
		--minetest.add_particlespawner(particle)
		--ent:set_velocity(spawn_vel)
	elseif self._held_item == 6 then
		--ent = minetest.add_entity(spawn_pos, "invector:item_ion_cannon")
		--ent:set_velocity(spawn_vel)
	end
	ent:set_yaw(yaw)
end

function kart:spawn_item_backwards()
	local ent
	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()
	local vel = self.object:get_velocity()
	local xm, zm = solarsail.util.functions.yaw_to_vec(yaw, 1)
	local spawn_pos = vector.add(pos, {x=-xm*2, y=1.25, z=-zm*2})
	local spawn_vel = vector.add(vel, vector.new(xm*-15, 0, zm*-15))
	if self._held_item == 3 then
		ent = minetest.add_entity(spawn_pos, "invector:item_rocket")
		local particle = table.copy(invector.items.rocket_particle_trail)
		particle.attached = ent
		minetest.add_particlespawner(particle)
		ent:set_velocity(spawn_vel)
	elseif self._held_item == 4 then
		--ent = minetest.add_entity(spawn_pos, "invector:item_missile")
		--local particle = table.copy(invector.items.rocket_particle_trail)
		--particle.attached = ent
		--minetest.add_particlespawner(particle)
		--ent:set_velocity(spawn_vel)
	elseif self._held_item == 6 then
		--ent = minetest.add_entity(spawn_pos, "invector:item_ion_cannon")
		--ent:set_velocity(spawn_vel)
	end
	ent:set_yaw(yaw + 3.142)
end

-- Things like sand, TNT, PTNT, mese shards etc
function kart:throw_item_forwards()
	local ent
	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()
	local vel = self.object:get_velocity()
	local xm, zm = solarsail.util.functions.yaw_to_vec(yaw, 1)
	local spawn_pos = vector.add(pos, {x=xm*2, y=0.35, z=zm*2})
	local throw_vel = vector.add(vel, {x=xm*7.2, y=8, z=zm*7.2})
	if self._held_item == 1 then
		ent = minetest.add_entity(spawn_pos, "invector:item_tnt")
	elseif self._held_item == 2 then
		ent = minetest.add_entity(spawn_pos, "invector:item_ptnt")
	elseif self._held_item == 7 then
		ent = minetest.add_entity(spawn_pos, "invector:item_sand")
	elseif self._held_item == 9 then
		--ent = minetest.add_entity(spawn_pos, "invector:item_mese_shards")
	end
	ent:set_acceleration(vector.new(0, -9.71, 0))
	ent:set_velocity(throw_vel)
end

function kart:drop_item_backwards()
	local ent
	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()
	local vel = self.object:get_velocity()
	local xm, zm = solarsail.util.functions.yaw_to_vec(yaw, 1)
	local spawn_pos = vector.add(pos, {x=-xm*2, y=0.35, z=-zm*2})
	local throw_vel = vector.add(vel, {x=0, y=1, z=0})
	if self._held_item == 1 then
		ent = minetest.add_entity(spawn_pos, "invector:item_tnt")
	elseif self._held_item == 2 then
		ent = minetest.add_entity(spawn_pos, "invector:item_ptnt")
	elseif self._held_item == 7 then
		ent = minetest.add_entity(spawn_pos, "invector:item_sand")
	elseif self._held_item == 9 then
		--ent = minetest.add_entity(spawn_pos, "invector:item_mese_shards")
	end
	ent:set_velocity(throw_vel)
	ent:set_acceleration(vector.new(0, -9.71, 0))
end

function kart:clear_boost()
	self._is_drifting = 0
	self._drift_timer = 0
	self._boost_type = 0
	self._boost_timer = 0
end

function kart:on_step(dtime, moveresult)
	if not invector.game_started and not self._is_creative then
		return
	end
	
	-- Avoid the kart logic over or underscaling things due to framerate variability.
	local tick_scaling = solarsail.util.functions.remap(dtime, tick_speed/4, tick_speed*4, 0.25, 4)
	local ratio_tick = solarsail.util.functions.remap(tick_scaling, 0.25, 4, 0, 1)

	-- Add kart stun 
	if self._stun_timer > 0 then
		self._stun_timer = self._stun_timer - dtime
	end
	-- Nanite Regeneration
	if self._immune_timer > 0 then
		self._immune_timer = self._immune_timer - dtime
	end

	-- Impulse from other karts
	if self._collision_timer > 0 then
		self._collision_timer = self._collision_timer - dtime
	else -- Clear the vector
		self._collision_timer = 0
		self._collision_mod = vector.new(0,0,0)
	end

	-- Tick down the level of boost until it completes
	if self._boost_timer > 0 then
		self._boost_timer = self._boost_timer - dtime
	elseif self._boost_type > 0 then
		self._boost_type = 0
	end

	local velocity = self.object:get_velocity()
	local rotation = self.object:get_yaw()
	local cam_rot_offset = 0
	local yaw_offset = 0
	
	local kart_rot_offsets = vector.new(0,0,0)
	local xv, zv
	-- Animation and camera handler:
	local frange, fspeed, fblend, floop = self.object:get_animation()
	local new_frames = {x=0, y=0}

	-- Identify the node under the kart for physics and boost/item detection
	local kart_phys_pos = self.object:get_pos()
	local kart_node_pos = table.copy(kart_phys_pos)
	kart_node_pos.y = kart_node_pos.y - 0.5
	local node_detector = Raycast(kart_phys_pos, kart_node_pos, false, false)
	local node_pos
	if node_detector == nil then
	else
		for pointed in node_detector do
			if pointed.type == "node" then
				node_pos = table.copy(pointed.under)
				break
			end
		end
	end
	local node_data, node
	if node_pos ~= nil then
		node_data = minetest.get_node_or_nil(node_pos)
		node = minetest.registered_nodes[node_data.name]
	end

	
	for k, coll in pairs(moveresult.collisions) do
		if coll.type == "object" then
			local ent_lua = coll.object:get_luaentity()
			if ent_lua._is_kart ~= nil then
				if ent_lua._raceri_id ~= self._racer_id then
					local nx, nz = solarsail.util.functions.yaw_to_vec(rotation, self._dvel*0.75)
					local kart_forwards = vector.new(nx, 0, nz)
					ent_lua._collision_timer = 1
					ent_lua._collision_mod = vector.add(
						kart_forwards,
						vector.subtract(
							vector.multiply(coll.old_velocity, 0.5),
							vector.multiply(coll.new_velocity, 0.5)
						)
					)
					self._dvel = 0
					--break
				end
			end
		end
	end

	-- Handle boost, item, jump, and waypoints
	if node_data ~= nil then
		-- Handle the start/finish line first, then handle waypoints
		if node.groups.sector ~= nil then
			if invector.tracks[invector.current_track] == nil then
			elseif invector.tracks[invector.current_track].track_num_waypoints == self._waypoint then
				self._waypoint = 0
				self._track_sector = self._track_sector + 1
				invector.racers[self._racer_id].sector = self._track_sector
				invector.racers[self._racer_id].waypoint = self._waypoint
				print("lap: " .. self._track_sector)
				print("waypoint: " .. 0)
				self._ai_dist_rand = math.random(1, 250) / 100
			end
		elseif node.groups.waypoint ~= nil then
			if node.groups.waypoint == self._waypoint + 1 then
				self._waypoint = 0 + node.groups.waypoint
				invector.racers[self._racer_id].waypoint = self._waypoint
				print("waypoint: " .. node.groups.waypoint)
				self._ai_dist_rand = math.random(1, 250) / 100
			end
		end

		if node.groups.booster ~= nil then
			if self._boost_timer <= 0 then
				if node.groups.booster == 1 then
					minetest.sound_play("boost_pad_small", {object=self.object, max_hear_distance=8}, true)
				elseif node.groups.booster == 2 then
					minetest.sound_play("boost_pad_big", {object=self.object, max_hear_distance=8}, true)
				end
			end
			self._boost_timer = node.groups.booster
			self._boost_type = 3
		end

		if node.groups.jump ~= nil then
			if moveresult.touching_ground then
				velocity.y = node.groups.jump
			end
		end

		if node.groups.item ~= nil then
			if self._held_item == 0 then
				self._held_item = invector.items.give_item(self.object)
				local textures = self.object:get_properties().textures
				textures[4] = invector.items.id_to_textures[self._held_item]
				self.object:set_properties({textures = textures})
				if self._attached_player ~= nil then
					minetest.sound_play("item_voice_"..self._held_item, {to_player=self._attached_player:get_player_name(), gain=0.8})
				end
				minetest.swap_node(node_pos, {name=node._swap_to})
				minetest.sound_play("item_pickup", {object=self.object, max_hear_distance=8}, true)
				local timer = minetest.get_node_timer(node_pos)
				timer:start(invector.items.pad_timer)
			end
		end
	end

	-- Handle node frictive types here;
	-- Handle friction on ground
	if moveresult.touching_ground then
		local frictive = 0
		if node == nil then
			frictive = friction_off_track
		elseif node.groups == nil then
			frictive = friction_off_track
		elseif node.groups.track == nil then
			frictive = friction_off_track
		else
			frictive = friction_track
		end
		self._dvel = solarsail.util.functions.lerp(self._dvel, self._dvel * (frictive * tick_speed), ratio_tick)
	else -- In air
	end

	-- Round down numbers when percentages exponentialise movement:
	if self._dvel > 0 and self._dvel < 0.05 then
		self._dvel = 0
	elseif self._dvel < 0 and self._dvel > -0.05 then
		self._dvel = 0
	end

	-- Handle controls for players and AI
	local control = controls
	if self._attached_player ~= nil then
		control = solarsail.controls.player[self._attached_player:get_player_name()]
		self._last_control = control
	elseif self._is_ai and self._ai_timer >= self._ai_reaction_time then
		local new_control, new_reaction_time = invector.ai.think(self)
		control = new_control
		self._last_control = new_control
		self._ai_timer = 0
		self._ai_reaction_time = new_reaction_time
	elseif self._is_ai then
		control = self._last_control
		self._ai_timer = self._ai_timer + dtime
	end

	if self._stun_timer <= 0 then
		-- Handle controls;
		-- Accel braking;
		if control.up or self._forced_boost then
			local boost_multi = 1
			if self._boost_timer > 0 then
				boost_multi = 3
			elseif node == nil then
				boost_multi = 0.15
			elseif node.groups == nil then
				boost_multi = 0.15
			elseif node.groups.track == nil then
				boost_multi = 0.15
			end
			self._dvel = self._dvel + ((forwards_accel * boost_multi) * tick_scaling)
		elseif control.down then
			-- Reversing
			local racc_div = 1
			-- Make braking half as effective compared to reversing
			if self._dvel > 0 then racc_div = 2 end
			self._dvel = self._dvel + ((reverse_accel/racc_div) * tick_scaling)
		end

		-- Drifting, turning, do not turn when airborne;
		if velocity.y ~= 0 then
		elseif control.jump and self._dvel > 5.5 then
			-- Direction of drifting
			if self._is_drifting == 0 then
				if control.left then
					self._is_drifting = 1
				elseif control.right then
					self._is_drifting = -1
				end
			else
				-- Increment timer for boost
				self._drift_timer = self._drift_timer + dtime

				-- Drift steering
				if control.left then
					if self._is_drifting == 1 then --Left
						yaw_offset = drifting_radius_greater * tick_scaling
					elseif self._is_drifting == -1 then
						yaw_offset = -drifting_radius_lesser * tick_scaling
					end
				elseif control.right then
					if self._is_drifting == 1 then --Left adds, right removes
						yaw_offset = drifting_radius_lesser * tick_scaling
					elseif self._is_drifting == -1 then
						yaw_offset = -drifting_radius_greater * tick_scaling
					end
				else
					if self._is_drifting == 1 then --Left
						yaw_offset = drifting_radius * tick_scaling
					elseif self._is_drifting == -1 then
						yaw_offset = -drifting_radius * tick_scaling
					end
				end
			end
		elseif control.left then
			-- Fowards
			if self._dvel > 0.25 then
				yaw_offset = turning_radius * tick_scaling
			-- Reversing
			elseif self._dvel < -0.1 then
				yaw_offset = -reverse_radius * tick_scaling
			end
		elseif control.right then
			-- Fowards
			if self._dvel > 0.5 then
				yaw_offset = -turning_radius * tick_scaling
			-- Reversing
			elseif self._dvel < -0.1 then
				yaw_offset = reverse_radius * tick_scaling
			end
		end

		-- Give the boost
		if not control.jump and self._boost_timer <= 0 then
			self._is_drifting = 0
			-- Maximum boost
			if self._drift_timer >= big_drift_time then
				self._boost_timer = big_boost_time
				self._boost_type = 3
				self._drift_timer = 0
				minetest.sound_play("drift_boost_big", {object=self.object, max_hear_distance=8}, true)
			-- Medium boost
			elseif self._drift_timer >= med_drift_time then
				self._boost_timer = med_boost_time
				self._boost_type = 2
				self._drift_timer = 0
				minetest.sound_play("drift_boost_med", {object=self.object, max_hear_distance=8}, true)
			-- Small boost
			elseif self._drift_timer >= small_drift_time then
				self._boost_timer = small_boost_time
				self._boost_type = 1
				self._drift_timer = 0
				minetest.sound_play("drift_boost_small", {object=self.object, max_hear_distance=8}, true)
			end
		end

		-- Do not give a boost if falling under the drifting speed or while in air
		if self._dvel <= 5 or velocity.y ~= 0 then
			if self._is_drifting ~= 0 then self:clear_boost() end
		end

		-- Use Item/Item Alt mode; usually in the form of throw forwards or backwards
		if control.LMB and self._held_item > 0 then
			if self._held_item == 1 or self._held_item == 2 then -- TNT family
				self:drop_item_backwards()
			elseif self._held_item == 3 or self._held_item == 4 then -- Rocket Family
				self:spawn_item_forwards()
			elseif self._held_item == 5 then -- Shield
				if not self._shields then
					self._shields = true
					local textures = self.object:get_properties().textures
					textures[3] = "invector_kart_shield.png"
					self.object:set_properties({textures=textures})
				end
			elseif self._held_item == 6 then -- Ion Cannon
				self:spawn_item_forwards()
			elseif self._held_item == 7 then -- Sand
				self:drop_item_backwards()
			elseif self._held_item == 8 then -- Mese Crystal
				self._boost_timer = 2
				self._boost_type = 3
				minetest.sound_play("boost_pad_big", {object=self.object, max_hear_distance=8}, true)
			elseif self._held_item == 9 then -- Mese Shards
			elseif self._held_item == 10 then -- Nanites
				local particles = table.copy(nanite_particle_def)
				particles.attached = self.object
				minetest.add_particlespawner(particles)
				self._boost_timer = 10
				self._boost_type = 3
				self._immune_timer = 10
			end
			self._held_item = 0
			local textures = self.object:get_properties().textures
			textures[4] = "transparent.png"
			self.object:set_properties({textures = textures})
		elseif control.RMB and self._held_item > 0 then
			if self._held_item == 1 or self._held_item == 2 then
				self:throw_item_forwards()
			elseif self._held_item == 3 or self._held_item == 4 then -- Rocket Family
				self:spawn_item_backwards()
			elseif self._held_item == 5 then -- Shield
				if not self._shields then
					self._shields = true
					local textures = self.object:get_properties().textures
					textures[3] = "invector_kart_shield.png"
					self.object:set_properties({textures=textures})
				end
			elseif self._held_item == 6 then -- Ion Cannon
				self:spawn_item_backwards()
			elseif self._held_item == 7 then -- Sand
				self:throw_item_forwards()
			elseif self._held_item == 8 then -- Mese Crystal
				self._boost_timer = 2
				self._boost_type = 3
				minetest.sound_play("boost_pad_big", {object=self.object, max_hear_distance=8}, true)
			elseif self._held_item == 9 then -- Mese Shards
			elseif self._held_item == 10 then -- Nanites
				local particles = table.copy(nanite_particle_def)
				particles.attached = self.object
				minetest.add_particlespawner(particles)
				self._boost_timer = 10
				self._boost_type = 3
				self._immune_timer = 10
			end
			self._held_item = 0
			local textures = self.object:get_properties().textures
			textures[4] = "transparent.png"
			self.object:set_properties({textures = textures})
		end
			
		-- Animation frames while driving.
		if control.up then
			if control.left then
				new_frames.x = 60
				new_frames.y = 79
			elseif control.right then
				new_frames.x = 120
				new_frames.y = 139
			else
				new_frames.x = 0
				new_frames.y = 19
			end
		elseif control.down then -- Reversing
			if self._dvel > 0.5 then
				if control.left then
					new_frames.x = 60
					new_frames.y = 79
				elseif control.right then
					new_frames.x = 120
					new_frames.y = 139
				else
					new_frames.x = 0
					new_frames.y = 19
				end
			elseif self._dvel < -0.5 then
				if control.left then
					new_frames.x = 90
					new_frames.y = 109
				elseif control.right then
					new_frames.x = 150
					new_frames.y = 169
				else
					new_frames.x = 30
					new_frames.y = 49
				end
			end
		else -- Coming to a stop or idle
			if self._dvel > 0.5 then
				if control.left then
					new_frames.x = 60
					new_frames.y = 79
				elseif control.right then
					new_frames.x = 120
					new_frames.y = 139
				else
					new_frames.x = 0
					new_frames.y = 19
				end
			elseif self._dvel < -0.5 then
				if control.left then
					new_frames.x = 90
					new_frames.y = 109
				elseif control.right then
					new_frames.x = 150
					new_frames.y = 169
				else
					new_frames.x = 30
					new_frames.y = 49
				end
			else -- Idle
				if control.left then
					new_frames.x = 79
					new_frames.y = 79
				elseif control.right then
					new_frames.x = 139
					new_frames.y = 139
				else
					new_frames.x = 19
					new_frames.y = 19
				end
			end
		end
		
		xv, zv = solarsail.util.functions.yaw_to_vec(rotation+yaw_offset, self._dvel)
		local new_vel = vector.new(xv, 0, zv)
		new_vel = vector.normalize(new_vel)
		new_vel.y = velocity.y

		-- Particlespawner handler
		-- Exhausts;
		local exhaust_particle = table.copy(exhaust_particle_def)
		exhaust_particle.attached = self.object
		exhaust_particle.minvel = vector.new(-0.05, 0.5, -0.25)
		exhaust_particle.maxvel = vector.new(-0.15, 1.2, -0.5)
		exhaust_particle.minpos = rear_left_exhaust_pos_min
		exhaust_particle.maxpos = rear_left_exhaust_pos_max
		if self._boost_type == 0 and self._exhaust_left_spawner == nil then
			exhaust_particle.time = 0
			exhaust_particle.glow = 0
			exhaust_particle.node = {name = "invector:smoke_node"}
			exhaust_particle.minsize = 1
			exhaust_particle.maxsize = 1.15
			self._exhaust_left_spawner = minetest.add_particlespawner(exhaust_particle)
			exhaust_particle.minpos = rear_right_exhaust_pos_min
			exhaust_particle.maxpos = rear_right_exhaust_pos_max
			exhaust_particle.minvel.x = 0.05
			exhaust_particle.maxvel.x = 0.15
			self._exhaust_right_spawner = minetest.add_particlespawner(exhaust_particle)
		elseif self._boost_type == 1 then
			exhaust_particle.time = self._boost_timer
			exhaust_particle.glow = 14
			exhaust_particle.node = {name = "invector:boost_1_node"}
			exhaust_particle.minsize = 1.15
			exhaust_particle.maxsize = 1.4
			minetest.add_particlespawner(exhaust_particle)
			exhaust_particle.minpos = rear_right_exhaust_pos_min
			exhaust_particle.maxpos = rear_right_exhaust_pos_max
			exhaust_particle.minvel.x = 0.05
			exhaust_particle.maxvel.x = 0.15
			minetest.add_particlespawner(exhaust_particle)
		elseif self._boost_type == 2 then
			exhaust_particle.time = self._boost_timer
			exhaust_particle.glow = 14
			exhaust_particle.node = {name = "invector:boost_2_node"}
			exhaust_particle.minsize = 1.4
			exhaust_particle.maxsize = 1.65
			minetest.add_particlespawner(exhaust_particle)
			exhaust_particle.minpos = rear_right_exhaust_pos_min
			exhaust_particle.maxpos = rear_right_exhaust_pos_max
			exhaust_particle.minvel.x = 0.05
			exhaust_particle.maxvel.x = 0.15
			minetest.add_particlespawner(exhaust_particle)
		elseif self._boost_type == 3 then
			exhaust_particle.time = self._boost_timer
			exhaust_particle.glow = 14
			exhaust_particle.node = {name = "invector:boost_3_node"}
			exhaust_particle.minsize = 1.65
			exhaust_particle.maxsize = 1.95
			minetest.add_particlespawner(exhaust_particle)
			exhaust_particle.minpos = rear_right_exhaust_pos_min
			exhaust_particle.maxpos = rear_right_exhaust_pos_max
			exhaust_particle.minvel.x = 0.05
			exhaust_particle.maxvel.x = 0.15
			minetest.add_particlespawner(exhaust_particle)
		end

		-- Rear Tyres;
		local drift_particle = table.copy(drift_particle_def)
		drift_particle.attached = self.object
		drift_particle.minvel = vector.new(-new_vel.x/2, (-new_vel.y/2)+0.5, -new_vel.z/2)
		drift_particle.maxvel = vector.new(-new_vel.x, (-new_vel.y)+0.75, -new_vel.z)
		if self._drift_timer >= big_drift_time then
			if self._drift_level == 2 then
				minetest.sound_play("drift_spark_big", {object=self.object, max_hear_distance=8}, true)
				self._drift_level = 3
				drift_particle.time = 0
				drift_particle.texture = "invector_drift_big.png"
				drift_particle.minsize = 3
				drift_particle.maxsize = 4
				drift_particle.minpos = rear_left_tyre_pos_min
				drift_particle.maxpos = rear_left_tyre_pos_max
				self._rear_left_tyre_spawner = minetest.add_particlespawner(drift_particle)
				drift_particle.minpos = rear_right_tyre_pos_min
				drift_particle.maxpos = rear_right_tyre_pos_max
				self._rear_right_tyre_spawner = minetest.add_particlespawner(drift_particle)
			end
		elseif self._drift_timer >= med_drift_time and self._drift_level == 1 then
			minetest.sound_play("drift_spark_med", {object=self.object, max_hear_distance=8}, true)
			self._drift_level = 2
			drift_particle.time = 1.35
			drift_particle.texture = "invector_drift_medium.png"
			drift_particle.minsize = 2
			drift_particle.maxsize = 3
			drift_particle.minpos = rear_left_tyre_pos_min
			drift_particle.maxpos = rear_left_tyre_pos_max
			minetest.add_particlespawner(drift_particle)
			drift_particle.minpos = rear_right_tyre_pos_min
			drift_particle.maxpos = rear_right_tyre_pos_max
			minetest.add_particlespawner(drift_particle)
		elseif self._drift_timer >= small_drift_time and self._drift_level == 0 then
			minetest.sound_play("drift_spark_small", {object=self.object, max_hear_distance=8}, true)
			self._drift_level = 1
			drift_particle.time = 1.35
			drift_particle.texture = "invector_drift_small.png"
			drift_particle.minsize = 1
			drift_particle.maxsize = 2
			drift_particle.minpos = rear_left_tyre_pos_min
			drift_particle.maxpos = rear_left_tyre_pos_max
			minetest.add_particlespawner(drift_particle)
			drift_particle.minpos = rear_right_tyre_pos_min
			drift_particle.maxpos = rear_right_tyre_pos_max
			minetest.add_particlespawner(drift_particle)
		elseif self._rear_left_tyre_spawner ~= nil then
			-- Clear max boost particles
			minetest.delete_particlespawner(self._rear_left_tyre_spawner)
			minetest.delete_particlespawner(self._rear_right_tyre_spawner)
			self._rear_left_tyre_spawner = nil
			self._rear_right_tyre_spawner = nil
			self._drift_level = 0
		end

		-- Limit velocity based on boost status
		if self._boost_timer > 0 then
			if self._dvel > max_speed_boost then
				self._dvel = max_speed_boost
			elseif self._dvel < -max_speed_boost then
				self._dvel = -max_speed_boost
			end
		else
			if self._dvel > max_speed_norm then
				self._dvel = max_speed_norm
			elseif self._dvel < -max_speed_norm then
				self._dvel = -max_speed_norm
			end
		end
	else
		-- Stunned animation.
		new_frames.x = 180
		new_frames.y = 209
	end
	
	-- Set camera rotation for players only
	if not self._last_control.sneak and self._attached_player ~= nil then
		if self._attached_player:get_look_vertical() ~= 0 then
			self._attached_player:set_look_vertical(0)
		end
		if self._attached_player:get_look_horizontal() ~= rotation+cam_rot_offset then
			-- Reversing camera mode if required
			if self._dvel < -0.5 and control.down then
				cam_rot_offset = 3.142
			end
			self._attached_player:set_look_horizontal(rotation+cam_rot_offset)
		end
	end

	-- Set object rotation and speed, if the kart enters a stunned state; it'll slide in place
	if not moveresult.touching_ground then
		xv = nil
		zv = nil
	end

	if xv == nil or zv == nil then
		self.object:set_velocity(
			vector.add(
				velocity, 
				vector.new(
					self._collision_mod.x*self._collision_timer,
					self._collision_mod.y*self._collision_timer,
					self._collision_mod.z*self._collision_timer
				)
			)
		)
	else
		self.object:set_velocity(
			vector.add(
				{x=xv, y=velocity.y, z=zv},
				vector.new(
					self._collision_mod.x*self._collision_timer,
					self._collision_mod.y*self._collision_timer,
					self._collision_mod.z*self._collision_timer
				)
			)
		)
	end
	self.object:set_rotation(vector.new(kart_rot_offsets.x, rotation+yaw_offset, 0))

	-- Compare against frame table to avoid re-applying the animation
	if frange.x ~= new_frames.x then
		self.object:set_animation(new_frames, 60, 0.1, true)
	end

	-- Disable regular smoke when boosting or stunned
	if self._boost_type > 0 and self._exhaust_left_spawner ~= nil then
		minetest.delete_particlespawner(self._exhaust_left_spawner)
		minetest.delete_particlespawner(self._exhaust_right_spawner)
		self._exhaust_left_spawner = nil
		self._exhaust_right_spawner = nil
	elseif self._stun_timer > 0 and self._exhaust_left_spawner ~= nil then
		minetest.delete_particlespawner(self._exhaust_left_spawner)
		minetest.delete_particlespawner(self._exhaust_right_spawner)
		self._exhaust_left_spawner = nil
		self._exhaust_right_spawner = nil
	end

	-- Allow exiting the kart while in creative mode to test changes even when stunned;
	if control.aux1 and self._is_creative then
		if self._attached_player ~= nil then
			self._attached_player:set_detach()
			self._attached_player:hud_set_flags({
				crosshair = true,
				hotbar = true,
				healthbar = true,
				wielditem = true,
				breathbar = true
			})
			self._attached_player:set_eye_offset()
			self._attached_player = nil
			self.object:remove()
			return
		end
	end
end

invector.functions.register_kart("kart", kart)
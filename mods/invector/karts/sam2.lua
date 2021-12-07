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
local front_left_tyre_pos = vector.new(0,0,0)
local front_right_tyre_pos = vector.new(0,0,0)
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

local drift_particle_def = {
	amount = 50,
	vertical = false,
	collisiondetection = false,
	minexptime = 0.25,
	maxexptime = 0.5,
	glow = 14
}

local exhause_particle_def = {
	amount = 50,
	vertical = false,
	collisiondetection = false,
	minexptime = 0.15,
	maxexptime = 0.35
}

local kart = {
	visual = "mesh",
	mesh = "sam2.b3d",
	use_texture_alpha = true,
	backface_culling = false,
	makes_footstep_sound = true,
	textures = {
		"sam2_kart_neo.png",
		"sam2_skin.png",
	},
	visual_size = {x=1, y=1},
	collisionbox = {-0.61, 0.0, -0.61, 0.61, 1.4, 0.61},
	physical = true,
	collide_with_objects = true,
	pointable = false,
	stepheight = 0.5/16,

	-- Custom fields:
	_timer = 0,
	_boost_timer = 0,
	_drift_timer = 0,
	_stun_timer = 0,
	_immune_timer = 0,
	_xvel = 0,
	_zvel = 0,
	_dvel = 0,
	_yvel = 0,
	_last_cam_offset = 0,
	_is_drifting = 0, -- 1 = left, -1 = right
	_drift_level = 0, -- 0 = not drifting, 1 = small, 2 = medium, 3 = big / infinite
	_boost_type = 0, -- 0 = regular smoke, 1 = small boost, 2 = medium boost, 3 = big boost/boost pad
	_is_kart = true,
	_is_ai_capable = false,
	_held_item = nil,
	_held_item_uses = nil,
	_shields = true, -- Can take an extra hit without being stunned
	_position = -1, -- Set at race start and during a race
	_course_node = -1, -- Similar purpose to _position
	_track_sector = -1, -- Lap / track sector for non circuits
	_racer_id = -1, -- Set on game startup since it's likely singleplayer.

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

function kart:on_step(dtime)
	-- Avoid the kart logic over or underscaling things due to framerate variability.
	local tick_scaling = solarsail.util.functions.remap(dtime, tick_speed/4, tick_speed*4, 0.25, 4)
	-- Add kart stun 
	if self._stun_timer > 0 then
		self._stun_timer = self._stun_timer - dtime
	end
	if self._immune_timer > 0 then
		self._immune_timer = self._immune_timer - dtime
	end

	if self.attached_player ~= nil and self._stun_timer <= 0 then
		local control = solarsail.controls.player[self.attached_player:get_player_name()]
		if control == nil then return end

		-- Allow exiting the kart while in creative mode to test changes;
		if control.aux1 and minetest.settings:get_bool("creative_mode") then
			self.attached_player:set_detach()
			self.attached_player:hud_set_flags({
				crosshair = true,
				hotbar = true,
				healthbar = true,
				wielditem = true,
				breathbar = true
			})
			self.attached_player:set_eye_offset()
			self.attached_player = nil
			return
		end

		local ratio_tick = solarsail.util.functions.remap(tick_scaling, 0.25, 4, 0, 1)
		local velocity = self.object:get_velocity()
		local accel = self.object:get_acceleration()
		local rotation = self.object:get_yaw()
		local cam_rot_offset = 0
		local yaw_offset = 0
		local last_rot_offsets = self.object:get_rotation()
		local kart_rot_offsets = vector.new(0,0,0)

		-- Identify the node under the kart for physics and boost/item detection
		local kart_phys_pos = self.object:get_pos()
		local kart_node_pos = table.copy(kart_phys_pos)
		kart_node_pos.y = kart_node_pos.y - 1.5
		local node_detector = Raycast(kart_phys_pos, kart_node_pos, false, false)
		local node_pos
		for pointed in node_detector do
			if pointed == nil then
			else
				if pointed.type == "node" then
					node_pos = table.copy(pointed.under)
					break
				end
			end
		end
		local node_data = minetest.get_node_or_nil(node_pos)
		local node = minetest.registered_nodes[node_data.name]
		
		if node.groups.booster ~= nil then
			if self._boost_timer <= 0 then
				self._boost_timer = node.groups.booster
				self._boost_type = 3
			end
		end

		if node.groups.item ~= nil then
			minetest.swap_node(node_pos, {name=node._swap_to})
			local timer = minetest.get_node_timer(node_pos)
			timer:start(3)
		end

		-- Handle node frictive types here;
		-- Handle friction on ground
		if velocity.y == 0 then
			local frictive = 0
			if node.groups.track == nil then
				frictive = friction_off_track
			else
				frictive = friction_track
			end
			self._dvel = solarsail.util.functions.lerp(self._dvel, self._dvel * (frictive * tick_speed), ratio_tick)
		else -- In air
			self._dvel = solarsail.util.functions.lerp(self._dvel, self._dvel * (friction_air * tick_speed), ratio_tick)
		end

		-- Round down numbers when percentages exponentialise movement:
		if self._dvel > 0 and self._dvel < 0.2 then
			self._dvel = 0
		elseif self._dvel < 0 and self._dvel > -0.2 then
			self._dvel = 0
		end

		-- Handle controls;
		-- Accel braking;
		if control.up or self._boost_timer > 0 then
			local boost_multi = 1
			if self._boost_timer > 0 then
				boost_multi = 3
			end
			self._dvel = self._dvel + ((forwards_accel * boost_multi) * tick_scaling)
		elseif control.down then
			-- Reversing
			local racc_div = 1
			-- Make braking half as effective compared to reversing
			if self._dvel > 0 then racc_div = 2 end
			self._dvel = self._dvel + ((reverse_accel/racc_div) * tick_scaling)
		end

		-- Drifting;
		if control.jump and self._dvel > 5.5 then
			-- Direction of drifting
			if self._is_drifting == 0 then
				if control.left then
					self._is_drifting = 1
				elseif control.right then
					self._is_drifting = -1
				end
			end
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

		-- Tick down the level of boost until it completes
		if self._boost_timer > 0 then
			self._boost_timer = self._boost_timer - dtime
		elseif self._boost_type > 0 then
			self._boost_type = 0
		end

		-- Give the boost
		if not control.jump then
			self._is_drifting = 0
			-- Maximum boost
			if self._drift_timer >= big_drift_time then
				self._boost_timer = big_boost_time
				self._boost_type = 3
				self._drift_timer = 0
			-- Medium boost
			elseif self._drift_timer >= med_drift_time then
				self._boost_timer = med_boost_time
				self._boost_type = 2
				self._drift_timer = 0
			-- Small boost
			elseif self._drift_timer >= small_drift_time then
				self._boost_timer = small_boost_time
				self._boost_type = 1
				self._drift_timer = 0
			end
		end

		-- Do not give a boost if falling under the drifting speed or while in air
		if self._dvel <= 5 or velocity.y ~= 0 then
			self._is_drifting = 0
			self._drift_timer = 0
			self._boost_type = 0
			self._boost_timer = 0
		end

		-- Use Item/Boost;
		if control.LMB then
		elseif control.RMB then
		end

		local xv, zv = solarsail.util.functions.yaw_to_vec(rotation+yaw_offset, self._dvel, false)
		local new_vel = vector.new(xv, 0, zv)
		new_vel = vector.normalize(new_vel)
		new_vel.y = velocity.y

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

		-- Animation and camera handler:
		local frange, fspeed, fblend, floop = self.object:get_animation()
		local new_frames = {x=0, y=0}
		local new_fps = 60
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

		-- Compare against frame table to avoid re-applying the animation
		if frange.x ~= new_frames.x then
			self.object:set_animation(new_frames, 60, 0.1, true)
		end

		-- Reversing camera mode if required
		if self._dvel < -0.5 and control.down then
			cam_rot_offset = 3.142
		end

		-- Particlespawner handler
		-- Exhausts;
		local exhaust_particle = table.copy(exhause_particle_def)
		exhaust_particle.attached = self.object
		exhaust_particle.minvel = vector.new((-new_vel.x/4)-0.05, (-new_vel.y/4)+0.5, (-new_vel.z/4)-0.25)
		exhaust_particle.maxvel = vector.new((-new_vel.x/2)-0.15, (-new_vel.y/2)+1.2, (-new_vel.z/2)-0.5)
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
			exhaust_particle.minvel.x = (-new_vel.x/4)+0.05
			exhaust_particle.maxvel.x = (-new_vel.x/2)+0.15
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
			exhaust_particle.minvel.x = (-new_vel.x/4)+0.05
			exhaust_particle.maxvel.x = (-new_vel.x/2)+0.15
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
			exhaust_particle.minvel.x = (-new_vel.x/4)+0.05
			exhaust_particle.maxvel.x = (-new_vel.x/2)+0.15
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
			exhaust_particle.minvel.x = (-new_vel.x/4)+0.05
			exhaust_particle.maxvel.x = (-new_vel.x/2)+0.15
			minetest.add_particlespawner(exhaust_particle)
		end

		-- Disable regular smoke when boosting
		if self._boost_type > 0 and self._exhaust_left_spawner ~= nil then
			minetest.delete_particlespawner(self._exhaust_left_spawner)
			minetest.delete_particlespawner(self._exhaust_right_spawner)
			self._exhaust_left_spawner = nil
			self._exhaust_right_spawner = nil
		end

		-- Rear Tyres;
		local drift_particle = table.copy(drift_particle_def)
		drift_particle.attached = self.object
		drift_particle.minvel = vector.new(-new_vel.x/2, (-new_vel.y/2)+0.5, -new_vel.z/2)
		drift_particle.maxvel = vector.new(-new_vel.x, (-new_vel.y)+0.75, -new_vel.z)
		if self._drift_timer >= big_drift_time and self._rear_left_tyre_spawner == nil then
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
		elseif self._drift_timer >= med_drift_time and self._drift_level == 1 then
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

		-- Set camera rotation
		if not control.sneak then
			if self.attached_player:get_look_vertical() ~= 0 then
				self.attached_player:set_look_vertical(0)
			end
			if self.attached_player:get_look_horizontal() ~= rotation+cam_rot_offset then
				self.attached_player:set_look_horizontal(rotation+cam_rot_offset)
			end
		end

		-- Set object rotation and speed
		self.object:set_velocity({x=xv, y=velocity.y, z=zv})
		self.object:set_rotation(vector.new(kart_rot_offsets.x, rotation+yaw_offset, 0))
	else -- Self destruct
		--self.object:remove()
	end
end

invector.functions.register_kart("sam2", kart)
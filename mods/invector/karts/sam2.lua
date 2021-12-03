-- Invector, License MIT, Author Jordach

-- Fake third person but works like third person
local default_eye_offset = vector.new(0,0,0)
local ground_eye_offset = vector.new(0,1.8,-30)
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
local rear_left_tyre_pos = vector.new(0,0,0)
local rear_right_tyre_pos = vector.new(0,0,0)
local rear_left_exhaust_pos = vector.new(0,0,0)
local rear_right_exhaust_pos = vector.new(0,0,0)

-- Handling specs
local turning_radius = 0.0472665
local drifting_radius = turning_radius * 1.75
local drifting_radius_lesser = drifting_radius * 0.5
local drifting_radius_greater = drifting_radius * 1.5
local reverse_radius = 0.0174533

-- Speed specs
local max_speed_boost = 8
local max_speed_norm = 6
local forwards_accel = 3
local reverse_accel = -0.25
local braking_factor = 0.75

-- Boost specs
local small_boost_time = 1.5
local med_boost_time = 3
local big_boost_time = 5

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
	_xvel = 0,
	_zvel = 0,
	_dvel = 0,
	_yvel = 0,
	_last_cam_offset = 0,
	_is_drifting = 0, -- 1 = left, -1 = right

	-- Particle ID holders
	_rear_left_tyre_spawner = 0,
	_rear_right_tyre_spawner = 0,
	_exhaust_left_spawner = 0,
	_exhaust_right_spawner = 0,

	_deo = default_eye_offset,
	_geo = ground_eye_offset,
	_geo3r = ground_eye_offset_3r,
	_prel = player_relative,
	_prot = player_rot
}

function kart:on_step(dtime)
	if self.attached_player ~= nil then
		self._timer = self._timer + dtime
		if self._timer > tick_speed then
			self._timer = 0
			local control = solarsail.controls.player[self.attached_player:get_player_name()]
			if control == nil then return end

			--[[ if control.aux1 then
				self.attached_player:set_detach()
				self.attached_player = nil
				return
			end ]]

			if self._boost_timer > 0 then
				self._boost_timer = self._boost_timer - dtime
			end
			--self.object:set_animation({x=0, y=159}, 60, 0)
			local velocity = self.object:get_velocity()
			local accel = self.object:get_acceleration()
			local rotation = self.object:get_yaw()
			local cam_rot_offset = 0
			local yaw_offset = 0

			if velocity.y == 0 then
				-- Handle node frictive types here;

				-- Handle friction
				if self._dvel > 1 then
					self._dvel = self._dvel - 1
				else
					self._dvel = self._dvel * 0.96
				end
			end

			-- Round down numbers when percentages exponentialise movement:
			if self._dvel < 0.1 and self._dvel > 0 then
				self._dvel = 0
			elseif self._dvel > -0.1 and self._dvel < 0 then
				self._dvel = 0
			end

			-- Handle controls;
			-- Accel braking;
			if control.up then
				self._dvel = self._dvel + forwards_accel
			elseif control.down then
				-- Reversing
				if self._dvel < 0.1 then
					self._dvel = self._dvel + reverse_accel
				else
					self._dvel = self._dvel * braking_factor
				end
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
				-- Drift steering
				if control.left then
					if self._is_drifting == 1 then --Left
						yaw_offset = drifting_radius_greater
					elseif self._is_drifting == -1 then
						yaw_offset = -drifting_radius_lesser
					end
				elseif control.right then
					if self._is_drifting == 1 then --Left adds, right removes
						yaw_offset = drifting_radius_lesser
					elseif self._is_drifting == -1 then
						yaw_offset = -drifting_radius_greater
					end
				else
					if self._is_drifting == 1 then --Left
						yaw_offset = drifting_radius
					elseif self._is_drifting == -1 then
						yaw_offset = -drifting_radius
					end
				end
			elseif control.left then
				-- Fowards
				if self._dvel > 0.5 then
					yaw_offset = turning_radius
				-- Reversing
				elseif self._dvel < -0.1 then
					cam_rot_offset = 3.142
					yaw_offset = -reverse_radius
				end
			elseif control.right then
				-- Fowards
				if self._dvel > 0.5 then
					yaw_offset = -turning_radius
				-- Reversing
				elseif self._dvel < -0.1 then
					cam_rot_offset = 3.142
					yaw_offset = reverse_radius
				end
			end

			-- Give the boost
			if not control.jump then
				self._is_drifting = 0
				-- Maximum boost
				if self._drift_timer >=5 then
					self._boost_timer = 3
				-- Medium boost
				elseif self._drift_timer >=3 then
					self._boost_timer = 2
				-- Small boost
				elseif self._drift_timer >=1.5 then
					self._boost_timer = 1
				end
			end
			-- Do not give a boost if falling under the drifting speed
			if self._dvel <= 5 then
				self._is_drifting = 0
				self._drift_timer = 0
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
				if self._dvel > 1.5 then
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
				elseif self._dvel < -1.5 then
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
				if self._dvel > 1.5 then
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
				elseif self._dvel < -1.5 then
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

			if frange.x ~= new_frames.x then
				if frange.y ~= new_frames.y then
					self.object:set_animation(new_frames, 60, 0.1, true)
				end
			end

			-- Reversing camera mode if required
			if self._dvel < -1 and control.down then
				cam_rot_offset = 3.142
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
			self.object:set_yaw(rotation+yaw_offset)
		end
	else -- Self destruct
		--self.object:remove()
	end
end

invector.functions.register_kart("sam2", kart)
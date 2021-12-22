-- Invector, License MIT, Author Jordach

-- AI handling routines.

invector.ai = {}

invector.ai.difficulty = {
	[1] = {tmin=22, tmax=23*2, frate=12},
	[2] = {tmin=21, tmax=22*2, frate=11},
	[3] = {tmin=20, tmax=21*2, frate=10},
	[4] = {tmin=19, tmax=20*2, frate=9},
	[5] = {tmin=18, tmax=19*2, frate=8},
	[6] = {tmin=17, tmax=18*2, frate=7},
	[7] = {tmin=16, tmax=17*2, frate=6},
	[8] = {tmin=15, tmax=16*2, frate=5},
	[9] = {tmin=14, tmax=15*2, frate=4},
	[10] = {tmin=13, tmax=14*2, frate=3},
	[11] = {tmin=12, tmax=13*2, frate=2},
	[12] = {tmin=11, tmax=12*2, frate=1},
}

local controls_template = {
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

invector.ai.known_node_targets = {}

function invector.ai.think(self)
	local controls = table.copy(self._last_control)

	local kart_pos = self.object:get_pos()
	local node_pos = vector.new(
		math.floor(kart_pos.x),
		math.floor(kart_pos.y),
		math.floor(kart_pos.z)
	)

	local kart_yaw = self.object:get_yaw()
	local vel = self.object:get_velocity()
	local thonk_timer_new = 1

	controls.left = false
	controls.right = false
	controls.up = false
	controls.jump = false
	-- Prefer waypoints that are marked as track rather than off track
	-- by lack of the node group.
	local cross = 0
	local function preferential_waypoints(pos, target_pos)
		local area_min = vector.new(node_pos.x-32, node_pos.y-32, node_pos.z-32)
		local area_max = vector.new(node_pos.x+32, node_pos.y+32, node_pos.z+32)
		local node_target
		-- Scan for the start/finish line first if it's up next
		if invector.tracks[invector.current_track] == nil then
			error("Track data missing?")
		elseif invector.tracks[invector.current_track].track_num_waypoints == self._waypoint then
			node_target = "invector:sector_marker"
		else
			node_target = "invector:waypoint_" .. self._waypoint + 1
		end

		local target_nodes = minetest.find_nodes_in_area(area_min, area_max, node_target, false)
		-- Make a list of valid nodes
		local node_targets = {}
		for i, pos in pairs(target_nodes) do
			local check_for_non_track = table.copy(pos)
			check_for_non_track.y = check_for_non_track.y - 1
			local node = minetest.get_node_or_nil(check_for_non_track)
			if node == nil then -- Skip nil nodes
			else
				local node_def = minetest.registered_nodes[node.name]
				if node_def.groups == nil then
				elseif node_def.groups.track then
					table.insert(node_targets, table.copy(pos))
				end
			end
		end

		-- Select a node to navigate to from the known good list
		-- Prioritise the closest waypoint that's on track
		local best_pos = {}
		local best_dist
		for k, v in pairs(node_targets) do
			local dist = math.abs(solarsail.util.functions.pos_to_dist(kart_pos, v))

			if best_dist == nil or dist < best_dist then
				best_dist = dist
				best_pos = k
			end
		end
		
		--local test_pos = node_targets[best_pos] --node_targets[math.random(1, #node_targets)]
		local test_pos = node_targets[best_pos]
		local x, z = solarsail.util.functions.yaw_to_vec(kart_yaw, 1)
		local kart_forwards = vector.new(x, 0, z)

		local cross 
		if test_pos == nil then
		else
			local delta = vector.normalize(vector.subtract(test_pos, kart_pos))
			cross = vector.cross(delta, kart_forwards)
			
			--[[
				minetest.add_particle({
					pos = test_pos,
					velocity = vector.new(0, 2, 0),
					expiration_time = 3,
					size = 3,
					collisiondetection = false,
					vertical = false,
					texture = "invector_kart_shield.png",
					glow = 14
				})
			]]

			if cross.y <= -0.15 then
				controls.right = true
			elseif cross.y >= 0.15 then
				controls.left = true
			end

			if cross.y <= -0.5 then
				controls.jump = true
			elseif cross.y >= 0.5 then
				controls.jump = true
			end

			-- Manage drifting controls based on direction while drifting
			if self._is_drifting == -1 then
				if cross.y <= -0.65 then
				elseif cross.y <= -0.3 then
					controls.left = false
					controls.right = false
				elseif cross.y <= -0.15 then
					controls.left = true
					controls.right = false
				end
			elseif self._is_drifting == 1 then
				if cross.y >= 0.65 then
				elseif cross.y >= 0.3 then
					controls.left = false
					controls.right = false
				elseif cross.y >= 0.15 then
					controls.left = false
					controls.right = true
				end
			end

		end
		controls.up = true

		return cross
	end

	-- Only steer when on the ground
	if vel.y == 0 then
		cross = preferential_waypoints()
	end

	-- Figure out when the next thinking step is based on AI params
	local function thonk_timer()
		local thonk_time =
			math.random(
				self._ai_reaction_timing.min,
				self._ai_reaction_timing.max
			)
		return thonk_time / 100
	end
	thonk_timer_new = thonk_timer()

	-- Check if there are walls or objects in front or beside the kart
	-- that would block forwards trajectory, this function will override
	-- preferential_waypoints and adds a second to the thonk_timer
	local function eyesight()
		local bonus_thonk_time = 0
		local possible_coll = false

		local lookx, lookz = solarsail.util.functions.yaw_to_vec(kart_yaw, 1)
		local look_vec = vector.new(lookx, 0, lookz)
		local kart_pos_new = table.copy(kart_pos)
		kart_pos_new.y = kart_pos_new.y + 0.25
		local center_look = 
			Raycast(kart_pos_new, vector.add(kart_pos_new, vector.multiply(look_vec, 1.25)), false, false)

		local node_pos, node, node_def
		-- Search to avoid collisions
		if center_look == nil then
		else
			for pointed in center_look do
				if pointed.type == "node" then
					node_pos = table.copy(pointed.under)
					if node_pos ~= nil then
						node = minetest.get_node_or_nil(node_pos).name
						node_def = minetest.registered_nodes[node]
					end
					if node_def.walkable == nil then
						if pointed.type == "node" then
							possible_coll = true
							break
						end
					elseif node_def.walkable then
						if pointed.type == "node" then
							possible_coll = true
							break
						end
					end
				end
			end
		end

		-- Turn away from the possible collision for a short moment
		if possible_coll then
			bonus_thonk_time = math.random(50, 250) / 100
			controls.up = false
			controls.down = true
			controls.jump = false
			if cross == nil then
			else
				if cross.y > 0 then
					controls.left = false
					controls.right = true
				elseif cross.y < 0 then
					controls.right = false
					controls.left = true
				end
			end
		end

		return thonk_timer_new+bonus_thonk_time
	end
	if vel.y == 0 then
		thonk_timer_new = eyesight()
	end

	-- Always reset controls
	controls.LMB = false
	controls.RMB = false
	local function use_items()
		if self._held_item > 0 then
			if self._held_item == 1 then -- TNT
				if math.random(0, 99) > 5 then -- Use chance
					if math.random(0, 99) > 75 then -- Fire forwards or backwards
						controls.LMB = true
					else
						controls.RMB = true
					end
				end
			elseif self._held_item == 2 then -- Prox TNT
				if math.random(0, 99) > 5 then -- Use chance
					if math.random(0, 99) > 85 then -- Fire forwards or backwards
						controls.LMB = true
					else
						controls.RMB = true
					end
				end
			elseif self._held_item == 3 then -- Rocket
				if math.random(0, 99) > 5 then -- Use chance
					if math.random(0, 99) < 75 then -- Fire forwards or backwards
						controls.LMB = true
					else
						controls.RMB = true
					end
				end
			elseif self._held_item == 4 then -- Missile
				if math.random(0, 99) > 5 then -- Use chance
					if math.random(0, 99) < 85 then -- Fire forwards or backwards
						controls.LMB = true
					else
						controls.RMB = true
					end
				end
			elseif self._held_item == 5 then -- Shield
				if not self._shields then
					controls.LMB = true
				end
			elseif self._held_item == 6 then -- Ion Cannon
				if math.random(0, 99) > 5 then -- Use chance
					if math.random(0, 99) > 75 then -- Fire forwards or backwards
						controls.LMB = true
					else
						controls.RMB = true
					end
				end
			elseif self._held_item == 7 then -- Sand
				if math.random(0, 99) > 5 then -- Use chance
					if math.random(0, 99) < 75 then -- Fire forwards or backwards
						controls.LMB = true
					else
						controls.RMB = true
					end
				end
			elseif self._held_item == 8 then -- Mese Crystal
				if self._boost_timer <= 0 then
					controls.LMB = true
				end
			elseif self._held_item == 9 then -- Mese Shards
				if math.random(0, 99) > 5 then -- Use chance
					if math.random(0, 99) > 75 then -- Fire forwards or backwards
						controls.LMB = true
					else
						controls.RMB = true
					end
				end
			elseif self._held_item == 10 then -- Nanite Boosters
				if self._boost_timer <= 0 then
					controls.LMB = true
				end
			end
		end
	end
	-- Only use items when on the ground
	if vel.y == 0 then
		use_items()
	end

	-- Only apply control modulation when on the ground
	local result_controls = {}
	if vel.y == 0 then
		for k, v in pairs(controls) do
			if math.random(1,100) <= self._ai_button_press_success then
				if v then -- Quickly invert keys when the AI makes a "mistake"
					controls[k] = false
				end
			end
		end
	end

	return controls, thonk_timer_new
end
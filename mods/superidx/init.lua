superi = {}

-- Whether to save it as raw text as serialized or under binary data via zlib
superi.use_zlib_compression = false

superi.saved = {}

superi.temp = {}

-- Special 3d array to save mapblocks into - unlikely to have collisions; milage may vary
superi.array_save = {}

function superi.lesser(v1, v2)
	if v1 < v2 then return v1 end
	return v2
end

function superi.greater(v1, v2)
	if v1 < v2 then return v2 end
	return v1
end

function superi.rle(nodes)
	local ti = 1
	local tstr = ""
	local kvp = {}

	local nodes_rle = {}

	for i = 1, #nodes do
		if nodes[i] ~= nodes[i+1] then
			tstr = "{" ..nodes[i] .."," ..ti .."}"
			if #tstr > ti then
				for e = 1, ti do
					table.insert(nodes_rle, nodes[i])
				end
			else
				table.insert(nodes_rle, {nodes[i], ti})
			end
			ti = 1
		else
			ti = ti + 1
		end

	end
	return nodes_rle
end

function superi.save(minpos, maxpos, name, chunky, chunk_index)

	local nodenames = {}
	local nodes = {}
	local tempnode = {}
	local tempid = ""
	local is_nodename = false
	local size = vector.subtract(maxpos, minpos)
	local c_ids = {}

	local voxelmanip = minetest.get_voxel_manip(minpos, maxpos)
	local emin, emax = voxelmanip:read_from_map(minpos, maxpos)
	local voxelarea = VoxelArea:new{MinEdge = emin, MaxEdge = emax}

	local vm_nodes = voxelmanip:get_data()

	for loc in voxelarea:iterp(minpos, maxpos) do
		tempnode = vm_nodes[loc]
		for n = 1, #nodenames do
			is_nodename = false
			if tempnode == c_ids[n] then
				table.insert(nodes, n)
				is_nodename = true
				break
			end 
		end
		if not is_nodename then
			table.insert(nodenames, minetest.get_name_from_content_id(tempnode))
			table.insert(c_ids, tempnode)
			table.insert(nodes, #nodenames)
		end
	end

	superi.saved[name] = {size = size, nodenames = nodenames, nodes = superi.rle(nodes)}

	local chunk_mode = chunky or false
	if chunk_mode then
		if superi.array_save[chunk_index.x] == nil then
			superi.array_save[chunk_index.x] = {}
		end
		if superi.array_save[chunk_index.x][chunk_index.y] == nil then
			superi.array_save[chunk_index.x][chunk_index.y] = {}
		end
		if superi.array_save[chunk_index.x][chunk_index.y][chunk_index.z] == nil then
			superi.array_save[chunk_index.x][chunk_index.y][chunk_index.z] = superi.saved[name]
		end
	else
		minetest.mkdir(minetest.get_worldpath() .."/schems")
		local file = io.open(minetest.get_worldpath() .."/schems/" ..name ..".sdx", "w+")
		local serial_data = minetest.serialize(superi.saved[name])
		if superi.use_zlib_compression then
			file:write(minetest.compress(serial_data:gsub(" ", ""), "deflate", 9))
		else
			file:write(serial_data:gsub(" ", ""))
		end
		file:close()
	end
end

function superi.load(minpos, data)

	local i = 1
	local ti = 1
	local maxpos = vector.add(minpos, data.size)
	local c_ids = {}

	local voxelmanip = minetest.get_voxel_manip(minpos, maxpos)
	local emin, emax = voxelmanip:read_from_map(minpos, maxpos)
	local voxelarea = VoxelArea:new{MinEdge = emin, MaxEdge = emax}


	local vm_nodes = voxelmanip:get_data()

	for j = 1, #data.nodenames do
		table.insert(c_ids, minetest.get_content_id(data.nodenames[j]))
	end

	for loc in voxelarea:iterp(minpos, maxpos) do
		if data.nodenames[data.nodes[i]] then
			vm_nodes[loc] = c_ids[data.nodes[i]]
			i = i + 1
		else
			vm_nodes[loc] = c_ids[data.nodes[i][1]]
			if ti < data.nodes[i][2] then
				ti = ti + 1
			else
				i = i + 1
				ti = 1
			end
		end
	end
	voxelmanip:set_data(vm_nodes)
	voxelmanip:write_to_map(true)
end

-- quick and dirty chunking functions

--[[ superi.save_chunking(minbpos, maxbpos, name, origin_pos)
	
	The minimum number of 16^3 sections to save
	minbpos = vector(1,1,1)
	
	The maximum number of 16^3 sections to scave
	maxbpos = vector(3,3,3)
	
	The file name that gets saved to the world dir
	name = "file_name_to_out_put_as"
	
	Where the bottomleft corner for minbpos is located at, defaults to vector(0,0,0)
	if omitted
	origin_pos = vector(0,0,48)
]]--

function superi.save_chunking(minbpos, maxbpos, name, origin_pos)
	if minbpos.x < 1 or maxbpos.x < 1 then
		error("Minimum sizes of 1 or more along the x axis.")
	end

	for x=minbpos.x, maxbpos.x do
		for y=minbpos.y, maxbpos.y do
			for z=minbpos.z, maxbpos.z do
				local x_pos_in = (0+(x*16) - 16)
				local y_pos_in = (0+(y*16) - 16)
				local z_pos_in = (0+(z*16) - 16)
				local x_pos_out = (15+(x*16) - 16)
				local y_pos_out = (15+(y*16) - 16)
				local z_pos_out = (15+(z*16) - 16)
				local offset_pos = origin_pos or vector.new(0,0,0)

				local corner_inside = vector.add(offset_pos, vector.new(x_pos_in, y_pos_in, z_pos_in))
				local corner_outside = vector.add(offset_pos, vector.new(x_pos_out, y_pos_out, z_pos_out))
				superi.save(corner_inside, corner_outside, name, true, vector.new(x,y,z))
			end
		end
	end
	
	minetest.mkdir(minetest.get_worldpath() .."/schems")
	local file = io.open(minetest.get_worldpath() .."/schems/" .. name .."_chunky.sdx", "w+")
	local serial_data = minetest.serialize(superi.array_save)
	if superi.use_zlib_compression then
		file:write(minetest.compress(serial_data:gsub(" ", ""), "deflate", 9))
	else
		file:write(serial_data:gsub(" ", ""))
	end
	file:close()
end


-- This function wants superidx data in 16^3 sections as data[x][y][z]
-- Use save_chunking to generate a compatible data
-- Copy and paste the data into a .lua file for loading static worlds from memory.
-- Example, please note the [[]] to escape any strings
-- minetest.deserialize([[return {{{{["nodes"] = {{1, 160}, {2, 96}, {1, 129}, {3, 5},.....]])
function superi.load_chunking(minbpos, maxbpos, data, origin_pos)
	if minbpos.x < 1 or maxbpos.x < 1 then
		error("Minimum sizes of 1 or more along the x axis.")
	end

	for x=minbpos.x, maxbpos.x do
		for y=minbpos.y, maxbpos.y do
			for z=minbpos.z, maxbpos.z do
				local x_pos_in = (0+(x*16) - 16)
				local y_pos_in = (0+(y*16) - 16)
				local z_pos_in = (0+(z*16) - 16)
				local offset_pos = origin_pos or vector.new(0,0,0)
				local corner_inside = vector.add(offset_pos, vector.new(x_pos_in, y_pos_in, z_pos_in))
				superi.load(corner_inside, data[x][y][z])
			end
		end
	end
end

-- Commands only for testing, initial release

minetest.register_chatcommand("save", { -- Function needs to handle small amount of maths to determine min and max pos, not permanent
	privs = {server = true},
	func = function(name, param)
		if not minetest.get_player_by_name(name) then return end
		if not superi.temp[name]["1"] or not superi.temp[name]["2"] then return end
		-- you don't know how much I hate doing this but thank god it's temporary
		local newpos1 = {x = superi.lesser(superi.temp[name]["1"].x, superi.temp[name]["2"].x), y = superi.lesser(superi.temp[name]["1"].y, superi.temp[name]["2"].y), z = superi.lesser(superi.temp[name]["1"].z, superi.temp[name]["2"].z)}
		local newpos2 = {x = superi.greater(superi.temp[name]["1"].x, superi.temp[name]["2"].x), y = superi.greater(superi.temp[name]["1"].y, superi.temp[name]["2"].y), z = superi.greater(superi.temp[name]["1"].z, superi.temp[name]["2"].z)}
		superi.save(newpos1, newpos2, param)
		minetest.chat_send_player(name, "Saved as " ..param ..".sdx!")
	end
})

minetest.register_chatcommand("load", {
	privs = {server = true},
	func = function(name, param)
		if not minetest.get_player_by_name(name) or not superi.temp[name]["1"] then return end
		local file
		if superi.use_zlib_compression then
			file = minetest.deserialize(minetest.decompress(io.open(minetest.get_worldpath() .."/schems/" ..param ..".sdx", "r"):read("*a"), "deflate", 9))
		else
			minetest.deserialize(io.open(minetest.get_worldpath() .."/schems/" ..param ..".sdx", "r"):read("*a"))
		end
		superi.load(superi.temp[name]["1"], superi.saved[param] or file)
		minetest.chat_send_player(name, "Loaded " ..param ..".sdx!")
	end
})

minetest.register_chatcommand("1", {
	privs = {server = true},
	func = function(name)
		if not minetest.get_player_by_name(name) then return end

		local tpos = minetest.get_player_by_name(name):get_pos()
		superi.temp[name]["1"] = {x = math.floor(tpos.x), y = math.floor(tpos.y), z = math.floor(tpos.z)}
		minetest.chat_send_player(name, "Coordinates of 1 set to " ..dump(superi.temp[name]["1"]))
	end
})

minetest.register_chatcommand("2", {
	privs = {server = true},
	func = function(name)
		if not minetest.get_player_by_name(name) then return end
		local tpos = minetest.get_player_by_name(name):get_pos()
		superi.temp[name]["2"] = {x = math.floor(tpos.x), y = math.floor(tpos.y), z = math.floor(tpos.z)}
		minetest.chat_send_player(name, "Coordinates of 2 set to " ..dump(superi.temp[name]["2"]))
	end
})

minetest.register_on_joinplayer(function(player)
	superi.temp[player:get_player_name()] = {}
end)

minetest.register_on_leaveplayer(function(player)
	superi.temp[player:get_player_name()] = nil
end)

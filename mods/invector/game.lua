-- Invector, License MIT, Author Jordach
minetest.after(0.01, minetest.clear_objects, {mode = "full"})

invector.game = {}
-- Racers are numerically indexed as .racers[1-12]
-- with fields being generally as'
-- .racers[1] = {
--   player = player_ref,
--   pname = player:get_player_name(),
--   kart = kart_ref, should be set at race start.
--   color = "colour"
--   sector = 1/2/3... also known as laps
--   waypoint = 
--   is_ai = false, or true, depending on if they 
--                  have an AI mind and can be replaced by a player
--   ai_difficulty = 0-10, requires is_ai set.
--}

invector.racers = {}
invector.course_progress = {}
invector.host_player = false
invector.game_started = false
invector.game_starting = false
invector.current_track = "none"
invector.known_colours = {
	"aqua",
	"black",
	"blue",
	"brown",
	"green",
	"magenta",
	"mint",
	"orange",
	"red",
	"violet",
	"white",
	"yellow"
}

-- Fill out the racers
for i=1, 12 do
	invector.racers[i] =  {
		is_ai = true,
		colour = false,
		player_ref = false,
		position = -1,
		waypoint = 0,
		sector = -1,
		player_name = "CPU "..i,
		kart_ref = false,
		ai_difficulty = { -- dummy data for later
			tmin = 20,
			tmax = 21,
			frate = 50
		}
	}
end

--[[
	track_name = {
		-- Where the starting grid sits for 12th place
		-- Use invector:starting_grid_marker to set it neatly
		grid_pos_offset = vector.new(1,2,3)

		-- Track data here;
		track_data = {
			[1] = {
				[1] = {
					[1] = data
				}
			}
		}

		-- Music options
		music = "song_name"
		crescendo_music = "song_name_alt"

		-- UI/Formspec options
		track_icon_model = "model.b3d"
		track_icon_materials = {"texture.png", "texture.png"}
		track_name = "Track Name"

		-- Game settings
		track_num_laps = 3
		track_num_waypoints = 1-100
		
		-- Size of the track in 16x16x16 sections, will be force loaded by the server
		track_mapblocks_size_min = vector.new(1,1,1)
		track_mapblocks_size_max = vector.new(3,3,3)
	}
]]
invector.tracks = {}

function invector.game.register_track(track_id, track_def)
	invector.tracks[track_id] = table.copy(track_def)
end

function invector.game.get_racer_id(player_ref)
	local index = -1
	local pname = player_ref:get_player_name()
	for i=1, 12 do
		if pname == invector.racers[i].player_ref:get_player_name() then
			return i
		end
	end
end

function invector.game.shuffle_positions()
	local pos = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
	table.shuffle(pos)
	for i=1, 12 do
		invector.racers[i].position = pos[i]
	end
end

function invector.game.get_unused_colours()
	local unused = table.copy(invector.known_colours)
	-- Remove duplicates from shuffle due to player assignment
	for i=1, 12 do
		for k, v in pairs(unused) do
			if v == invector.racers[i].colour then
				table.remove(unused, k)
			end
		end
	end
	return unused
end

-- Randomly assign colours to AI and not use doubles
function invector.game.shuffle_colours()
	local unused = table.copy(invector.game.get_unused_colours())
	-- Then assign it to the CPU
	for i=1, 12 do
		local randpos = math.random(1, #unused)
		if not invector.racers[i].colour and invector.racers[i].is_ai then
			invector.racers[i].colour = unused[randpos]
			table.remove(unused, randpos)
		end
	end
end

function invector.game.set_ai_difficulty()
	local num_players = 0
	-- Scan for players first
	for i=1, 12 do
		if invector.racers[i].player_ref ~= false then
			num_players = num_players + 1
		end
	end

	-- Don't bother if there are 12 players
	if num_players == 12 then return end
	
	local ai_diff = 0 + num_players
	-- Then set AI difficulty inversely, the more players the harder it starts
	for i=0, 11 do
		if invector.racers[i+1].is_ai then
			invector.racers[i+1].ai_difficulty = table.copy(invector.ai.difficulty[ai_diff+i])
		end
	end
end

function invector.game.load_track()
	for x=invector.tracks[invector.current_track].track_mapblocks_size_min.x,
		invector.tracks[invector.current_track].track_mapblocks_size_max.x do
		for y=invector.tracks[invector.current_track].track_mapblocks_size_min.y,
			invector.tracks[invector.current_track].track_mapblocks_size_max.y do
			for z=invector.tracks[invector.current_track].track_mapblocks_size_min.z,
				invector.tracks[invector.current_track].track_mapblocks_size_max.z do

				local block_pos = vector.new(0+(x*16)-16, 0+(y*16)-16, 0+(z*16)-16)
				minetest.forceload_block(block_pos, true)
			end
		end
	end
	superi.load_chunking(
		invector.tracks[invector.current_track].track_mapblocks_size_min,
		invector.tracks[invector.current_track].track_mapblocks_size_max,
		invector.tracks[invector.current_track].track_data
	)
end

function invector.game.get_kart_grid_pos(racer_id)
	local position = invector.racers[racer_id].position
	local offset = table.copy(invector.tracks[invector.current_track].grid_pos_offset)
	offset.y = offset.y + 0.5
	-- Is odd
	if position % 2 == 1 then
		offset.x = offset.x+3
		offset.z = offset.z+1
	end

	local dist = math.floor((position/2) + 0.5)
	if dist == 1 then
		offset.z = offset.z + (4*5)
	elseif dist == 2 then
		offset.z = offset.z + (4*4)
	elseif dist == 3 then
		offset.z = offset.z + (4*3)
	elseif dist == 4 then
		offset.z = offset.z + (4*2)
	elseif dist == 5 then
		offset.z = offset.z + (4*1)
	end
	return offset
end

function invector.game.spawn_racers_into_karts()
	for i=1, 12 do
		--if i>1 then break end
		local kart_ent
		local grid_pos = table.copy(invector.game.get_kart_grid_pos(i))
		if invector.racers[i].is_ai then
			kart_ent = minetest.add_entity(grid_pos, "invector:kart")
		elseif invector.racers[i].player_ref ~= false then
			kart_ent = solarsail.player.set_model(invector.racers[i].player_ref, "invector:kart", {x=1, y=1}, 60,
			invector.karts.kart._geo, invector.karts.kart._geo3r, "",
			invector.karts.kart._prel, invector.karts.kart._prot)
			kart_ent:set_pos(grid_pos)
		else
			error("Uhhhhhhhhhhh, kart that should be either an AI or player, but is somehow neither.")
		end
		kart_ent:set_properties({
			textures = {
				invector.racers[i].colour .. "_kart_neo.png",
				invector.racers[i].colour .. "_skin.png",
				"transparent.png",
				"transparent.png"
			}
		})
		invector.racers[i].kart_ref = kart_ent
		kart_ent:set_yaw(6.283)
		kart_ent:set_acceleration(vector.new(0, -9.71, 0))
		local kart_lua = kart_ent:get_luaentity()
		kart_lua._is_ai = invector.racers[i].is_ai
		kart_lua._position = invector.racers[i].position
		kart_lua._racer_id = i
		kart_lua._ai_reaction_timing.min = invector.racers[i].ai_difficulty.tmin
		kart_lua._ai_reaction_timing.max = invector.racers[i].ai_difficulty.tmax
		kart_lua._ai_button_press_success = invector.racers[i].ai_difficulty.frate
	end
end

function invector.game.recursive_timer(time)
	if time > 0 then
		for k, player in pairs(minetest.get_connected_players()) do
			minetest.sound_play("count_"..time, {to_player=player:get_player_name(), gain=0.8})
		end
		minetest.after(2, invector.game.recursive_timer, time-1)
	else
		for k, player in pairs(minetest.get_connected_players()) do
			minetest.sound_play("count_go", {to_player=player:get_player_name(), gain=0.8})
		end
		invector.game_started = true
	end
end

function invector.game.prepare_game()
	invector.game_starting = true
	-- Load world map based on paramaters
	invector.game.load_track()
	-- set AI difficulty
	invector.game.set_ai_difficulty()
	-- shuffle AI kart colours
	invector.game.shuffle_colours()
	-- shuffle kart positions
	invector.game.shuffle_positions()
	-- start karts proper
	invector.game.spawn_racers_into_karts()
	-- start the countdown
	invector.game.recursive_timer(3)
end

function invector.game.fade_music(player_ref)
	local pname = player_ref:get_player_name()
	if invector.music[pname].sound_ref ~= false then
		minetest.sound_fade(invector.music[pname].sound_ref, 0.325, 0)
	end
end

function invector.game.play_music(player_ref, song_name)
	local pname = player_ref:get_player_name()
	invector.music[pname].sound_ref =
		minetest.sound_play(song_name, {to_player=pname, loop=true, gain=0.65})
end

invector.music = {}
-- Music engine handler only available in regular gameplay.
if not minetest.settings:get_bool("creative_mode") then
	minetest.register_globalstep(function(dtime)
		for _, player in ipairs(minetest.get_connected_players()) do
			local racer_id = invector.game.get_racer_id(player)
			local pname = player:get_player_name()
			if not invector.game_starting then
				if invector.music[pname].sound_name ~= "coffee_break" then
					invector.music[pname].sound_name = "coffee_break"
					-- Only needed for game startup
					if invector.music[pname].sound_ref ~= false then
						invector.game.fade_music(player)
						minetest.after(2, invector.game.play_music, player, "funk_of_the_coffee_break")
					else
						invector.game.play_music(player, "funk_of_the_coffee_break")
					end
				end
			else
				if invector.racers[racer_id].sector == 3 then
					if invector.music[pname].sound_name ~= invector.tracks[invector.current_track].crescendo_music then
						invector.music[pname].sound_name = invector.tracks[invector.current_track].crescendo_music
						invector.game.fade_music(player)
						invector.game.play_music(player, invector.tracks[invector.current_track].crescendo_music)
					end
				elseif invector.racers[racer_id].sector < 3 then
					if invector.music[pname].sound_name ~= invector.tracks[invector.current_track].music then
						invector.music[pname].sound_name = invector.tracks[invector.current_track].music
						invector.game.fade_music(player)
						invector.game.play_music(player, invector.tracks[invector.current_track].music)
					end
				end
			end
		end
	end)
end

local function invector_formspec_colour_selection_formspec(player)
	local formspec = "size[18,9]formspec_version[3]"
	local colours

	if player == invector.host_player then
		colours = table.copy(invector.known_colours)
	else
		colours = invector.game.get_unused_colours()
	end

	local x=0
	local y=0.5

	formspec = formspec .. "image[0,-0.5;4,2;invector_title.png]"
	formspec = formspec .. "image[3.15,-0.15;3,1.5;invector_kart_select.png]"
	for k, colour in pairs(colours) do
		formspec = formspec .. "model["..x..","..(y)..";3,3;"..
			colour.."_kart;default_kart.b3d;"..
			colour.."_kart_neo.png,"..
			colour.."_skin.png,transparent.png,transparent.png;-15,180;true;false;{0,0}]"

		formspec = formspec .. "button["..x..","..(y+3)..
			";3,1;"..
			"button_"..colour..
			";"..string.upper(colour:sub(1,1))..string.sub(colour, 2, string.len(colour)) .. "]"
		x = x + 3
		if x == 18 then
			x = 0
			y = y + 4.5
		end
	end

	return formspec
end

local function invector_formspec_track_selection_formspec(player_ref)
	if player_ref ~= invector.host_player then return "" end

	local formspec = "size[16,8]formspec_version[3]"
	formspec = formspec .. "image[0,-0.5;4,2;invector_title.png]"
	formspec = formspec .. "image[3.15,-0.15;3,1.5;invector_track_select.png]"
	
	local x = 0
	local y = 1
	for track_id, track_data in pairs(invector.tracks) do
		formspec = formspec .. "model["..x..","..(y)..";2,2;"..
		track_data.track_button..";"..
		track_data.track_icon_model..";"..
		track_data.track_icon_materials..";"..
		track_data.track_icon_rotation..";"..
		"true;false;"..track_data.track_icon_animation.."]"

		formspec = formspec .. "button["..x..","..(y+2)..";2,1;"..
		track_data.track_button..";"..
		track_data.track_name.."]"

		x = x + 2
		if x == 16 then
			x = 0
			y = y + 3
		end
	end

	return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()
	local racer_id = invector.game.get_racer_id(player)
	if formname == "invector_colour_picker" then
		if fields.quit then
			minetest.after(0.01, minetest.show_formspec, pname, formname, invector_formspec_colour_selection_formspec(player))
		else
			for k, colour in pairs(fields) do
				invector.racers[racer_id].colour = colour:lower()
			end

			if invector.host_player == player then
				minetest.show_formspec(pname, "invector_track_selection", invector_formspec_track_selection_formspec(player))
			else
				minetest.show_formspec(pname, "exit", "")
			end
		end
	end

	if formname == "invector_track_selection" then
		if fields.quit then
			minetest.after(0.01, minetest.show_formspec, pname, formname, invector_formspec_track_selection_formspec(player))
		else
			-- Attempt to find a match between button and track data ID
			for key, value in pairs(fields) do
				for track_name, track_data in pairs(invector.tracks) do
					if key == track_name then
						invector.current_track = key
						break
					end
				end
			end
			-- MASIVE TODO FIX FOR MULTIPLAYER
			minetest.close_formspec(pname, formname)
			invector.game.prepare_game()
		end
	end
end)

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	-- Set the host as the first player to join; future releases will be automated
	if not invector.host_player then
		invector.host_player = player
	else
		minetest.kick_player(player_name, "Invector cannot support more than one client at the moment.")
	end
	invector.music[player_name] = {sound_ref=false, sound_name="notplaying"}
	player:set_properties({
		textures = {"transparent.png", "transparent.png"},
		pointable = false,
		collisionbox = {-0.01, -0.01, -0.01, 0.01, 0.01, 0.01}
	})

	player:set_nametag_attributes({
		color = "#00000000"
	})

	for i=1, 12 do
		if invector.racers[i].is_ai then
			invector.racers[i].is_ai = false
			invector.racers[i].player_ref = player
			invector.racers[i].player_name = string.gsub(player_name, "_", " ")
			-- Stop at the first entry.
			break
		elseif i == 12 and invector.racers[i].is_ai == true then
			-- Disconnect the player if there's no room;
			minetest.kick_player(player_name, "This server cannot fit more than 12 players.")
		end
	end

	if not minetest.settings:get_bool("creative_mode") then
		minetest.show_formspec(player_name, "invector_colour_picker", invector_formspec_colour_selection_formspec(player))
	end
end)

minetest.register_on_leaveplayer(function(player)
	local lname = player:get_player_name()
	if invector.host_player == player then
		-- Next player becomes the host.
		for i=1, 12 do
			if not invector.racers[i].is_ai and lname ~= invector.racers[i].player_name then
				invector.host_player = invector.racers[i].player_ref
				break
			end
		end
		-- Remove the player from the known racers;
		for i=1, 12 do
			if lname == invector.racers[i].player_ref:get_player_name() then
				invector.racers[i].is_ai = true
				invector.racers[i].player_ref = false
				invector.racers[i].player_name = "CPU " .. i
				break
			end
		end
	end
end)

-- Special creative mode commands

minetest.register_chatcommand("jukebox", {
	description = "Play a looped version of any sound.",
	func = function(name, param)
		if minetest.settings:get_bool("creative_mode") then
			minetest.sound_play(param, {to_player=name, loop=true, gain=0.65})
		end
	end
})

minetest.register_chatcommand("save_chunks", {
	description = "Save track to disk, 1,1,1 = starting mapblocks, 3,3,3 ending mapblocks, 0,0,0 = offset in blocks, filename",
	func = function(name, param)
		if minetest.settings:get_bool("creative_mode") then
			local pos = string.split(param, ",")
			if #pos > 10 then
				error("Too many arguments used")
			end

			local start_pos = vector.new(tonumber(pos[1]), tonumber(pos[2]), tonumber(pos[3]))
			local   end_pos = vector.new(tonumber(pos[4]), tonumber(pos[5]), tonumber(pos[6]))
			local offset_pos = vector.new(tonumber(pos[7]), tonumber(pos[8]), tonumber(pos[9]))
			local filename = pos[10]
			superi.save_chunking(start_pos, end_pos, filename, offset_pos)
		end
	end
})

minetest.register_chatcommand("load_chunks", {
	description = "Load track from Lua data",
	func = function(name, param)
		if minetest.settings:get_bool("creative_mode") then
			local pos = string.split(param, ",")
			if #pos > 1 then
				error("Too many arguments used")
			end
			local track_name = pos[1]
			superi.load_chunking(
				invector.tracks[track_name].track_mapblocks_size_min,
				invector.tracks[track_name].track_mapblocks_size_max,
				invector.tracks[track_name].track_data
			)
			invector.game_started = true
		end
	end
})

minetest.register_chatcommand("fake_race_start", {
	description = "Fakes a race for creative mode",
	func = function(name, param)
		if minetest.settings:get_bool("creative_mode") then
			local player = minetest.get_player_by_name(name)
			local racer_id = invector.game.get_racer_id(player)
			invector.racers[racer_id].colour = invector.known_colours[math.random(1, #invector.known_colours)]
			invector.current_track = param
			-- set AI difficulty
			invector.game.set_ai_difficulty()
			-- shuffle AI kart colours
			invector.game.shuffle_colours()
			-- shuffle kart positions
			invector.game.shuffle_positions()
			-- Nerf the AI bot for testing
			invector.racers[2].ai_difficulty = table.copy(invector.ai.difficulty[12])
		end
	end
})

minetest.register_chatcommand("test_kart", {
	description = "Spawn a kart in creative mode only.",
	func = function(name)
		if minetest.settings:get_bool("creative_mode") then
			local player = minetest.get_player_by_name(name)
			local racer_id = invector.game.get_racer_id(player)
			local ent = solarsail.player.set_model(player, "invector:kart", {x=1, y=1}, 60,
			invector.karts.kart._geo, invector.karts.kart._geo3r, "",
			invector.karts.kart._prel, invector.karts.kart._prot)
			local col = invector.known_colours[math.random(1, #invector.known_colours)]
			ent:set_properties({
				textures = {
					col .. "_kart_neo.png",
					col .. "_skin.png",
					"transparent.png",
					"transparent.png"
				}
			})
			ent:set_yaw(player:get_look_horizontal())
			ent:set_acceleration(vector.new(0, -9.71, 0))
			invector.racers[racer_id].kart_ref = ent
			local kart_lua = ent:get_luaentity()
			kart_lua._is_ai = invector.racers[racer_id].is_ai
			kart_lua._position = invector.racers[racer_id].position
			kart_lua._racer_id = racer_id
			kart_lua._ai_reaction_timing.min = invector.racers[racer_id].ai_difficulty.tmin
			kart_lua._ai_reaction_timing.max = invector.racers[racer_id].ai_difficulty.tmax
			kart_lua._ai_button_press_success = invector.racers[racer_id].ai_difficulty.frate
		end
	end,
})

minetest.register_chatcommand("place_node", {
	description = "places a flat 16x1x16 at 0, 8, 0",
	func = function(name)
		if minetest.settings:get_bool("creative_mode") then
			for x=0,15 do
				for z=0,15 do
					minetest.set_node(vector.new(x, 8, z), {name="solarsail:wireframe"})
				end
			end
		end
	end,
})
-- SolarSail Engine Skybox Handler:
-- Author: Jordach
-- License: Reserved

-- Pre-Init:

solarsail.skybox.is_paused = false

solarsail.skybox.regions = {}
solarsail.skybox.regions.pos_1 = {}
solarsail.skybox.regions.pos_2 = {}
solarsail.skybox.regions.skybox = {}

solarsail.skybox.skybox_defs = {}
solarsail.skybox.cloud_defs = {}

--[[ solarsail.skybox.register_skybox(skybox_name, skybox_defs, cloud_defs, pos_1, pos_2)

API spec for registering clouds based on position:

skybox_defs table:
	skybox_defs.textures = {1, 2, 3, 4, 5, 6}
	skybox_defs.type = "regular", "bgcolor", "skybox"
	skybox_defs.bgcolor = "#rrggbb"
	skybox_defs.clouds = true, false

cloud_defs table:
	cloud_defs.density: 0 to 1
	cloud_defs.color: "#rrggbbaa"
	cloud_defs.ambient: "#rrggbb"
	cloud_defs.height: -31000 to 31000
	cloud_defs.thickness: 0.01 to 31000
	cloud_defs.x = -128 to 128
	cloud_defs.y = -128 to 128

position_1 = {x =  1, y = 0, z = 0}
position_2 = {x = -1, y = 1, z = 10}

Note: Preferrably as game_skyboxname or mod_skyboxname
]]--

function solarsail.skybox.register_skybox(skybox_name, skybox_defs, cloud_defs, pos_1, pos_2)
	solarsail.skybox.skybox_defs[skybox_name] = skybox_defs
	solarsail.skybox.cloud_defs[skybox_name] = cloud_defs
	solarsail.skybox.regions.pos_1[skybox_name] = pos_1
	solarsail.skybox.regions.pos_2[skybox_name] = pos_2
	solarsail.skybox.regions.skybox[skybox_name] = skybox_name
end

--[[ solarsail.skybox.override_skybox(skybox_defs, cloud_defs, player)

API spec for temporarily overriding skyboxes:

skybox_defs table:
	skybox_defs.textures = {"1", "2", "3", "4", "5", "6"}
	skybox_defs.type = "regular", "bgcolor", "skybox"
	skybox_defs.bgcolor = "#rrggbb"s
	skybox_defs.clouds = true, false

cloud_defs table:
	cloud_defs.density: 0 to 1
	cloud_defs.color: "#rrggbbaa"
	cloud_defs.ambient: "#rrggbb"
	cloud_defs.height: -31000 to 31000
	cloud_defs.thickness: 0.01 to 31000
	cloud_defs.x = -128 to 128
	cloud_defs.y = -128 to 128

player is a PlayerRef created by the Minetest Engine.
]]--

function solarsail.skybox.override_skybox(skybox_defs, cloud_defs, player)
	solarsail.skybox.is_paused = true
	player:set_sky(
		skybox_defs.bgcolor,
		skybox_defs.type,
		skybox_defs.textures,
		skybox_defs.clouds
	)
	player:set_clouds({
		density = cloud_defs.density,
		color = cloud_defs.color,
		ambient = cloud_defs.ambient,
		height = cloud_defs.height,
		thickness = cloud_defs.thickness,
		speed = {x = cloud_defs.x, cloud_defs.y}
	})
end


--[[ solarsail.skybox.restore_skybox()
	Resume paused skybox functionality from overrides
]]--

function solarsail.skybox.restore_skybox()
	solarsail.skybox.is_paused = false
	solarsail_render_sky()
end

-- Simplified inbetween check:

local function inbetween(lower, upper, val)
	if val >= lower and val <= upper then
		return true
	else 
		return false
	end
end

-- Compare skybox settings against the new ones:

local function compare_sky(skybox_defs, one, two, three)
	-- Compare bgcolor to supplied bgcolor:
	local bgcolor = minetest.rgba(one.r, one.g, one.b)
	if bgcolor ~= skybox_defs.bgcolor then return true end

	-- Compare skybox types:
	if two ~= skybox_defs.type then return true end
	
	-- If we happen to be now using "skybox" do so here - otherwise we ignore it and flag it as changed
	if skybox_defs.type == "skybox" and three == "skybox" then
		for k, v in pairs(three) do
			if v ~= skybox_defs.textures[k] then
				return true
			end
		end
	end

	return false -- if somehow we get here by mistake
end

-- Compare cloud settings against the new ones:

local function compare_clouds(cloud_defs, player_clouds) -- Speed of clouds aren't changed as they're considered a changing value, eg wind
	-- Compare cloud densities:
	if cloud_defs.density ~= player_clouds.density then return true end

	-- Compare base color:
	if cloud_defs.color ~= minetest.rgba(
		player_clouds.color.r,
		player_clouds.color.g,
		player_clouds.color.b,
		player_clouds.color.a
	) then return true end

	-- Compare "ambiance colour"
	if cloud_defs.ambient ~= minetest.rgba(
		player_clouds.ambient.r,
		player_clouds.ambient.g,
		player_clouds.ambient.b,
		player_clouds.ambient.a
	) then return true end

	-- Compare height
	if cloud_defs.height ~= player_clouds.height then return true end

	-- Compare thiccness
	if cloud_defs.thickness ~= player_clouds.thickness then return true end

	return false -- if somehow none of these values are considered changed
end

-- Change skybox for "connected players here":

local function solarsail_render_sky()
	if solarsail.skybox.is_paused then
	else
		for _, player in ipairs(minetest.get_connected_players()) do
			local ppos = player:get_pos()
			local isx, isy, isz = false
			-- Iterate over a table full of names
			for k, v in pairs(solarsail.skybox.regions.skybox) do
				if inbetween(solarsail.skybox.regions.pos_1[v].x, solarsail.skybox.regions.pos_2[v].x, ppos.x) then
					isx = true
				end
				if inbetween(solarsail.skybox.regions.pos_1[v].y, solarsail.skybox.regions.pos_2[v].y, ppos.y) then
					isy = true
				end
				if inbetween(solarsail.skybox.regions.pos_1[v].z, solarsail.skybox.regions.pos_2[v].z, ppos.z) then
					isz = true
				end
				if isx and isy and isz then
					local sky_1, sky_2, sky_3 = player:get_sky()
					if compare_sky(solarsail.skybox.skybox_defs[v], sky_1, sky_2, sky_3) then
						player:set_sky(
							solarsail.skybox.skybox_defs[v].bgcolor,
							solarsail.skybox.skybox_defs[v].type,
							solarsail.skybox.skybox_defs[v].textures,
							solarsail.skybox.skybox_defs[v].clouds
						)
					end
					if compare_clouds(solarsail.skybox.cloud_defs[v], player:get_clouds()) then
						player:set_clouds({
							density = solarsail.skybox.cloud_defs[v].density,
							color = solarsail.skybox.cloud_defs[v].color,
							ambient = solarsail.skybox.cloud_defs[v].ambient,
							height = solarsail.skybox.cloud_defs[v].height,
							thickness = solarsail.skybox.cloud_defs[v].thickness,
							speed = {x = solarsail.skybox.cloud_defs[v].x, solarsail.skybox.cloud_defs[v].y}
						})
					end
					break
				else
					isx, isy, isz = false
				end
			end
		end
		minetest.after(0.1, solarsail_render_sky)
	end
end

local player_count = 0
--[[
	minetest.register_on_joinplayer(function(player)
		-- magic values to make comparisons work, as MT does not provide defaults
		player:set_sky("#ffffff", "regular", {"eror.png"}, true)
		solarsail_render_sky()
	
		-- Prevent player handling freaking out; but this may change in future
		player_count = player_count + 1
		if player_count > 1 then
			--minetest.kick_player(player:get_player_name(), "[SolarSail]: Singleplayer only, multiplayer disallowed.")
		end
	end)
	
	minetest.register_on_leaveplayer(function(player)
		player_count = player_count - 1
	end)
	
	solarsail.skybox.register_skybox("default",
		{
			-- ["top"] = "#676891", ["bottom"] = "#c79161", ["base"] = "#a17268", ["light"] = 0.15} sunrise = #ffae5f horizon = #404164
			bgcolor = "#a17268",
			type = "regular",
			clouds = true
		},
		{
			density = 0.34
		},
		{
			x = -31000,
			y = -31000,
			z = -31000
		},
		{
			x = 31000,
			y = 31000,
			z = 31000
		}
	)
]]

local day_sky = "#c5b7ea"
local day_horizon = "#f0ecff"
local dawn_sky = "#bf9bb4"
local dawn_horizon = "#dec6d7"
local night_sky = "#030015"
local night_horizon = "#100033"
local sun_tint = "#dbbae7"
local moon_tint = "#d37dff"

local cloud_color = "#f3eaf8e7"
local star_color = "#c0c7ffaa"

minetest.register_on_joinplayer(function(player)
	player:set_sky({
		type = "regular",
		clouds = true,
		sky_color = {
			day_sky = day_sky,
			day_horizon = day_horizon,
			dawn_sky = dawn_sky,
			dawn_horizon = dawn_horizon,
			night_sky = night_sky,
			night_horizon = night_horizon,
			fog_sun_tint = sun_tint,
			fog_moon_tint = moon_tint,
			fog_tint_type = "custom"
		}
	})

	player:set_clouds({
		color = cloud_color
	})

	player:set_stars({
		count = 2000,
		star_color = star_color,
		scale = 0.65
	})
end)
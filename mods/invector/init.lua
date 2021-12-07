-- Invector, License MIT, Author Jordach

-- Disable the hand if in survival mode or play game mode, while
-- creative mode acts as the built in track editor
if not minetest.settings:get_bool("creative_mode") then
	minetest.override_item("", {
		wield_scale = {x=1,y=1,z=1},
		range = 1,
		tool_capabilities = {
			full_punch_interval = 1,
			max_drop_level = 0,
			groupcaps = {},
			damage_groups = {},
		}
	})
else
	minetest.override_item("", {
		wield_scale = {x=1,y=1,z=1},
		range = 5,
		tool_capabilities = {
			full_punch_interval = 1,
			max_drop_level = 0,
			groupcaps = {
				debug = {times={[1]=1,[2]=0.5,[3]=0.25}, uses=0},
				invector = {times={[1]=1,[2]=0.5,[3]=0.25}, uses=0},
			},
			damage_groups = {},
		}
	})
end

invector = {}
invector.functions = {}
-- Racers are numerically indexed as .racers[1-12]
-- with fields being generally as'
-- .racers[1] = {
--   player = player_ref,
--   pname = player:get_player_name(),
--   kart = kart_ref, should be set at race start.
--   is_ai = false, or true, depending on if they 
--                  have an AI mind and can be replaced by a player
--   ai_difficulty = 0-10, requires is_ai set.
--}
invector.racers = {}

invector.path = minetest.get_modpath("invector")

local function exec(file)
	dofile(invector.path.."/"..file..".lua")
end

exec("blocks")
exec("kart")
exec("karts/sam2")
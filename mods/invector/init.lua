-- Invector, License MIT, Author Jordach

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

invector = {}
invector.functions = {}

invector.path = minetest.get_modpath("invector")

local function exec(file)
	dofile(invector.path.."/"..file..".lua")
end

exec("kart")
exec("karts/sam2")

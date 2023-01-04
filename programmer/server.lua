--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	VM16 File Server
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end
local prog = vm16.prog

local function split_filename(s)
	local _, _, name, ext = string.find(s, "(.+)%.(.*)")
	name = name or s
	ext = ext or ""
	local _, _, path, base = string.find(name, "(.-)/(.+)")
	path = path or ""
	base = base or name
	return path, base, ext
end

local function order(a, b)
	local path1, name1, ext1 = split_filename(a.name)
	local path2, name2, ext2 = split_filename(b.name)
	
	if path1 ~= path2 then
		return path1 < path2
	elseif a.attr ~= b.attr then
		return a.attr > b.attr
	elseif ext1 ~= ext2 then
		return ext1 < ext2
	end
	return name1 < name2
end

local ReadOnlyFiles = {}   -- [cpu_type][file_name] = text

local function get_ro_files(pos)
	local cpu_type = M(pos):get_string("cpu_type")
	return ReadOnlyFiles[cpu_type] or {}
end

local function get_filelist(pos)
	local meta = M(pos)
	local cpu_type = meta:get_string("cpu_type")
	local s = meta:get_string("files")
	local files = minetest.deserialize(s) or {}
	local out = {}
	local ro_files = get_ro_files(pos)
	for name, text in pairs(ro_files) do
		out[#out + 1] = {name = name, attr = "ro"}
	end
	for name, text in pairs(files) do
		if not ro_files[name] then
			out[#out + 1] = {name = name, attr = "rw"}
		end
	end
	table.sort(out, order)
	return out
end

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------
vm16.server = {}

function vm16.server.init(pos, cpu_type)
	M(pos):set_string("cpu_type", cpu_type)
	local name = minetest.get_node(pos).name
	if name == "vm16:server" or name == "vm16:server2" then
		local mem = prog.get_mem(pos)
		mem.filelist = get_filelist(pos)
	end
end

function vm16.server.get_filelist(pos)
	local name = minetest.get_node(pos).name
	if name == "vm16:server" or name == "vm16:server2" then
		local mem = prog.get_mem(pos)
		mem.filelist = mem.filelist or get_filelist(pos)
		return mem.filelist
	end
	return {}
end

function vm16.server.read_file(pos, filename)
	local name = minetest.get_node(pos).name
	if name == "vm16:server" or name == "vm16:server2" then
		local ro_files = get_ro_files(pos)
		if ro_files[filename] then
			return ro_files[filename]
		end
		local s = M(pos):get_string("files")
		local files = minetest.deserialize(s) or {}
		return files[filename] or ""
	end
	return ""
end

function vm16.server.write_file(pos, filename, text)
	local name = minetest.get_node(pos).name
	if name == "vm16:server" or name == "vm16:server2" then
		local mem = prog.get_mem(pos)
		local ro_files = get_ro_files(pos)
		if not ro_files[filename] then
			local s = M(pos):get_string("files")
			local files = minetest.deserialize(s) or {}
			if text ~= "" then
				files[filename] = text
			else
				files[filename] = nil
			end
			s = minetest.serialize(files)
			M(pos):set_string("files", s)
			mem.filelist = get_filelist(pos)
		end
	end
end

function vm16.server.rename_file(pos, files, old_name, new_name)
	local name = minetest.get_node(pos).name
	if name == "vm16:server" or name == "vm16:server2" then
		local mem = prog.get_mem(pos)
		local ro_files = get_ro_files(pos)
		if not ro_files[new_name] then
			local s = M(pos):get_string("files")
			local files = minetest.deserialize(s) or {}
			files[new_name] = files[old_name]
			files[old_name] = nil
			s = minetest.serialize(files)
			M(pos):set_string("files", s)
			mem.filelist = get_filelist(pos)
		end
	end
end

function vm16.server.register_ro_file(cpu_type, filename, text)
	ReadOnlyFiles[cpu_type] = ReadOnlyFiles[cpu_type] or {}
	ReadOnlyFiles[cpu_type][filename] = text
end

function vm16.server.is_ro_file(pos, filename)
	local ro_files = get_ro_files(pos)
	return ro_files[filename] ~= nil
end

local function after_place_node(pos, placer, itemstack, pointed_thing)
	local meta = M(pos)
	meta:set_string("owner", placer:get_player_name())
	meta:set_string("formspec", "formspec_version[4]size[6,3]button[0.8,0.8;4.4,1.4;destroy;Destroy Server\n  with all files?]")
	meta:set_string("files", minetest.serialize({}))
	meta:mark_as_private("files")
	meta:set_string("infotext", placer:get_player_name() .. "'s VM16 File Server")
end

local function on_receive_fields(pos, formname, fields, player)
	if player and player:get_player_name() == M(pos):get_string("owner") then
		if fields.destroy then
			local node = minetest.get_node(pos)
			minetest.remove_node(pos)
			minetest.add_item(pos, node)
			prog.del_mem(pos)
			M(pos):from_table(nil)
		end
	end
end

minetest.register_node("vm16:server", {
	description = "VM16 File Server",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -4/16, -8/16, -6/16, 4/16, 2/16, 6/16},
		},
	},
	tiles = {
		-- up, down, right, left, back, front
		"vm16_server_top.png",
		"vm16_server_top.png",
		"vm16_server_side.png^vm16_logo.png",
		"vm16_server_side.png^vm16_logo.png",
		"vm16_server_back.png",
		"vm16_server_front.png",
	},
	after_place_node = after_place_node,
	on_receive_fields = on_receive_fields,
	paramtype2 = "facedir",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 5,
	glow = 12,
	use_texture_alpha = "clip",
	is_ground_content = false,
	on_blast = function() end,
	on_destruct = function () end,
	can_dig = function() return false end,
	diggable = false,
	drop = "",
	stack_max = 1,
	groups = {cracky=2, crumbly=2, choppy=2},
})

minetest.register_node("vm16:server2", {
	description = "VM16 File Server",
	tiles = {
		-- up, down, right, left, back, front
		"vm16_programmer2_top.png",
		"vm16_programmer2_top.png",
		"vm16_programmer2_side.png",
		"vm16_programmer2_side.png",
		"vm16_server2_back.png",
		"vm16_server2_front.png",
	},
	after_place_node = after_place_node,
	on_receive_fields = on_receive_fields,
	paramtype2 = "facedir",
	is_ground_content = false,
	on_blast = function() end,
	on_destruct = function () end,
	can_dig = function() return false end,
	diggable = false,
	drop = "",
	stack_max = 1,
	groups = {cracky=2, crumbly=2, choppy=2},
})

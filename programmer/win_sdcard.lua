--[[
	vm16
	====

	Copyright (C) 2019-2023 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Programmer SD Cardl window
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = minetest.string_to_pos

vm16.sdcard = {}
local term = vm16.term
local prog = vm16.prog

local WIN_SIZE = "0.2,0.6;11.4, 9.6"

function vm16.sdcard.init(pos, mem)
end

function vm16.sdcard.formspec(pos, mem, textsize)
--	vm16.menubar.add_separator()
	if not mem.card_mounted then
		vm16.menubar.add_button("back", "Back")
		vm16.menubar.add_button("mount", "Mount")
		return "box[" .. WIN_SIZE .. ";#145]" ..
			"list[context;vm16_sdcard;5.5,2;1,1;]" ..
			"list[current_player;main;1,5;8,4;]" ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	elseif mem.card_edited then
		local descr = mem.sdcard_descr or ""
		vm16.menubar.add_button("cancel", "Cancel")
		vm16.menubar.add_button("save", "Save")
		return "box[" .. WIN_SIZE .. ";#145]" ..
			"box[5.5,2;1,1;#222]" ..
			"item_image[5.5,2;1,1;vm16:sdcard]" ..
			"textarea[3,3.5;6,1.2;descr;Description:;" .. descr .. "]" ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	else
		vm16.menubar.add_button("back", "Back")
		vm16.menubar.add_button("unmount", "Unmount")
		vm16.menubar.add_button("edit", "Edit")
		return "box[" .. WIN_SIZE .. ";#145]" ..
			"box[5.5,2;1,1;#222]" ..
			"item_image[5.5,2;1,1;vm16:sdcard]" ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	end
end

function vm16.sdcard.on_receive_fields(pos, fields, mem)
	if fields.mount then
		mem.sdcard_descr, mem.sdcard_text = vm16.sdcard.get_data(pos, "vm16_sdcard", 1)
		if mem.sdcard_descr then
			mem.card_mounted = true
			mem.card_edited = false
			vm16.files.create_file(mem, "mnt/sdcard", mem.sdcard_text)
		end
	elseif fields.unmount then
		mem.card_mounted = false
		mem.card_edited = nil
		local text = vm16.files.read_file(mem, "mnt/sdcard")
		vm16.sdcard.set_data(pos, "vm16_sdcard", 1, nil, text or "")
		vm16.files.remove_file(mem, "mnt/sdcard")
	elseif fields.edit then
		mem.card_edited = true
		mem.sdcard_descr, mem.sdcard_text = vm16.sdcard.get_data(pos, "vm16_sdcard", 1)
	elseif fields.cancel then
		mem.card_edited = nil
	elseif fields.save then
		mem.card_edited = nil
		vm16.sdcard.set_data(pos, "vm16_sdcard", 1, fields.descr)
	elseif fields.back then
		mem.sdcard_active = nil
		mem.card_edited = nil
	end
	vm16.files.on_receive_fields(pos, fields, mem)
end

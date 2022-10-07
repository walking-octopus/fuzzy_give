-- Licensed under GNU LGPLv2.1.

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
fzy = dofile(modpath .. '/lib/fzy_lua.lua')

-- Search funtions

-- Fuzzy search minetest.registered_items and return a list of result tables or error
function search_items_list(query)
	if query == "" then return false end

	local item_names = {}
	for name, _ in pairs(minetest.registered_items) do
		table.insert(item_names, name)
	end

	local matches = fzy.filter(query, item_names, false)
	if next(matches) == nil then return false end

	return matches, item_names
end

-- Fuzzy search minetest.registered_items and return the best match string or error
function search_one_item(query)
	if query == "" then return false end

	local item_names = {}
	for name, _ in pairs(minetest.registered_items) do
		table.insert(item_names, name)
	end

	local matches = fzy.filter(query, item_names, false)
	if next(matches) == nil then return false end

	table.sort(matches, function(a, b) return a[3] > b[3] end)
	local best_match = matches[1]

	return item_names[best_match[1]]
end

-- A funtion to handle the give commands
-- A modified version of MineClone 2 give command

local function handle_give_command(_, giver, receiver, query, amount)
	local match = search_one_item(query)

	if match == false then
		return false
	end

	if amount == "" then
		amount = 1
	end

	local itemstack = ItemStack(match .. " " .. amount)
	if itemstack:is_empty() then
		minetest.chat_send_player(giver, 'error: cannot give an empty item')
		return
	elseif not itemstack:is_known() then
		minetest.chat_send_player(giver, 'error: cannot give an unknown item')
		return
	end

	local receiverref = minetest.env:get_player_by_name(receiver)
	if receiverref == nil then
		minetest.chat_send_player(giver, receiver .. ' is not a known player')
		return
	end

	local leftover = receiverref:get_inventory():add_item("main", itemstack)

	if leftover:is_empty() then
		partiality = ""
	elseif leftover:get_count() == itemstack:get_count() then
		partiality = "could not be "
	else
		partiality = "partially "
	end

	-- The actual item stack string may be different from what the "giver"
	-- entered (e.g. big numbers are always interpreted as 2^16-1).
	stackstring = itemstack:to_string()

	if giver == receiver then
		minetest.chat_send_player(giver, '"' .. stackstring
			.. '" ' .. partiality .. 'added to inventory.');
	else
		minetest.chat_send_player(giver, '"' .. stackstring
			.. '" ' .. partiality .. 'added to ' .. receiver .. '\'s inventory.');
		minetest.chat_send_player(receiver, '"' .. stackstring
			.. '" ' .. partiality .. 'added to inventory.');
	end
end

-- Register all the commands

-- Register `/search`
minetest.register_chatcommand("search", {
	params = "<name> <query>",
	description = "Fuzzy search loaded items",
	privs = { interact = true }, -- Require the "privs" privilege to run

	func = function(_, query)
		local matches, item_names = search_items_list(query)
		if matches == false or item_names == nil then
			return false, "No results found for \"" .. query .. '"'
		end

		minetest.chat_send_all("\nResults for \"" .. query .. "\": ")

		for key, match in pairs(matches) do
			if not match[3] < 2 then
				minetest.chat_send_all(" - " .. key .. ". (score: " .. match[3] .. ") " .. item_names[match[1]])
			end
		end

		return true
	end
})

-- Register `/give`
minetest.register_chatcommand("give", {
	params = "<name> <query> <amount>",
	description = "search and give the item to a player",
	privs = { give = true },
	func = function(name, param)
		local toname, query, amount = string.match(param, "^([^ ]+) +(.+) (%d*)$")
		if not toname or not query then
			return false
		end

		if handle_give_command("/give", name, toname, query, amount) == false then
			return false, "No results found for \"" .. query .. '"'
		end
	end,
})

-- Register `/giveme`
minetest.register_chatcommand("giveme", {
	params = "<query> <amount>",
	description = "search and give an item to yourself",
	privs = { give = true },
	func = function(name, param)
		local query, amount = string.match(param, "^([^ ]+) (%d+)")
		-- TODO: Figure out how to get it to accept the command without the explicit query
		if not query then
			return false
		end
		
		if handle_give_command("/giveme", name, name, query, amount) == false then
			return false, "No results found for \"" .. query .. '"'
		end
	end,
})

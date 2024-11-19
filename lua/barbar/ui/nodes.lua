--
-- node_list.lua
--

local table_insert = table.insert
local strcharpart = vim.fn.strcharpart --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function

--- Operations on `node`s.
--- @see barbar.ui.node
--- @class barbar.ui.Nodes
local nodes = {}

function Split(input, sep)
	local result = {}

	if sep == "" then
		for i = 1, #input do
			table.insert(result, input:sub(i, i))
		end
		return result
	end

	local pattern = "(.-)" .. sep
	local last_end = 1
	local s, e, cap = input:find(pattern, 1)

	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(result, cap)
		end
		last_end = e + 1
		s, e, cap = input:find(pattern, last_end)
	end

	if last_end <= #input then
		table.insert(result, input:sub(last_end))
	end

	return result
end

function pop(array)
    if #array == 0 then
        return nil -- Return nil if the array is empty
    end
    local lastElement = array[#array] -- Get the last element
    array[#array] = nil -- Remove the last element
    return lastElement
end


function fix(s)
	string.gsub(s, [[\]], "/")
	sar = Split(s, "/")
	s = pop(sar)
	return s
end

--- Sums the width of the node_list
--- @param node_list barbar.ui.node[]
--- @return integer
function nodes.width(node_list)
	local result = 0
	for _, node in ipairs(node_list) do
		result = result + strwidth(fix(node.text))
	end
	return result
end

--- Concatenates some `node_list` into a valid tabline string.
--- @param node_list barbar.ui.node[]
--- @return string
function nodes.to_string(node_list)
	local result = ''

	for _, node in ipairs(node_list) do
		-- NOTE: We have to escape the text in case it contains '%', which is a special character to the
		--       tabline.
		--       To escape '%', we make it '%%'. It just so happens that '%' is also a special character
		--       in Lua, so we have write '%%' to mean '%'.
		result = result .. node.hl .. node.text:gsub('%%', '%%%%')
	end

	return result
end

--- Concatenates some `node_list` into a raw string.
--- @param node_list barbar.ui.node[]
--- For debugging purposes.
--- @return string
function nodes.to_raw_string(node_list)
	local result = ''

	for _, node in ipairs(node_list) do
		result = result .. fix(node.text)
	end

	return result
end

--- Insert `other` into `node_list` at the `position`.
--- @param node_list barbar.ui.node[]
--- @param position integer
--- @return barbar.ui.node[] with_insertions
function nodes.insert(node_list, position, node)
	return nodes.insert_many(node_list, position, { node })
end

--- Insert `others` into `node_list` at the `position`.
--- @param node_list barbar.ui.node[]
--- @param position integer
--- @param others barbar.ui.node[]
--- @return barbar.ui.node[] with_insertions
function nodes.insert_many(node_list, position, others)
	if position < 0 then
		local others_width = nodes.width(others)
		local others_end = position + others_width

		if others_end < 0 then
			return node_list
		end

		local available_width = others_end

		position = 0
		others = nodes.slice_left(others, available_width)
	end


	local current_position = 0

	local new_nodes = {}

	local i = 1
	while i <= #node_list do
		local node = node_list[i]
		local node_width = strwidth(node.text)

		-- While we haven't found the position...
		if current_position + node_width <= position then
			table_insert(new_nodes, node)
			i = i + 1
			current_position = current_position + node_width

			-- When we found the position...
		else
			local available_width = position - current_position

			-- Slice current node if it `position` is inside it
			if available_width > 0 then
				table_insert(new_nodes, {
					text = strcharpart(node.text, 0, available_width),
					hl = node.hl,
				})
			end

			-- Add new other node_list
			local others_width = 0
			for _, other in ipairs(others) do
				local other_width = strwidth(other.text)
				others_width = others_width + other_width
				table_insert(new_nodes, other)
			end

			local end_position = position + others_width

			-- Then, resume adding previous node_list
			-- table.insert(new_nodes, 'then')
			while i <= #node_list do
				local previous_node = node_list[i]
				local previous_node_width = strwidth(previous_node.text)
				local previous_node_start_position = current_position
				local previous_node_end_position   = current_position + previous_node_width

				if previous_node_end_position <= end_position and previous_node_width ~= 0 then
					-- continue
				elseif previous_node_start_position >= end_position then
					-- table.insert(new_nodes, 'direct')
					table_insert(new_nodes, previous_node)
				else
					local remaining_width = previous_node_end_position - end_position
					local start = previous_node_width - remaining_width
					local end_  = previous_node_width
					table_insert(new_nodes, { hl = previous_node.hl, text = strcharpart(previous_node.text, start, end_) })
				end

				i = i + 1
				current_position = current_position + previous_node_width
			end

			break
		end
	end

	return new_nodes
end

--- Select from `node_list` while fitting within the provided `width`, discarding all indices larger than the last index that fits.
--- @param width integer
--- @return barbar.ui.node[] sliced
function nodes.slice_right(node_list, width)
	local accumulated_width = 0

	local new_nodes = {}

	for _, node in ipairs(node_list) do
		local text_width = strwidth(node.text)
		accumulated_width = accumulated_width + text_width

		if accumulated_width >= width then
			local diff = text_width - (accumulated_width - width)
			table_insert(new_nodes, { hl = node.hl, text = strcharpart(node.text, 0, diff) })
			break
		end

		table_insert(new_nodes, node)
	end

	return new_nodes
end

--- Select from `node_list` in reverse while fitting within the provided `width`, discarding all indices less than the last index that fits.
--- @param node_list barbar.ui.node[]
--- @param width integer
--- @return barbar.ui.node[] sliced
function nodes.slice_left(node_list, width)
	local accumulated_width = 0

	local new_nodes = {}

	for i = #node_list, 1, -1 do
		local node = node_list[i] --- @type barbar.ui.node (it cannot be `nil`)
		local text_width = strwidth(node.text)
		accumulated_width = accumulated_width + text_width

		if accumulated_width >= width then
			local length = text_width - (accumulated_width - width)
			local start = text_width - length
			table_insert(new_nodes, 1, { hl = node.hl, text = strcharpart(node.text, start, length) })
			break
		end

		table_insert(new_nodes, 1, node)
	end

	return new_nodes
end

return nodes

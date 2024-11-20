
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
	s = s:gsub([[\]], "/")
	sar = Split(s, "/")
	s = pop(sar)
	return s
end

print(fix([[\abc\dfg\a.txt]])) -- a.txt

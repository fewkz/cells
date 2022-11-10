local cellValue = setmetatable({}, { __mode = "k" })
local cellDependents = setmetatable({}, { __mode = "k" })

local FENV_KEY = "74709086-5669-43dc-a7d1-195d71ae0464"

local function topologicallyUpdate(rootDependents: any)
	local visited = {}
	local stack = {}
	local function visit(d)
		if visited[d.cell] then
			return
		end
		visited[d.cell] = true
		for _, d in d.dependents do
			visit(d)
		end
		table.insert(stack, d)
	end
	for _, d in rootDependents do
		visit(d)
	end
	for i = #stack, 1, -1 do
		local d = stack[i]
		d:recompute()
	end
end

local function metaIndex(self, key)
	if key == "value" then
		local d = getfenv(0)[FENV_KEY]
		if d and not d.seen[self] then
			local i = table.insert(cellDependents[self], d)
			table.insert(d.unsubscribes, function()
				table.remove(cellDependents[self], i)
			end)
		end
		return cellValue[self]
	else
		error(string.format('Cannot get key %q from a cell, only valid field is "value"', key), 2)
	end
end

local function metaNewIndex(self, key, value)
	if key == "value" then
		cellValue[self] = value
		local fenv = getfenv(0)[FENV_KEY]
		if fenv == nil then
			local dependents = cellDependents[self]
			cellDependents[self] = setmetatable({}, { __mode = "v" })
			topologicallyUpdate(dependents)
		elseif fenv.seen then
			error("Cannot set cell value from within a cell computation", 2)
		elseif fenv.batch then
			fenv.batch[self] = { cell = self, dependents = cellDependents[self] }
		end
	else
		error(string.format('Cannot set key %q in a cell, only valid field is "value"', key), 2)
	end
end

local function metaToString(self)
	return tostring(cellValue[self])
end

local function cell<T>(initial: T): { value: T }
	local cell = newproxy(true)
	local mt = getmetatable(cell)
	mt.__index = metaIndex
	mt.__newindex = metaNewIndex
	mt.__tostring = metaToString
	cellValue[cell] = initial
	cellDependents[cell] = setmetatable({}, { __mode = "v" })
	return cell
end

return cell

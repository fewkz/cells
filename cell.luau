local FENV_KEY = "74709086-5669-43dc-a7d1-195d71ae0464"

local function topologicallyUpdate(rootDependents: any)
	local visited = {}
	local stack = {}
	local function visit(d)
		if visited[d] then
			return
		end
		visited[d] = true
		for d in d.dependents do
			visit(d)
		end
		table.insert(stack, d)
	end
	for d in rootDependents do
		visit(d)
	end
	for i = #stack, 1, -1 do
		local d = stack[i]
		d:recompute()
	end
end

local function metaIndex(self, key)
	if key == "value" then
		local ourData = getmetatable(self)._cellData
		local d = getfenv(0)[FENV_KEY]
		if d and not d.seen[self] then
			d.seen[self] = true
			ourData.dependents[d] = true
			table.insert(d.unsubscribes, function()
				ourData.dependents[d] = nil
			end)
		end
		return ourData.value
	else
		error(string.format('Cannot get key %q from a cell, only valid field is "value"', key), 2)
	end
end

local function metaNewIndex(self, key, value)
	if key == "value" then
		local ourData = getmetatable(self)._cellData
		local fenv = getfenv(0)[FENV_KEY]
		if fenv == nil then
			if ourData.value ~= value then
				ourData.value = value
				local dependents = ourData.dependents
				ourData.dependents = setmetatable({}, { __mode = "k" })
				topologicallyUpdate(dependents)
			end
		elseif fenv.batch then
			if ourData.value ~= value then
				ourData.value = value
				fenv.batch[ourData] = true
			end
		elseif fenv.seen then
			error("Cannot set cell value from within a cell computation", 2)
		end
	else
		error(string.format('Cannot set key %q in a cell, only valid field is "value"', key), 2)
	end
end

local function metaToString(self)
	local ourData = getmetatable(self)._cellData
	return tostring(ourData.value)
end

local function cell<T>(initial: T): { value: T }
	local cell = newproxy(true)
	local mt = getmetatable(cell)
	mt.__index = metaIndex
	mt.__newindex = metaNewIndex
	mt.__tostring = metaToString
	local cellData = {
		cell = cell,
		seen = {},
		unsubscribes = {},
		dependents = setmetatable({}, { __mode = "k" }),
		value = initial,
	}
	mt._cellData = cellData
	return cell
end

return cell

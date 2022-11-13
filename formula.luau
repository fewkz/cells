local FENV_KEY = "74709086-5669-43dc-a7d1-195d71ae0464"

local function callFormulaBody(cellData, body, recompute)
	cellData.seen = {}
	getfenv(0)[FENV_KEY] = cellData
	cellData.value = body()
	getfenv(0)[FENV_KEY] = nil
	cellData.seen = nil
end

local function recompute(d)
	for _, unsubscribe in d.unsubscribes do
		unsubscribe()
	end
	table.clear(d.dependents)
	table.clear(d.roots)
	table.clear(d.unsubscribes)
	callFormulaBody(d, d.body, recompute)
end

local function metaIndex(self, key)
	if key == "value" then
		local ourData = getmetatable(self)._data
		local d = getfenv(0)[FENV_KEY]
		if d and d.seen and not d.seen[self] then
			d.seen[self] = true
			ourData.dependents[d] = true
			table.insert(d.unsubscribes, function()
				ourData.dependents[d] = nil
			end)
			for root in ourData.roots do
				d.roots[root] = true
			end
		end
		return ourData.value
	else
		error(string.format('Cannot get key %q from a cell, only valid field is "value"', key), 2)
	end
end

local function metaNewIndex(self, key, value)
	error("Cannot set the value of a derived cell", 2)
end

local function metaToString(self)
	local ourData = getmetatable(self)._data
	return tostring(ourData.value)
end

local function formula<T>(body: () -> T): { value: T }
	local cell = newproxy(true)
	local mt = getmetatable(cell)
	mt.__index = metaIndex
	mt.__newindex = metaNewIndex
	mt.__tostring = metaToString
	local data = {
		proxy = cell, -- Store a reference to the proxy so it doesn't get garbage collected.
		body = body,
		recompute = recompute,
		seen = {},
		unsubscribes = {},
		dependents = setmetatable({}, { __mode = "k" }),
		roots = {},
	}
	mt._data = data
	callFormulaBody(data, body, recompute)
	return cell
end

return formula

local cellValue = setmetatable({}, { __mode = "k" })
local cellDependents = setmetatable({}, { __mode = "k" })

local FENV_KEY = "74709086-5669-43dc-a7d1-195d71ae0464"

local function callFormulaBody(cell, body, recompute)
	local dependents = setmetatable({}, { __mode = "k" })
	cellDependents[cell] = dependents
	getfenv(0)[FENV_KEY] = {
		body = body,
		-- We use a weak table here so that the cell can be garbage collected.
		-- Otherwise, this dependency would keep the cell alive.
		cell = setmetatable({ inner = cell }, { __mode = "v" }),
		seen = {},
		recompute = recompute,
		dependents = dependents,
		unsubscribes = {},
	}
	cellValue[cell] = body()
	getfenv(0)[FENV_KEY] = nil
end

local function recompute(d)
	for _, unsubscribe in d.unsubscribes do
		unsubscribe()
	end
	callFormulaBody(d.cell.inner, d.body, recompute)
end

local function metaIndex(self, key)
	if key == "value" then
		local d = getfenv(0)[FENV_KEY]
		if d and not d.seen[self] then
			d.seen[self] = true
			cellDependents[self][d.cell.inner] = d
			table.insert(d.unsubscribes, function()
				cellDependents[self][d.cell.inner] = nil
			end)
		end
		return cellValue[self]
	else
		error(string.format('Cannot get key %q from a cell, only valid field is "value"', key), 2)
	end
end

local function metaNewIndex(self, key, value)
	error("Cannot set the value of a derived cell", 2)
end

local function metaToString(self)
	return tostring(cellValue[self])
end

local function formula<T>(body: () -> T): { value: T }
	local cell = newproxy(true)
	local mt = getmetatable(cell)
	mt.__index = metaIndex
	mt.__newindex = metaNewIndex
	mt.__tostring = metaToString
	callFormulaBody(cell, body, recompute)
	return cell
end

return formula

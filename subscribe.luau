local FENV_KEY = "74709086-5669-43dc-a7d1-195d71ae0464"

local function callBody(cellData, body, recompute)
	cellData.seen = {}
	getfenv(0)[FENV_KEY] = cellData
	body()
	getfenv(0)[FENV_KEY] = nil
	cellData.seen = nil
	for root in cellData.roots do
		root.subscriptions[cellData] = true
		table.insert(cellData.unsubscribes, function()
			root.subscriptions[cellData] = nil
		end)
	end
end

local function recompute(d)
	for _, unsubscribe in d.unsubscribes do
		unsubscribe()
	end
	table.clear(d.roots)
	table.clear(d.unsubscribes)
	callBody(d, d.body, recompute)
end

local function subscribe<T>(body: () -> ())
	local subscription = newproxy(true)
	local cellData = {
		proxy = subscription, -- Store a reference to the proxy so it doesn't get garbage collected.
		body = body,
		recompute = recompute,
		dependents = setmetatable({}, { __newindex = function() end }),
		unsubscribes = {},
		roots = {},
	}
	getmetatable(subscription)._data = cellData
	callBody(cellData, body, recompute)
	return function()
		for _, unsubscribe in cellData.unsubscribes do
			unsubscribe()
		end
		table.clear(cellData.unsubscribes)
	end
end

return subscribe

-- Keep subscriptions alive so they don't get garbage collected
-- TODO: This is a memory leak, subscriptions should instead be
-- garbaged collected when all the cells it depends on are gone.
local subscriptions = {}

local FENV_KEY = "74709086-5669-43dc-a7d1-195d71ae0464"

local function callBody(cellData, body, recompute)
	cellData.seen = {}
	getfenv(0)[FENV_KEY] = cellData
	body()
	getfenv(0)[FENV_KEY] = nil
	cellData.seen = nil
end

local function recompute(d)
	for _, unsubscribe in d.unsubscribes do
		unsubscribe()
	end
	table.clear(d.unsubscribes)
	callBody(d, d.body, recompute)
end

local function subscribe<T>(body: () -> ())
	local subscription = newproxy(true)
	local cellData = {
		cell = subscription,
		body = body,
		recompute = recompute,
		dependents = setmetatable({}, { __newindex = function() end }),
		unsubscribes = {},
	}
	getmetatable(subscription)._cellData = cellData
	callBody(cellData, body, recompute)
	subscriptions[subscription] = true
	return function()
		for _, unsubscribe in cellData.unsubscribes do
			unsubscribe()
		end
		table.clear(cellData.unsubscribes)
		subscriptions[subscription] = nil
	end
end

return subscribe

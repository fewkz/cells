local cellUnsubscribes = setmetatable({}, { __mode = "k" })

-- Keep subscriptions alive so they don't get garbage collected
-- TODO: This is a memory leak, subscriptions should instead be
-- garbaged collected when all the cells it depends on are gone.
local subscriptions = {}

local FENV_KEY = "74709086-5669-43dc-a7d1-195d71ae0464"

local function callBody(cell, body, recompute)
	local unsubscribes = {}
	cellUnsubscribes[cell] = unsubscribes
	getfenv(0)[FENV_KEY] = {
		body = body,
		-- We use a weak table here so that the cell can be garbage collected.
		-- Otherwise, this dependency would keep the cell alive.
		cell = setmetatable({ inner = cell }, { __mode = "v" }),
		seen = {},
		recompute = recompute,
		dependents = {},
		unsubscribes = unsubscribes,
	}
	body()
	getfenv(0)[FENV_KEY] = nil
end

local function recompute(d)
	for _, unsubscribe in d.unsubscribes do
		unsubscribe()
	end
	callBody(d.cell.inner, d.body, recompute)
end

local function subscribe<T>(body: () -> ())
	local subscription = newproxy()
	callBody(subscription, body, recompute)
	subscriptions[subscription] = true
	return function()
		for _, unsubscribe in cellUnsubscribes[subscription] do
			unsubscribe()
		end
		cellUnsubscribes[subscription] = nil
		subscriptions[subscription] = nil
	end
end

return subscribe

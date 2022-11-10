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

local function batch(body: () -> ())
	local fenv = getfenv(0)[FENV_KEY]
	local nested = fenv and fenv.batch ~= nil
	if nested then
		body()
	else
		local dependents = {}
		getfenv(0)[FENV_KEY] = { batch = dependents }
		body()
		getfenv(0)[FENV_KEY] = nil
		topologicallyUpdate(dependents)
	end
end

return batch

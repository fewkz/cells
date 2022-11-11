local cell = require("cell")
local formula = require("formula")
local batch = require("batch")

local passedTests = {}
local failedTests = {}

local function test(name: string, body: () -> ())
	local suc = xpcall(body, function(msg)
		table.insert(failedTests, { name = name, msg = msg })
	end)
	if suc then
		table.insert(passedTests, name)
	end
end

test("Cells can be created and read from", function()
	local c = cell(1)
	assert(c.value == 1)
end)

test("Cells can be written to", function()
	local c = cell(1)
	assert(c.value == 1)
	c.value = 2
	assert(c.value == 2)
end)

test("Cells can be converted to a string", function()
	assert(tostring(cell("Hello, World!")) == "Hello, World!")
end)

test("Derived cells can be created and read from", function()
	local f = formula(function()
		return "Hello, World!"
	end)
	assert(f.value == "Hello, World!")
end)

test("Derived cells are updated if any cell it refers to changes", function()
	local c = cell(8)
	local f = formula(function()
		return "The lucky number is " .. c.value
	end)
	assert(f.value == "The lucky number is 8", "Formula should have been evaluated")
	c.value = 64
	assert(f.value == "The lucky number is 64", "Formula should have been re-evaluated")
end)

test("Derived cells can depend on other derived cells", function()
	local c = cell(8)
	local f1 = formula(function()
		return "The lucky number is " .. c.value
	end)
	local f2 = formula(function()
		return f1.value .. "!"
	end)
	assert(f2.value == "The lucky number is 8!", "Formula should have been evaluated")
	c.value = 64
	assert(f2.value == "The lucky number is 64!", "Formula should have been re-evaluated")
end)

test("Derived cells dependencies can change", function()
	local switchCell = cell(false)
	local c1 = cell(1)
	local c2 = cell(2)
	local timesRan = 0
	local f = formula(function()
		timesRan += 1
		if switchCell.value then
			return "foxes - " .. c1.value
		else
			return "kitties - " .. c2.value
		end
	end)
	assert(f.value == "kitties - 2", "Formula should have been evaluated")
	assert(timesRan == 1, "Formula should have run once, but ran " .. timesRan .. " times")
	c1.value = 3
	assert(f.value == "kitties - 2", "Formula should not have been re-evaluated")
	assert(timesRan == 1, "Formula should have only ran once, but ran " .. timesRan .. " times")
	c2.value = 4
	assert(f.value == "kitties - 4", "Formula should have been re-evaluated")
	assert(timesRan == 2, "Formula should have only ran twice, but ran " .. timesRan .. " times")
	switchCell.value = true
	assert(f.value == "foxes - 3", "Formula should have been re-evaluated")
	assert(timesRan == 3, "Formula should have only ran thrice, but ran " .. timesRan .. " times")
end)

test("Updates to derived cells are topologically sorted", function()
	local c = cell({ "Hello,", "World!" })
	local firstWord = formula(function()
		return c.value[1]
	end)
	local secondWord = formula(function()
		return c.value[2]
	end)
	local timesRan = 0
	local computed = formula(function()
		timesRan += 1
		return string.format("%s %s", firstWord.value, secondWord.value)
	end)
	assert(computed.value == "Hello, World!", "Formula should have been evaluated")
	assert(timesRan == 1, "Formula should have run once")
	-- Changing the value of the cell will only recompute the formula once
	c.value = { "foo", "bar" }
	assert(computed.value == "foo bar", "Formula should have been re-evaluated")
	assert(timesRan == 2, "Formula should have only ran twice, but ran " .. timesRan .. " times")
end)

test("Updates can be batched", function()
	local c = cell(1)
	local timesRan = 0
	local f = formula(function()
		timesRan += 1
		return c.value + 1
	end)
	assert(f.value == 2, "Formula should have been evaluated")
	batch(function()
		c.value = 2
		c.value = 3
		c.value = 4
	end)
	assert(f.value == 5, "Formula should have been re-evaluated")
	assert(timesRan == 2, "Formula should have only ran twice")
end)

test("Batches can be nested", function()
	local c = cell(1)
	local timesRan = 0
	local f = formula(function()
		timesRan += 1
		return c.value + 1
	end)
	assert(f.value == 2, "Formula should have been evaluated")
	batch(function()
		c.value = 2
		batch(function()
			c.value = 3
			c.value = 4
		end)
		c.value = 5
	end)
	assert(f.value == 6, "Formula should have been re-evaluated")
	assert(timesRan == 2, "Formula should have only ran twice")
end)

test("Batch affecting multiple dependencies of a cell will only update it once", function()
	local c1 = cell("foo")
	local c2 = cell("bar")
	local timesRan = 0
	local f = formula(function()
		timesRan += 1
		return c1.value .. c2.value
	end)
	assert(f.value == "foobar", "Formula should have been evaluated")
	assert(timesRan == 1, "Formula should have run once, but ran " .. timesRan .. " times")
	-- The formula will only be recomputed at the end of the batch block
	batch(function()
		c1.value = "first"
		c2.value = "second"
	end)
	assert(f.value == "firstsecond", "Formula should have been re-evaluated")
	assert(timesRan == 2, "Formula should have only ran twice, but ran " .. timesRan .. " times")
end)

test("Unused derived cells should be garbage collected", function()
	local c = cell(1)
	local t = setmetatable({}, { __mode = "v" })
	t[1] = formula(function()
		return c.value
	end)
	assert(t[1].value == 1, "Formula should have been evaluated")
	collectgarbage()
	assert(t[1] == nil, "Formula should have been garbage collected")
end)

test("Dependencies shouldn't be garbaged collected unexpectedly", function()
	local c = cell(1)
	local f = formula(function()
		return c.value
	end)
	assert(f.value == 1, "Formula should have been evaluated")
	collectgarbage()
	c.value = 2
	assert(f.value == 2, "Formula should have been re-evaluated")
end)

test("Setting a cell to the value value shouldn't trigger a re-evaluation", function()
	local c = cell(1)
	local timesRan = 0
	local f = formula(function()
		timesRan += 1
		return c.value
	end)
	assert(f.value == 1, "Formula should have been evaluated")
	assert(timesRan == 1, "Formula should have run once, but ran " .. timesRan .. " times")
	c.value = 1
	assert(f.value == 1, "Formula should not have been re-evaluated")
	assert(timesRan == 1, "Formula should have only ran once, but ran " .. timesRan .. " times")
end)

local red = "\27[31m"
local green = "\27[32m"
local bold = "\27[1m"
local reset = "\27[0m"
local underline = "\27[4m"

for _, passedTest in passedTests do
	print(green .. underline .. passedTest .. reset)
end
for _, failedTest in failedTests do
	print(red .. underline .. failedTest.name .. reset)
	print(failedTest.msg)
end
if #failedTests > 0 then
	error(red .. bold .. #failedTests .. " tests failed" .. reset, 0)
else
	print(green .. bold .. "All tests passed!" .. reset)
end
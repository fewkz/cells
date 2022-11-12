# Cells

Cells is a Luau library that provide simple primitives for writing reactive
code. It is based off the idea of spreadsheets, where the value of a cell can be
modified or derived from a formula that depends on other cells. The library is
based off of https://github.com/preactjs/signals

```lua
local foo = cell(2)
print(foo.value) -- 2
local fooSquared = formula(function()
    return foo.value * foo.value
end)
print(fooSquared) -- 4
foo.value = 10
print(fooSquared) -- 100
```

## Cells

A cell represents a piece of data that can change. It can store any data. When a
cell changes, anything that depends on it will be recomputed. You can create a
cell by using the `cell` function, and passing in an initial value.

```lua
local stringCell = cell("Hello, World!")
local numberCell = cell(1)
local tableCell = cell({ text = "Cells can store anything!" })
print(stringCell.value) -- Hello, World!

print(numberCell.value) -- 1
numberCell.value = 10
print(numberCell.value) -- 10

stringCell.value = 3 -- Luau analyze will give a TypeError
```

## Derived cells

A derived cell can be created by using the `formula` function. Any cells that
are used in the formula will become dependencies of the derived cell. The
derived cell will update whenever the value of any cells it depends on changes.
Derived cells are read-only, attempting to set the value of a derived cell will
cause a runtime error. Derived cells are garbage collected when there are no
more references to them.

```lua
local points = cell(100)
local pointsText = formula(function()
    return `You have {points.value} points.`
end)
print(pointsText.value) -- You have 100 points.
points.value = 200
print(pointsText.value) -- You have 200 points.
```

## Batching

You can use the `batch` function to update multiple cells at once, and only
trigger updates at the end of the batch.

```lua
local c1 = cell("foo")
local c2 = cell("bar")
local f = formula(function()
    return c1.value .. c2.value
end)
-- The formula will only be recomputed at the end of the batch block
batch(function()
    c1.value = "first"
    c2.value = "second"
end)
```

## Topological sorting

Derived cells are recomputed in topological order. This means all the cells that
a cell depends on will be recomputed before the cell itself, minimizing
unnecessary computations.

```lua
local c = cell({"Hello,", "World!"})
local firstWord = formula(function()
    return c.value[1]
end)
local secondWord = formula(function()
    return c.value[2]
end)
local combined = formula(function()
    return `{firstWord.value} {secondWord.value}`
end)
-- Changing the value of the cell will only recompute each formula once
c.value = {"foo", "bar"}
```

## Subscriptions

The `subscribe` function can be used to subscribe to when cells change. The
callback will be called immediately, and any cells it depends on will become
dependencies that will run the callback whenever they're changed. Subscribing
returns an function that can be used to unsubscribe from all cells. Note:
subscriptions can cause a memory leak if they are not unsubscribed from.

```lua
local foo = cell(2)
local fooSquared = formula(function()
    return foo.value * foo.value
end)
local unsub = subscribe(function()
    print(`foo is {foo.value} and foo squared is {fooSquared.value}`)
end)
-- Prints foo is 2 and foo squared is 4

foo.value = 10
-- Prints foo is 10 and foo squared is 100

unsub()
foo.value = 20
-- Nothing is printed
```

--!nocheck
-- Local unit-test runner (Lune). Runs the real ModuleScripts from a Rojo-built place file
-- outside Studio, with small shims for the few engine services the pure modules touch.
-- Usage: lune run tools/run-tests.luau <place.rbxl> [filter]
-- Studio stays the authority (it runs every suite, including engine-heavy ones); this is a
-- fast pre-check. Suites that need engine features Lune lacks are skipped and listed.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local placePath = process.args[1] or error("usage: lune run tools/run-tests.luau <place.rbxl> [filter]")
local filter = process.args[2]
local SKIP = { ItemAssets_Test = "needs Model:GetPivot / PrimaryPart (Studio only)" }

local dm = roblox.deserializePlace(fs.readFile(placePath))

local guidCounter = 0
local shims = {
	HttpService = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, s)
			return serde.decode("json", s)
		end,
		GenerateGUID = function()
			guidCounter += 1
			return "local-guid-" .. guidCounter
		end,
	},
	RunService = {
		IsStudio = function()
			return true
		end,
	},
}

local game = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return shims[name] or dm:GetService(name)
			end
		end
		return dm[key]
	end,
})

local cache = {}
local function makeRequire()
	local function req(module)
		if cache[module] ~= nil then
			return cache[module]
		end
		assert(module:IsA("ModuleScript"), "require target is not a ModuleScript: " .. tostring(module))
		local env = setmetatable({
			script = module,
			game = game,
			require = req,
			task = task,
			workspace = dm:GetService("Workspace"),
			CFrame = roblox.CFrame,
			Vector3 = roblox.Vector3,
			Color3 = roblox.Color3,
			Enum = roblox.Enum,
		}, { __index = getfenv and getfenv(0) or _G })
		local fn = luau.load(module.Source, { debugName = module:GetFullName(), environment = env })
		local result = fn()
		cache[module] = result
		return result
	end
	return req
end
local requireModule = makeRequire()

local ServerStorage = dm:GetService("ServerStorage")
local cases = ServerStorage:FindFirstChild("UnitTest"):FindFirstChild("Cases")

-- Same assertion API as RunUnitTest.
local function fmt(v)
	return if type(v) == "string" then string.format("%q", v) else tostring(v)
end
local expect = {}
function expect.equal(a, b)
	if a ~= b then
		error(string.format("expected %s, got %s", fmt(b), fmt(a)), 2)
	end
end
function expect.truthy(v)
	if not v then
		error("expected truthy, got " .. fmt(v), 2)
	end
end
function expect.falsy(v)
	if v then
		error("expected falsy, got " .. fmt(v), 2)
	end
end
function expect.near(a, b, tol)
	tol = tol or 1e-6
	if type(a) ~= "number" or math.abs(a - b) > tol then
		error(string.format("expected %s within %s of %s", fmt(a), fmt(tol), fmt(b)), 2)
	end
end
function expect.throws(fn)
	local ok, err = pcall(fn)
	if ok then
		error("expected the function to throw", 2)
	end
	return err
end
function expect.deepEqual(a, b)
	local function eq(x, y)
		if x == y then
			return true
		end
		if type(x) ~= "table" or type(y) ~= "table" then
			return false
		end
		for k, v in x do
			if not eq(v, y[k]) then
				return false
			end
		end
		for k in y do
			if x[k] == nil then
				return false
			end
		end
		return true
	end
	if not eq(a, b) then
		error("tables are not deeply equal", 2)
	end
end

local run, passed, failed, skipped = 0, 0, 0, {}
local modules = cases:GetChildren()
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)
for _, module in modules do
	if filter and not string.find(module.Name, filter, 1, true) then
		continue
	end
	if SKIP[module.Name] then
		table.insert(skipped, module.Name .. " (" .. SKIP[module.Name] .. ")")
		continue
	end
	local ok, caseFn = pcall(requireModule, module)
	if not ok then
		run += 1
		failed += 1
		print("[FAIL] " .. module.Name .. " | load error: " .. tostring(caseFn))
		continue
	end
	caseFn({
		expect = expect,
		test = function(name, fn)
			run += 1
			local okCase, err = pcall(fn)
			if okCase then
				passed += 1
				print("[PASS] " .. module.Name .. " > " .. name)
			else
				failed += 1
				print("[FAIL] " .. module.Name .. " > " .. name .. " | " .. tostring(err))
			end
		end,
	})
end
for _, s in skipped do
	print("[SKIP] " .. s)
end
print(string.format("[SUMMARY] %d run, %d passed, %d failed, %d suites skipped", run, passed, failed, #skipped))
process.exit(if failed == 0 then 0 else 1)

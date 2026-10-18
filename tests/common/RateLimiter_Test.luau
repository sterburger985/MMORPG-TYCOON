--!nonstrict
-- Tests for ServerScriptService.Server.Util.RateLimiter.
-- Contract: token bucket per key; starts full at `burst`, refills at `rate`/s, never above burst.
return function(t)
	local RateLimiter = require(game:GetService("ServerScriptService").Server.Util.RateLimiter)
	local expect = t.expect

	local function fakeClock()
		local now = 0
		return function()
			return now
		end, function(dt)
			now += dt
		end
	end

	-- A fresh key can spend exactly `burst` tokens immediately.
	t.test("allows the burst then blocks", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(2, 3, clock)
		expect.truthy(limiter:tryConsume("a"))
		expect.truthy(limiter:tryConsume("a"))
		expect.truthy(limiter:tryConsume("a"))
		expect.falsy(limiter:tryConsume("a"))
	end)

	-- After 0.5s at 2 tokens/s, exactly one more request is allowed.
	t.test("refills at the configured rate", function()
		local clock, advance = fakeClock()
		local limiter = RateLimiter.new(2, 1, clock)
		expect.truthy(limiter:tryConsume("a"))
		expect.falsy(limiter:tryConsume("a"))
		advance(0.5)
		expect.truthy(limiter:tryConsume("a"))
		expect.falsy(limiter:tryConsume("a"))
	end)

	-- One player spamming doesn't block another.
	t.test("keys are independent", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(1, 1, clock)
		expect.truthy(limiter:tryConsume("a"))
		expect.falsy(limiter:tryConsume("a"))
		expect.truthy(limiter:tryConsume("b"))
	end)

	-- A long idle period refills to burst, not beyond.
	t.test("never stores more than burst", function()
		local clock, advance = fakeClock()
		local limiter = RateLimiter.new(10, 2, clock)
		limiter:tryConsume("a")
		advance(1000)
		expect.truthy(limiter:tryConsume("a"))
		expect.truthy(limiter:tryConsume("a"))
		expect.falsy(limiter:tryConsume("a"))
	end)

	-- forget() resets a key to a full bucket.
	t.test("forget resets the bucket", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(1, 1, clock)
		limiter:tryConsume("a")
		limiter:forget("a")
		expect.truthy(limiter:tryConsume("a"))
	end)

	-- Invalid configuration fails loudly.
	t.test("rejects invalid configuration", function()
		expect.throws(function()
			RateLimiter.new(0, 1)
		end)
		expect.throws(function()
			RateLimiter.new(1, 0)
		end)
	end)
end

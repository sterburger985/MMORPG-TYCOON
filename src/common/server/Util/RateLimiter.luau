--!strict
-- RateLimiter: token bucket per key (one bucket per player).
-- Each request costs one token; tokens refill at `rate` per second up to `burst`.
-- The clock is injectable so tests stay deterministic.

export type RateLimiter = {
	tryConsume: (self: RateLimiter, key: any) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, t: number }

local RateLimiter = {}

function RateLimiter.new(rate: number, burst: number, clock: (() -> number)?): RateLimiter
	assert(rate > 0 and burst >= 1, "RateLimiter needs rate > 0 and burst >= 1")
	local now: () -> number = clock or os.clock
	local buckets: { [any]: Bucket } = {}

	local self = {} :: RateLimiter

	function self.tryConsume(_self: RateLimiter, key: any): boolean
		local t = now()
		local bucket = buckets[key]
		if bucket == nil then
			bucket = { tokens = burst, t = t }
			buckets[key] = bucket
		end
		bucket.tokens = math.min(burst, bucket.tokens + (t - bucket.t) * rate)
		bucket.t = t
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	function self.forget(_self: RateLimiter, key: any)
		buckets[key] = nil
	end

	return self
end

return RateLimiter

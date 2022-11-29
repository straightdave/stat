--
-- Get data in a certain time span from Redis ZSET
--
-- Note: run mix clean before run the app if there's any
--       changes in this script (including comments).
--

local t = redis.call('TIME')[1]
t = tonumber(t)

local last_end = redis.call('GET', 'apollo:last_end')
if last_end == false then
  -- if last end time is not set, set it and quit
  redis.call('SET', 'apollo:last_end', t)
  return 1 -- just initialized
end

last_end = tonumber(last_end)

-- in case the last_end is too old (e.g StatServer stops for a while).
-- only one call to this in concurrent calls
if last_end < t - 10 then
  last_end = t - 10
end

-- time span: ARGV[1]
local span = ARGV[1]
if span == nil then
  -- default span: 5s
  span = 5
end

local new_end = last_end + span

-- return {t, last_end, new_end}
-- [1669620058, 1669607675, 1669607685]

if t < new_end then
  -- if current time is less than last_end plus SPAN,
  -- quit and wait for next turn.
  return 2 -- data not ready
end

-- responses other than 1 or 2 should be seen as success.

local data = redis.call('ZRANGE', KEYS[1], '-inf', new_end, 'BYSCORE')
local len = 0
if data then
  len = table.getn(data)
end

-- remove those data
redis.call('ZPOPMIN', KEYS[1], len)

-- set new end time so this makes sure that data is poped every 5 seconds.
redis.call('SET', 'apollo:last_end', new_end)

-- returns an array: 1st is the timestamp. 2nd is an array of data.
-- if no data in the span, it could be like [1669000000, [ ... ]]
return {last_end, data}

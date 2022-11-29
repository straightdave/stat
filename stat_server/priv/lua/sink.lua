local t = redis.call('TIME')[1]
t = tonumber(t)
redis.call('ZADD', KEYS[1], t, ARGV[1])
return t

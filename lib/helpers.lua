local cjson = require('cjson')
local config = require("config.app")
local cookie_obj = require("lib.cookie")

-- use for k,v in pairsByKeys(hashTable) then ... end sort a hashTable by key
function pairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0                 -- iterator variable
    local iter = function ()    -- iterator function
       i = i + 1
       if a[i] == nil then return nil
       else return a[i], t[a[i]]
       end
    end
    return iter

end

function set_cookie(key, value, expires)
    local cookie, err = cookie_obj:new()
    if not cookie then
        ngx.log(ngx.ERR, err)
        return false, err
    end
    local cookie_payload = {
        key = key, value = value
    }
    if expires ~= nil then
        cookie_payload.expires = ngx.cookie_time(expires)
    end
    local ok, err = cookie:set(cookie_payload)
    if not ok then
        ngx.log(ngx.ERR, err)
        return false, err
    end
    return true
end

function get_cookie(key)
    local cookie, err = cookie_obj:new()
    if not cookie then
        ngx.log(ngx.ERR, err)
        return false
    end
    return cookie:get(key)
end

function get_local_time()
    local time_zone = ngx.re.match(config.time_zone, "[0-9]+")
    if time_zone == nil then
        local err = 'not set time zone or format error, time zone should look like `UTC+8` current is: '..config.time_zone
        ngx.log(ngx.ERR, err)
        return false, err
    end
    -- time-zone * 60(sec) * 60(min) + UTC+0 time = current time
    return time_zone[0] * 3600 + ngx.time()
end
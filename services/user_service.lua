local auth = require('providers.auth_service_provider')
local ipLocation = require('lib.ip_location')
local AccountLog = require('models.account_log')
local redis = require('lib.redis')

local _M = {}

function _M:verifyCheckcode(phone, smscode)
    local cacheCode = redis:get('phone:'..phone)
    if cacheCode ~= nil and cacheCode == smscode then
        return true
    end
    return false
end

function _M:notify(login_id)
    -- you can send a message to message queue
    return true
end

function _M:authorize(user)
    -- login success
    auth:authorize(user)
    -- 每次ip定位都会有 IO 消耗，读ip二进制dat文件
    local ipObj, err = ipLocation:new(ngx.var.remote_addr)
    local location, err = ipObj:location()
    if not location then
        return false, err
    end
    AccountLog:create(
        {
            ip = ngx.var.remote_addr,
            city = location.city,
            country = location.country,
            type = 'login'
        }
    )
    return true
end

return _M

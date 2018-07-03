local request = require('lib.request')
local common = require('lib.common')
local User = require('models.user')
local AccountLog = require('models.account_log')
local validator = require('lib.validator')
local config = require('config.app')
local auth = require('providers.auth_service_provider')
local cjson = require('cjson')
local user_service = require('services.user_service')
local random = require('lib.random')
local env = require('env')
local random = require('lib.random')
local redis = require('lib.redis')
local sms_service = require('services.sms_service')

local _M = {}

function _M:send_sms()
    local conf = config.sendcloud
    local args = request:all()
    local ok, msg =
        validator:check(
        args,
        {
            config.login_id
        }
    )
    if not ok then
        common:response(1, msg)
    end
    local key = 'phone:' .. args[config.login_id]
    local data, err = redis:get(key)
    if err then
        ngx.log(ngx.ERR, err)
        common:response(0x000007, err)
    else
        local smscode =
            random.number(math.pow(10, config.phone_code_len - 1), math.pow(10, config.phone_code_len) - 1)
        -- 用户第一次请求
        if data == nil then
            local ok, err = redis:set(key, smscode, 300)
            if not ok then
                ngx.log(ngx.ERR, err)
            end
            local ok, err = ngx.timer.at(0, function (premature, phone, smscode)
                    local ok, err = sms_service:sendSms(args[config.login_id], smscode)
                    if not ok then
                        ngx.log(ngx.ERR, err)
                    end
                end,
                args[config.login_id], smscode)
            if not ok then
                common:response(0x00000B, err)
            end
            common:response(0)
        else
            -- 用户大于1次请求
            local ttl, err = redis:ttl(key)
            if not ttl then
                ngx.log(ngx.ERR, err)
                common:response(0x000007, err)
            end
            if ttl > 240 then
                -- 没过60秒
                common:response(0x020001)
            else
                -- 过了60秒, 重置
                local ok, err = redis:set(key, smscode, 300)
                if not ok then
                    ngx.log(ngx.ERR, err)
                end
                -- local ok, err = sms_service:sendSms(args[config.login_id], smscode)
                local ok, err = ngx.timer.at(0, function (premature, phone, smscode)
                        local ok, err = sms_service:sendSms(args[config.login_id], smscode)
                        if not ok then
                            ngx.log(ngx.ERR, err)
                        end
                    end,
                    args[config.login_id], smscode)
                if not ok then
                    common:response(0x00000B, err)
                end
                common:response(0)
            end
        end
    end
end

function _M:login()
    local args = request:all()
    local ok, msg =
        validator:check(
        args,
        {
            config.login_id,
        }
    )
    if not ok then
        common:response(0x000001, msg)
    end
    local ok, user = User:find_by_login_id(args[config.login_id])
    if not ok then
        common:response(0x010003)
    end
    if args.smscode then
        ok = user_service:verify_checkcode(args[config.login_id], args.smscode)
        if not ok then
            common:response(0x000001, 'invalidate sms code')
        else
            user_service:authorize(user)
        end
    elseif args.password then
        ok, err = user_service:verify_password(args.password, user.password)
        if not ok then
            -- login fail
            common:response(0x010002, config.login_id .. ' or password error')
        else
            ok, err = user_service:authorize(user)
            if not ok then
                -- @todo should render only error message
                common:response(0x000001, err)
            end
        end
    else
        common:response(0x000001, 'need sms or password')
    end
    
    common:response(0, 'ok', user)
end

function _M:register()
    local args = request:all()
    local ok, msg =
        validator:check(
        args,
        {
            config.login_id,
            'password',
        }
    )
    if not ok then
        common:response(0x000001, msg)
    end
    -- 检测是否重复
    ok = User:find_by_login_id(args[config.login_id])
    if ok then
        common:response(0x010001)
    end

    local user_obj = {
        nickname = random.token(8),
        password = common:hash(args.password)
    }
    user_obj[config.login_id] = args[config.login_id]
    ok = User:create(user_obj)
    if not ok then
        common(0x000005)
    end
    common:response(0)
end

function _M:logout()
    local ok, err = auth:clear_token()
    if not ok then
        ngx.log(ngx.ERR, err)
        common:response(0x00000A)
    end
    return common:response(0)
end

function _M:reset_password()
    local args = request:all()
    local ok, msg = validator:check(args, {
        'old_password',
        'new_password'
        })
    if not ok then
        common:response(0x000001, msg)
    end
    if args.old_password == args.new_password then
        common:response(0x010007)
    end
    local ok,user = auth:user()
    local password = args.old_password
    ok = user_service:verify_password(args.old_password, user.password)
    if not ok then
        -- password error
        common:response(0x010005)
    end
    local ok, err = User:where('id', '=', user.id):update({
        password=common:hash(args.new_password)
    })
    if not ok then
        common:response(0x000005)
    end
    ok, err = auth:clear_token()
    if not ok then
        common:response(0x010006)
    end
    common:response(0)
end

return _M

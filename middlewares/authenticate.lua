local auth_service = require("services.auth_service")
local common = require("lib.common")
local _M = {}

function _M:handle()
    if not auth_service:check() then
        common:response(4,'no authorized in authenticate')
    end
end

return _M
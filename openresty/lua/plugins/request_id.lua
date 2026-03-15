local _M = {}

_M.PRIORITY = 2000

function _M.access()
    local rid = ngx.var.request_id

    if not rid or rid == "" then
        rid = tostring(ngx.now()) .. "-" .. tostring(math.random(100000, 999999))
    end

    ngx.ctx.request_id = rid
    ngx.header["X-Request-Id"] = rid
end

return _M
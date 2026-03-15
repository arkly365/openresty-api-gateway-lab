local _M = {}

_M.PRIORITY = 50

function _M.header_filter()
    local route = ngx.ctx.route or "unknown"
    local request_id = ngx.ctx.request_id or "-"
    local app_env = os.getenv("APP_ENV") or "dev"

    ngx.header["X-Gateway-Route"] = route
    ngx.header["X-Gateway-Env"] = app_env
    ngx.header["X-Correlation-Id"] = request_id
	ngx.header["X-Selected-Upstream"] = ngx.ctx.selected_upstream
	ngx.header["X-Weighted-Mode"] = ngx.ctx.weighted_route_mode
	
	if ngx.ctx.canary_hit ~= nil then
		ngx.header["X-Canary-Hit"] = tostring(ngx.ctx.canary_hit)
	end

	if ngx.ctx.canary_mode then
		ngx.header["X-Canary-Mode"] = ngx.ctx.canary_mode
	end
	
	if ngx.ctx.canary_reason then
		ngx.header["X-Canary-Reason"] = ngx.ctx.canary_reason
	end
	
	if ngx.ctx.bg_active_color then
		ngx.header["X-BG-Active-Color"] = ngx.ctx.bg_active_color
	end

	if ngx.ctx.bg_selected_color then
		ngx.header["X-BG-Selected-Color"] = ngx.ctx.bg_selected_color
	end
	
	if ngx.ctx.shadow_enabled ~= nil then
		ngx.header["X-Shadow-Enabled"] = tostring(ngx.ctx.shadow_enabled)
	end

	if ngx.ctx.shadow_primary_upstream then
		ngx.header["X-Shadow-Primary-Upstream"] = ngx.ctx.shadow_primary_upstream
	end

	if ngx.ctx.shadow_upstream then
		ngx.header["X-Shadow-Upstream"] = ngx.ctx.shadow_upstream
	end
	
	if ngx.ctx.shadow_hit ~= nil then
        ngx.header["X-Shadow-Hit"] = tostring(ngx.ctx.shadow_hit)
    end

    if ngx.ctx.shadow_reason then
        ngx.header["X-Shadow-Reason"] = ngx.ctx.shadow_reason
    end

    if ngx.ctx.shadow_sample_rate ~= nil then
        ngx.header["X-Shadow-Sample-Rate"] = tostring(ngx.ctx.shadow_sample_rate)
    end
end

return _M
local _M = {}

_M.PRIORITY = 100

local dict = ngx.shared.metrics
local decision_ctx = require("decision_context")

local EXCLUDED_ROUTES = {
    ["metrics"] = true,
    ["metrics_reset"] = true,
    ["health"] = true,
    ["debug_ip"] = true,
    ["jwt_debug"] = true
}

local HISTOGRAM_BUCKETS = {1, 5, 10, 50, 100, 500}

local function escape_label_value(value)
    if value == nil then
        return ""
    end

    value = tostring(value)
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\"", "\\\"")
    return value
end

local function incr_safe(key, value)
    value = value or 1

    local new_val, err = dict:incr(key, value)
    if not new_val then
        local ok, add_err = dict:add(key, value)
        if not ok and add_err == "exists" then
            dict:incr(key, value)
        end
    end
end

local function set_safe(key, value)
    local ok, err = dict:set(key, value)
    if not ok then
        ngx.log(ngx.ERR, "[metrics] failed to set key=", key, ", err=", err or "unknown")
    end
end

local function get_status_class(status)
    local s = tonumber(status)
    if not s then
        return "unknown"
    end

    if s >= 200 and s < 300 then
        return "2xx"
    elseif s >= 300 and s < 400 then
        return "3xx"
    elseif s >= 400 and s < 500 then
        return "4xx"
    elseif s >= 500 and s < 600 then
        return "5xx"
    else
        return "other"
    end
end

local function get_decision()
    return decision_ctx.get()
end

local function first_non_nil(...)
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        if v ~= nil then
            return v
        end
    end
    return nil
end

local function parse_first_upstream_status(raw)
    if not raw or raw == "" then
        return nil
    end

    -- 可能長這樣: "200" 或 "502, 200"
    local first = tostring(raw):match("^%s*([^,%s]+)")
    return first
end

local function parse_first_upstream_response_time_ms(raw)
    if not raw or raw == "" or raw == "-" then
        return nil
    end

    -- 可能長這樣: "0.003" 或 "0.002, 0.005"
    local first = tostring(raw):match("^%s*([^,%s]+)")
    local sec = tonumber(first)
    if not sec then
        return nil
    end

    return sec * 1000
end

local function get_req_key(method, route, status)
    return "metrics:req:" .. method .. "|" .. route .. "|" .. status
end

local function get_err_key(route, status)
    return "metrics:err:" .. route .. "|" .. status
end

local function get_status_class_key(route, class)
    return "metrics:status_class:" .. route .. "|" .. class
end

local function get_latency_bucket_key(method, route, bucket)
    return "metrics:latency_bucket:" .. method .. "|" .. route .. "|" .. tostring(bucket)
end

local function get_latency_sum_key(method, route)
    return "metrics:latency_sum:" .. method .. "|" .. route
end

local function get_latency_count_key(method, route)
    return "metrics:latency_count:" .. method .. "|" .. route
end

local function get_upstream_status_key(route, upstream_status)
    return "metrics:upstream_status:" .. route .. "|" .. upstream_status
end

local function get_upstream_bucket_key(route, bucket)
    return "metrics:upstream_bucket:" .. route .. "|" .. tostring(bucket)
end

local function get_upstream_sum_key(route)
    return "metrics:upstream_sum:" .. route
end

local function get_upstream_count_key(route)
    return "metrics:upstream_count:" .. route
end

local function get_upstream_selected_key(route, upstream)
    return "metrics:upstream_selected:" .. route .. "|" .. upstream
end

local function get_cb_requests_key(route, state, fallback, upstream_mode)
    return "metrics:cb:req:" .. route .. "|" .. state .. "|" .. fallback .. "|" .. upstream_mode
end

local function get_cb_fallback_key(route)
    return "metrics:cb:fallback:" .. route
end

local function get_cb_half_open_key(route)
    return "metrics:cb:half_open:" .. route
end

local function get_cb_state_key(route, state)
    return "metrics:cb:state:" .. route .. "|" .. state
end

local function get_canary_requests_key(route, hit)
    return "metrics:canary_requests:" .. route .. "|" .. hit
end

local function get_canary_reason_key(route, reason)
    return "metrics:canary_reason:" .. route .. "|" .. reason
end

local function get_canary_mode_key(route, mode)
    return "metrics:canary_mode:" .. route .. "|" .. mode
end

local function get_canary_percentage_key(route)
    return "metrics:canary_percentage:" .. route
end

local function get_bg_requests_key(route, color)
    return "metrics:bg_requests:" .. route .. "|" .. color
end

local function get_bg_active_color_key(route, color)
    return "metrics:bg_active_color:" .. route .. "|" .. color
end

local function get_shadow_requests_key(route, primary_upstream, shadow_upstream)
    return "metrics:shadow_requests:" .. route .. "|" .. primary_upstream .. "|" .. shadow_upstream
end

local function get_shadow_enabled_key(route)
    return "metrics:shadow_enabled:" .. route
end

local function get_shadow_eligible_key(route)
    return "metrics:shadow_eligible:" .. route
end

local function get_shadow_sampled_key(route, primary_upstream, shadow_upstream)
    return "metrics:shadow_sampled:" .. route .. "|" .. primary_upstream .. "|" .. shadow_upstream
end

local function get_shadow_skipped_key(route, reason)
    return "metrics:shadow_skipped:" .. route .. "|" .. reason
end

local function get_shadow_sample_rate_key(route)
    return "metrics:shadow_sample_rate:" .. route
end

local function get_shadow_mirror_requests_key(route, shadow_upstream)
    return "metrics:shadow_mirror_requests:" .. route .. "|" .. shadow_upstream
end

local function get_shadow_mirror_status_key(route, shadow_upstream, status)
    return "metrics:shadow_mirror_status:" .. route .. "|" .. shadow_upstream .. "|" .. tostring(status)
end

local function get_shadow_mirror_failures_key(route, shadow_upstream, reason)
    return "metrics:shadow_mirror_failures:" .. route .. "|" .. shadow_upstream .. "|" .. reason
end

local function get_shadow_mirror_latency_sum_key(route, shadow_upstream)
    return "metrics:shadow_mirror_latency_sum:" .. route .. "|" .. shadow_upstream
end

local function get_shadow_mirror_latency_count_key(route, shadow_upstream)
    return "metrics:shadow_mirror_latency_count:" .. route .. "|" .. shadow_upstream
end

local function observe_histogram(method, route, latency_ms)
    for _, bucket in ipairs(HISTOGRAM_BUCKETS) do
        if latency_ms <= bucket then
            incr_safe(get_latency_bucket_key(method, route, bucket), 1)
        end
    end

    incr_safe(get_latency_bucket_key(method, route, "+Inf"), 1)
    incr_safe(get_latency_sum_key(method, route), latency_ms)
    incr_safe(get_latency_count_key(method, route), 1)
end

local function observe_upstream_histogram(route, latency_ms)
    for _, bucket in ipairs(HISTOGRAM_BUCKETS) do
        if latency_ms <= bucket then
            incr_safe(get_upstream_bucket_key(route, bucket), 1)
        end
    end

    incr_safe(get_upstream_bucket_key(route, "+Inf"), 1)
    incr_safe(get_upstream_sum_key(route), latency_ms)
    incr_safe(get_upstream_count_key(route), 1)
end

local function set_cb_state_gauge(route, current_state)
    local states = {"CLOSED", "OPEN", "HALF_OPEN"}

    for _, state in ipairs(states) do
        local value = 0
        if state == current_state then
            value = 1
        end
        set_safe(get_cb_state_key(route, state), value)
    end
end

function _M.access()
    local route = ngx.ctx.route or "unknown"

    if EXCLUDED_ROUTES[route] then
        return
    end

    ngx.ctx.metrics_enabled = true
    ngx.ctx.start_time = ngx.now()
end

local function get_traffic_decision()
    if type(ngx.ctx.traffic_decision) == "table" then
        return ngx.ctx.traffic_decision
    end
    return nil
end

local function first_non_nil(...)
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        if v ~= nil then
            return v
        end
    end
    return nil
end

function _M.log()
    if not ngx.ctx.metrics_enabled then
        return
    end

    local method = ngx.var.request_method or "UNKNOWN"
    --local route = ngx.ctx.route or "unknown"
    local status = tostring(ngx.status or 0)
    local status_class = get_status_class(status)
	
	local d = get_decision()
	local routing = d.routing or {}
	local shadow = d.shadow or {}

	local route = d.route or ngx.ctx.route or "unknown"

    -- request counter
    incr_safe(get_req_key(method, route, status), 1)

    -- status class counter
    incr_safe(get_status_class_key(route, status_class), 1)

    -- error counter
    if ngx.status >= 400 then
        incr_safe(get_err_key(route, status), 1)
    end

    -- gateway total latency
    local start_time = ngx.ctx.start_time
    if start_time then
        local latency_ms = (ngx.now() - start_time) * 1000
        observe_histogram(method, route, latency_ms)
    end

    -- upstream status
    local upstream_status = parse_first_upstream_status(ngx.var.upstream_status)
    if upstream_status then
        incr_safe(get_upstream_status_key(route, upstream_status), 1)
    end

    -- upstream response time
    local upstream_response_ms = parse_first_upstream_response_time_ms(ngx.var.upstream_response_time)
    if upstream_response_ms then
        observe_upstream_histogram(route, upstream_response_ms)
    end

    local td = get_traffic_decision()
    local routing = td and td.routing or nil
    local canary = routing and routing.canary or nil
    local bg = routing and routing.blue_green or nil
    local shadow = td and td.shadow or nil

    -- selected upstream counter
    local selected_upstream = first_non_nil(
        routing and routing.selected_upstream,
        ngx.ctx.selected_upstream
    )
    if selected_upstream and selected_upstream ~= "" then
        incr_safe(get_upstream_selected_key(route, selected_upstream), 1)
    end
	
	local canary_hit = first_non_nil(routing.canary_hit, ngx.ctx.canary_hit)
	local canary_reason = first_non_nil(routing.canary_reason, ngx.ctx.canary_reason)
	local canary_mode = first_non_nil(routing.canary_mode, ngx.ctx.canary_mode)
	local canary_percentage = first_non_nil(routing.canary_percentage, ngx.ctx.canary_percentage)

	local bg_selected_color = first_non_nil(routing.bg_selected_color, ngx.ctx.bg_selected_color)
	local bg_active_color = first_non_nil(routing.bg_active_color, ngx.ctx.bg_active_color)

	local shadow_eligible = first_non_nil(shadow.eligible, ngx.ctx.shadow_eligible)
	local shadow_enabled = first_non_nil(shadow.enabled, ngx.ctx.shadow_enabled)
	local shadow_reason = first_non_nil(shadow.reason, ngx.ctx.shadow_reason)
	local shadow_sample_rate = first_non_nil(shadow.sample_rate, ngx.ctx.shadow_sample_rate)
	local shadow_primary_upstream = first_non_nil(shadow.primary_upstream, ngx.ctx.shadow_primary_upstream, "-")
	local shadow_upstream = first_non_nil(shadow.upstream, ngx.ctx.shadow_upstream, "-")

end


function _M.record_shadow_mirror_result(route, shadow_upstream, status, latency_ms, failure_reason)
    route = tostring(route or "unknown")
    shadow_upstream = tostring(shadow_upstream or "-")
    status = tonumber(status or 0) or 0
    latency_ms = tonumber(latency_ms or 0) or 0

    incr_safe(get_shadow_mirror_requests_key(route, shadow_upstream), 1)
    incr_safe(get_shadow_mirror_status_key(route, shadow_upstream, status), 1)

    if latency_ms >= 0 then
        incr_safe(get_shadow_mirror_latency_sum_key(route, shadow_upstream), latency_ms)
        incr_safe(get_shadow_mirror_latency_count_key(route, shadow_upstream), 1)
    end

    if failure_reason then
        incr_safe(get_shadow_mirror_failures_key(route, shadow_upstream, failure_reason), 1)
        return
    end

    if status >= 500 then
        incr_safe(get_shadow_mirror_failures_key(route, shadow_upstream, "5xx"), 1)
    elseif status >= 400 then
        incr_safe(get_shadow_mirror_failures_key(route, shadow_upstream, "4xx"), 1)
    end
end

function _M.prometheus_output()
    ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"

    local lines = {}
    local keys = dict:get_keys(0)
    table.sort(keys)

    -- request total
    table.insert(lines, "# HELP gateway_http_requests_total Total number of HTTP requests")
    table.insert(lines, "# TYPE gateway_http_requests_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:req:") then
            local raw = key:gsub("^metrics:req:", "")
            local method, route, status = raw:match("^([^|]+)|([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if method and route and status then
                table.insert(
                    lines,
                    string.format(
                        'gateway_http_requests_total{method="%s",route="%s",status="%s"} %s',
                        escape_label_value(method),
                        escape_label_value(route),
                        escape_label_value(status),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- errors total
    table.insert(lines, "# HELP gateway_http_errors_total Total number of HTTP error responses")
    table.insert(lines, "# TYPE gateway_http_errors_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:err:") then
            local raw = key:gsub("^metrics:err:", "")
            local route, status = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and status then
                table.insert(
                    lines,
                    string.format(
                        'gateway_http_errors_total{route="%s",status="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(status),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- status class total
    table.insert(lines, "# HELP gateway_http_status_class_total Total number of HTTP responses grouped by status class")
    table.insert(lines, "# TYPE gateway_http_status_class_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:status_class:") then
            local raw = key:gsub("^metrics:status_class:", "")
            local route, class = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and class then
                table.insert(
                    lines,
                    string.format(
                        'gateway_http_status_class_total{route="%s",class="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(class),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- gateway total latency histogram
    table.insert(lines, "# HELP gateway_http_request_duration_ms Request latency histogram in milliseconds")
    table.insert(lines, "# TYPE gateway_http_request_duration_ms histogram")

    for _, key in ipairs(keys) do
        if key:match("^metrics:latency_bucket:") then
            local raw = key:gsub("^metrics:latency_bucket:", "")
            local method, route, bucket = raw:match("^([^|]+)|([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if method and route and bucket then
                table.insert(
                    lines,
                    string.format(
                        'gateway_http_request_duration_ms_bucket{method="%s",route="%s",le="%s"} %s',
                        escape_label_value(method),
                        escape_label_value(route),
                        escape_label_value(bucket),
                        tostring(value)
                    )
                )
            end
        end
    end

    for _, key in ipairs(keys) do
        if key:match("^metrics:latency_sum:") then
            local raw = key:gsub("^metrics:latency_sum:", "")
            local method, route = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if method and route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_http_request_duration_ms_sum{method="%s",route="%s"} %s',
                        escape_label_value(method),
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end

    for _, key in ipairs(keys) do
        if key:match("^metrics:latency_count:") then
            local raw = key:gsub("^metrics:latency_count:", "")
            local method, route = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if method and route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_http_request_duration_ms_count{method="%s",route="%s"} %s',
                        escape_label_value(method),
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- upstream status total
    table.insert(lines, "# HELP gateway_upstream_status_total Total number of upstream responses grouped by upstream status")
    table.insert(lines, "# TYPE gateway_upstream_status_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:upstream_status:") then
            local raw = key:gsub("^metrics:upstream_status:", "")
            local route, upstream_status = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and upstream_status then
                table.insert(
                    lines,
                    string.format(
                        'gateway_upstream_status_total{route="%s",upstream_status="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(upstream_status),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- upstream response histogram
    table.insert(lines, "# HELP gateway_upstream_response_ms Upstream response time histogram in milliseconds")
    table.insert(lines, "# TYPE gateway_upstream_response_ms histogram")

    for _, key in ipairs(keys) do
        if key:match("^metrics:upstream_bucket:") then
            local raw = key:gsub("^metrics:upstream_bucket:", "")
            local route, bucket = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and bucket then
                table.insert(
                    lines,
                    string.format(
                        'gateway_upstream_response_ms_bucket{route="%s",le="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(bucket),
                        tostring(value)
                    )
                )
            end
        end
    end

    for _, key in ipairs(keys) do
        if key:match("^metrics:upstream_sum:") then
            local raw = key:gsub("^metrics:upstream_sum:", "")
            local route = raw:match("^([^|]+)$")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_upstream_response_ms_sum{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end

    for _, key in ipairs(keys) do
        if key:match("^metrics:upstream_count:") then
            local raw = key:gsub("^metrics:upstream_count:", "")
            local route = raw:match("^([^|]+)$")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_upstream_response_ms_count{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- selected upstream total
    table.insert(lines, "# HELP gateway_upstream_selected_total Total number of selected upstreams")
    table.insert(lines, "# TYPE gateway_upstream_selected_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:upstream_selected:") then
            local raw = key:gsub("^metrics:upstream_selected:", "")
            local route, upstream = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and upstream then
                table.insert(
                    lines,
                    string.format(
                        'gateway_upstream_selected_total{route="%s",upstream="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(upstream),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- canary requests total
    table.insert(lines, "# HELP gateway_canary_requests_total Total number of canary requests")
    table.insert(lines, "# TYPE gateway_canary_requests_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:canary_requests:") then
            local raw = key:gsub("^metrics:canary_requests:", "")
            local route, hit = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and hit then
                table.insert(
                    lines,
                    string.format(
                        'gateway_canary_requests_total{route="%s",hit="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(hit),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- canary mode total
    table.insert(lines, "# HELP gateway_canary_mode_total Total number of canary requests grouped by mode")
    table.insert(lines, "# TYPE gateway_canary_mode_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:canary_mode:") then
            local raw = key:gsub("^metrics:canary_mode:", "")
            local route, mode = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and mode then
                table.insert(
                    lines,
                    string.format(
                        'gateway_canary_mode_total{route="%s",mode="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(mode),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- canary reason total
    table.insert(lines, "# HELP gateway_canary_reason_total Total number of canary requests grouped by reason")
    table.insert(lines, "# TYPE gateway_canary_reason_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:canary_reason:") then
            local raw = key:gsub("^metrics:canary_reason:", "")
            local route, reason = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and reason then
                table.insert(
                    lines,
                    string.format(
                        'gateway_canary_reason_total{route="%s",reason="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(reason),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- canary percentage gauge
    table.insert(lines, "# HELP gateway_canary_percentage Current configured canary percentage")
    table.insert(lines, "# TYPE gateway_canary_percentage gauge")

    for _, key in ipairs(keys) do
        if key:match("^metrics:canary_percentage:") then
            local route = key:gsub("^metrics:canary_percentage:", "")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_canary_percentage{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")
	
	--blue_green requests total
    table.insert(lines, "# HELP gateway_blue_green_requests_total Total number of blue/green routed requests")
    table.insert(lines, "# TYPE gateway_blue_green_requests_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:bg_requests:") then
            local raw = key:gsub("^metrics:bg_requests:", "")
            local route, color = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and color then
                table.insert(
                    lines,
                    string.format(
                        'gateway_blue_green_requests_total{route="%s",color="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(color),
                        tostring(value)
                    )
                )
            end
        end
    end
	table.insert(lines, "")
	
	--blue_green active_color gauge
    table.insert(lines, "# HELP gateway_blue_green_active_color Current blue/green active color gauge")
    table.insert(lines, "# TYPE gateway_blue_green_active_color gauge")

    for _, key in ipairs(keys) do
        if key:match("^metrics:bg_active_color:") then
            local raw = key:gsub("^metrics:bg_active_color:", "")
            local route, color = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and color then
                table.insert(
                    lines,
                    string.format(
                        'gateway_blue_green_active_color{route="%s",color="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(color),
                        tostring(value)
                    )
                )
            end
        end
    end
	table.insert(lines, "")
	
	
	--shadow_requests total
    table.insert(lines, "# HELP gateway_shadow_requests_total Total number of requests with shadow traffic enabled")
    table.insert(lines, "# TYPE gateway_shadow_requests_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_requests:") then
            local raw = key:gsub("^metrics:shadow_requests:", "")
            local route, primary_upstream, shadow_upstream = raw:match("^([^|]+)|([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and primary_upstream and shadow_upstream then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_requests_total{route="%s",primary_upstream="%s",shadow_upstream="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(primary_upstream),
                        escape_label_value(shadow_upstream),
                        tostring(value)
                    )
                )
            end
        end
    end
	table.insert(lines, "")
	
	
	--gateway_shadow_enabled gauge    
    table.insert(lines, "# HELP gateway_shadow_enabled Whether shadow traffic is enabled for the route")
    table.insert(lines, "# TYPE gateway_shadow_enabled gauge")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_enabled:") then
            local route = key:gsub("^metrics:shadow_enabled:", "")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_enabled{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end
	table.insert(lines, "")
	
	--gateway_shadow_eligible Total
	table.insert(lines, "# HELP gateway_shadow_eligible_total Total number of shadow-eligible requests")
    table.insert(lines, "# TYPE gateway_shadow_eligible_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_eligible:") then
            local route = key:gsub("^metrics:shadow_eligible:", "")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_eligible_total{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	--gateway_shadow_sampled_total
	table.insert(lines, "# HELP gateway_shadow_sampled_total Total number of sampled shadow requests")
    table.insert(lines, "# TYPE gateway_shadow_sampled_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_sampled:") then
            local raw = key:gsub("^metrics:shadow_sampled:", "")
            local route, primary_upstream, shadow_upstream = raw:match("^([^|]+)|([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and primary_upstream and shadow_upstream then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_sampled_total{route="%s",primary_upstream="%s",shadow_upstream="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(primary_upstream),
                        escape_label_value(shadow_upstream),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	--gateway_shadow_skipped_total reason
	table.insert(lines, "# HELP gateway_shadow_skipped_total Total number of skipped shadow requests grouped by reason")
    table.insert(lines, "# TYPE gateway_shadow_skipped_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_skipped:") then
            local raw = key:gsub("^metrics:shadow_skipped:", "")
            local route, reason = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and reason then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_skipped_total{route="%s",reason="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(reason),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	--gateway_shadow_sample_rate gauge
	table.insert(lines, "# HELP gateway_shadow_sample_rate Current configured shadow sample rate")
    table.insert(lines, "# TYPE gateway_shadow_sample_rate gauge")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_sample_rate:") then
            local route = key:gsub("^metrics:shadow_sample_rate:", "")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_sample_rate{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	--mirror requests total
	table.insert(lines, "# HELP gateway_shadow_mirror_requests_total Total number of executed shadow mirror requests")
    table.insert(lines, "# TYPE gateway_shadow_mirror_requests_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_mirror_requests:") then
            local raw = key:gsub("^metrics:shadow_mirror_requests:", "")
            local route, shadow_upstream = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and shadow_upstream then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_mirror_requests_total{route="%s",shadow_upstream="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(shadow_upstream),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	--mirror status total
	table.insert(lines, "# HELP gateway_shadow_mirror_status_total Total number of shadow mirror responses grouped by status")
    table.insert(lines, "# TYPE gateway_shadow_mirror_status_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_mirror_status:") then
            local raw = key:gsub("^metrics:shadow_mirror_status:", "")
            local route, shadow_upstream, status = raw:match("^([^|]+)|([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and shadow_upstream and status then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_mirror_status_total{route="%s",shadow_upstream="%s",status="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(shadow_upstream),
                        escape_label_value(status),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	--mirror failures total
	table.insert(lines, "# HELP gateway_shadow_mirror_failures_total Total number of shadow mirror failures grouped by reason")
    table.insert(lines, "# TYPE gateway_shadow_mirror_failures_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_mirror_failures:") then
            local raw = key:gsub("^metrics:shadow_mirror_failures:", "")
            local route, shadow_upstream, reason = raw:match("^([^|]+)|([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and shadow_upstream and reason then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_mirror_failures_total{route="%s",shadow_upstream="%s",reason="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(shadow_upstream),
                        escape_label_value(reason),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	
	--mirror latency sum
	table.insert(lines, "# HELP gateway_shadow_mirror_latency_ms_sum Sum of shadow mirror latency in ms")
    table.insert(lines, "# TYPE gateway_shadow_mirror_latency_ms_sum counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_mirror_latency_sum:") then
            local raw = key:gsub("^metrics:shadow_mirror_latency_sum:", "")
            local route, shadow_upstream = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and shadow_upstream then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_mirror_latency_ms_sum{route="%s",shadow_upstream="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(shadow_upstream),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")
	
	--mirror latency count
	table.insert(lines, "# HELP gateway_shadow_mirror_latency_ms_count Count of shadow mirror latency samples")
    table.insert(lines, "# TYPE gateway_shadow_mirror_latency_ms_count counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:shadow_mirror_latency_count:") then
            local raw = key:gsub("^metrics:shadow_mirror_latency_count:", "")
            local route, shadow_upstream = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and shadow_upstream then
                table.insert(
                    lines,
                    string.format(
                        'gateway_shadow_mirror_latency_ms_count{route="%s",shadow_upstream="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(shadow_upstream),
                        tostring(value)
                    )
                )
            end
        end
    end
    table.insert(lines, "")

    -- circuit breaker requests total
    table.insert(lines, "# HELP gateway_cb_requests_total Total number of circuit breaker observed requests")
    table.insert(lines, "# TYPE gateway_cb_requests_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:cb:req:") then
            local raw = key:gsub("^metrics:cb:req:", "")
            local route, state, fallback, upstream_mode = raw:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and state and fallback and upstream_mode then
                table.insert(
                    lines,
                    string.format(
                        'gateway_cb_requests_total{route="%s",state="%s",fallback="%s",upstream_mode="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(state),
                        escape_label_value(fallback),
                        escape_label_value(upstream_mode),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- circuit breaker fallback total
    table.insert(lines, "# HELP gateway_cb_fallback_total Total number of circuit breaker fallback requests")
    table.insert(lines, "# TYPE gateway_cb_fallback_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:cb:fallback:") then
            local route = key:gsub("^metrics:cb:fallback:", "")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_cb_fallback_total{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- circuit breaker half-open total
    table.insert(lines, "# HELP gateway_cb_half_open_total Total number of half-open probe requests")
    table.insert(lines, "# TYPE gateway_cb_half_open_total counter")

    for _, key in ipairs(keys) do
        if key:match("^metrics:cb:half_open:") then
            local route = key:gsub("^metrics:cb:half_open:", "")
            local value = dict:get(key) or 0

            if route then
                table.insert(
                    lines,
                    string.format(
                        'gateway_cb_half_open_total{route="%s"} %s',
                        escape_label_value(route),
                        tostring(value)
                    )
                )
            end
        end
    end

    table.insert(lines, "")

    -- circuit breaker state gauge
    table.insert(lines, "# HELP gateway_cb_state Current circuit breaker state gauge (1 means current state)")
    table.insert(lines, "# TYPE gateway_cb_state gauge")

    for _, key in ipairs(keys) do
        if key:match("^metrics:cb:state:") then
            local raw = key:gsub("^metrics:cb:state:", "")
            local route, state = raw:match("^([^|]+)|([^|]+)$")
            local value = dict:get(key) or 0

            if route and state then
                table.insert(
                    lines,
                    string.format(
                        'gateway_cb_state{route="%s",state="%s"} %s',
                        escape_label_value(route),
                        escape_label_value(state),
                        tostring(value)
                    )
                )
            end
        end
    end

    ngx.say(table.concat(lines, "\n"))
end

function _M.reset()
    dict:flush_all()
    dict:flush_expired()

    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say('{"message":"metrics reset ok"}')
end

return _M
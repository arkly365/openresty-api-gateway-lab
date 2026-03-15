local _M = {}

local route_config = require("route_config")

local ALLOWED_PHASES = {
    rewrite = true,
    access = true,
    header_filter = true,
    log = true
}

local function load_plugin(plugin_name)
    local ok, plugin = pcall(require, "plugins." .. plugin_name)
    if not ok then
        ngx.log(ngx.ERR, "[plugin_runner] failed to load plugin: ", plugin_name, ", err: ", plugin)
        return nil
    end

    return plugin
end

local function get_plugin_chain()
    local route = ngx.ctx.route or "unknown"
    return route_config.get_plugins(route)
end

local function build_sorted_plugins(plugin_names)
    local result = {}

    for _, plugin_name in ipairs(plugin_names) do
        local plugin = load_plugin(plugin_name)
        if plugin then
            table.insert(result, {
                name = plugin_name,
                handler = plugin,
                priority = tonumber(plugin.PRIORITY) or 0
            })
        end
    end

    table.sort(result, function(a, b)
        return a.priority > b.priority
    end)

    return result
end

local function run_phase(phase_name)
    if not ALLOWED_PHASES[phase_name] then
        ngx.log(ngx.ERR, "[plugin_runner] unsupported phase: ", tostring(phase_name))
        return
    end

    local plugin_chain = get_plugin_chain()

    if not plugin_chain or type(plugin_chain) ~= "table" then
        return
    end

    local plugins = build_sorted_plugins(plugin_chain)

    for _, item in ipairs(plugins) do
        local plugin_name = item.name
        local plugin = item.handler

        if type(plugin[phase_name]) == "function" then
            local ok, err = pcall(plugin[phase_name])
            if not ok then
                ngx.log(
                    ngx.ERR,
                    "[plugin_runner] plugin phase error, plugin=",
                    plugin_name,
                    ", phase=",
                    phase_name,
                    ", err=",
                    err
                )
            end
        end
    end
end

function _M.run_rewrite()
    run_phase("rewrite")
end

function _M.run_access()
    run_phase("access")
	
	local route_name = ngx.ctx.route
    if not route_name then
        return
    end

    if not ngx.ctx.selected_upstream or ngx.ctx.selected_upstream == "" then
        local default_upstream = route_config.get_upstream(route_name)
        if default_upstream and default_upstream ~= "" then
            ngx.ctx.selected_upstream = default_upstream
        end
    end
end

function _M.run_header_filter()
    run_phase("header_filter")
end

function _M.run_log()
    run_phase("log")
end

return _M
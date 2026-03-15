local _M = {}

local function default_timeout()
    return {
        connect_ms = 1000,
        send_ms = 1000,
        read_ms = 2000
    }
end

_M.ROUTES = {
    svc_a = {
        upstream = "backend_a",
        plugins = {"request_id", "ip_acl", "jwt_auth", "rate_limit", "metrics", "response_meta", "logger"},
        policies = {
            auth = "jwt",
            rate_limit = {
                limit = 5,
                window = 10
            },
            timeout = default_timeout()
        }
    },

    svc_a_weighted = {
        upstream = "backend_a",
        plugins = {"request_id", "traffic_router", "metrics", "response_meta", "logger"},
        policies = {
            timeout = default_timeout(),
            traffic = {
                enabled = true,
                routing = {
                    strategy = "weighted",
                    primary_upstream = "backend_a",
                    weighted = {
                        mode = "random",
                        targets = {
                            { upstream = "backend_a", weight = 80 },
                            { upstream = "backend_b", weight = 20 }
                        }
                    }
                },
                shadow = {
                    enabled = false
                }
            }
        }
    },

    svc_a_canary = {
        upstream = "backend_a",
        plugins = {"request_id", "traffic_router", "metrics", "response_meta", "logger"},
        policies = {
            timeout = default_timeout(),
            traffic = {
                enabled = true,
                routing = {
                    strategy = "canary",
                    primary_upstream = "backend_a",
                    canary = {
                        mode = "header",
                        stable_upstream = "backend_a",
                        canary_upstream = "backend_b",
                        header = {
                            name = "X-Canary",
                            value = "always"
                        }
                    }
                },
                shadow = {
                    enabled = false
                }
            }
        }
    },

    svc_a_canary_pct = {
        upstream = "backend_a",
        plugins = {"request_id", "traffic_router", "metrics", "response_meta", "logger"},
        policies = {
            timeout = default_timeout(),
            traffic = {
                enabled = true,
                routing = {
                    strategy = "canary",
                    primary_upstream = "backend_a",
                    canary = {
                        mode = "percentage",
                        stable_upstream = "backend_a",
                        canary_upstream = "backend_b",
                        percentage = 10
                    }
                },
                shadow = {
                    enabled = false
                }
            }
        }
    },

    svc_a_canary_hybrid = {
        upstream = "backend_a",
        plugins = {"request_id", "traffic_router", "metrics", "response_meta", "logger"},
        policies = {
            timeout = default_timeout(),
            traffic = {
                enabled = true,
                routing = {
                    strategy = "canary",
                    primary_upstream = "backend_a",
                    canary = {
                        mode = "hybrid",
                        stable_upstream = "backend_a",
                        canary_upstream = "backend_b",
                        percentage = 10,
                        header = {
                            name = "X-Canary",
                            value = "always"
                        }
                    }
                },
                shadow = {
                    enabled = false
                }
            }
        }
    },

    svc_a_bluegreen = {
        upstream = "backend_a",
        plugins = {"request_id", "traffic_router", "metrics", "response_meta", "logger"},
        policies = {
            timeout = default_timeout(),
            traffic = {
                enabled = true,
                routing = {
                    strategy = "blue_green",
                    primary_upstream = "backend_a",
                    blue_green = {
                        active_color = "green",
                        mappings = {
                            blue = "backend_a",
                            green = "backend_b"
                        }
                    }
                },
                shadow = {
                    enabled = false
                }
            }
        }
    },

    svc_a_shadow = {
        upstream = "backend_a",
        plugins = {
            "request_id",
            "traffic_router",
            "shadow_routing",
            "response_meta",
            "metrics",
            "shadow_executor",
            "logger"
        },
        policies = {
            timeout = default_timeout(),
            traffic = {
                enabled = true,
                routing = {
                    strategy = "direct",
                    primary_upstream = "backend_a"
                },
                shadow = {
                    enabled = true,
                    upstream = "backend-echo",
                    sample_rate = 1.0,
                    methods = {"GET"},
                    header_match = nil
                }
            }
        }
    },

    svc_b = {
        upstream = "backend_b",
        plugins = {"request_id", "ip_acl", "api_key", "metrics", "response_meta", "logger"},
        policies = {
            auth = "api_key",
            timeout = default_timeout()
        }
    },

    svc_slow = {
        upstream = "slow_backend",
        plugins = {"request_id", "metrics", "response_meta", "logger"},
        policies = {
            timeout = default_timeout(),
            retry = {
                enabled = true,
                tries = 2,
                conditions = {"error", "timeout", "http_502", "http_503", "http_504"},
                methods = {"GET"}
            }
        }
    },

    svc_failover = {
        upstream = "retry_failover_pool",
        plugins = {"request_id", "circuit_breaker", "metrics", "response_meta", "logger"},
        policies = {
            timeout = default_timeout(),
            retry = {
                enabled = true,
                tries = 2,
                conditions = {"error", "timeout", "http_502", "http_503", "http_504"},
                methods = {"GET"}
            },
            circuit_breaker = {
                enabled = true,
                failure_threshold = 2,
                recovery_timeout = 15,
                failure_window = 30
            }
        }
    },

    health = {
        plugins = {},
        policies = {}
    },

    metrics = {
        plugins = {},
        policies = {}
    },

    metrics_reset = {
        plugins = {},
        policies = {}
    }
}

function _M.get_route(route_name)
    if not route_name then
        return nil
    end
    return _M.ROUTES[route_name]
end

function _M.get_plugins(route_name)
    local route = _M.get_route(route_name)
    if not route then
        return {}
    end
    return route.plugins or {}
end

function _M.get_policies(route_name)
    local route = _M.get_route(route_name)
    if not route then
        return {}
    end
    return route.policies or {}
end

function _M.get_policy(route_name, policy_name)
    local policies = _M.get_policies(route_name)
    return policies[policy_name]
end

function _M.get_traffic_policy(route_name)
    local policies = _M.get_policies(route_name)
    return policies.traffic
end

function _M.get_routing_policy(route_name)
    local traffic = _M.get_traffic_policy(route_name)
    if type(traffic) ~= "table" then
        return nil
    end
    return traffic.routing
end

function _M.get_shadow_policy(route_name)
    local traffic = _M.get_traffic_policy(route_name)
    if type(traffic) ~= "table" then
        return nil
    end
    return traffic.shadow
end

function _M.get_default_upstream(route_name)
    local route = _M.get_route(route_name)
    if not route then
        return nil
    end
    return route.upstream
end

function _M.get_upstream(route_name)
    return _M.get_default_upstream(route_name)
end

return _M
# Design Decisions

This document explains the key design decisions behind the architecture of the **OpenResty API Gateway Lab**.

The purpose of this document is to clarify **why certain architectural choices were made**, and what trade-offs were considered.

This lab focuses on understanding gateway internals by implementing simplified versions of components commonly found in production API gateways.

---

# 1. Why OpenResty

The gateway is implemented using **OpenResty**, which extends NGINX with Lua scripting.

OpenResty provides several advantages for building a programmable gateway:

- high performance event-driven architecture
- tight integration with NGINX request lifecycle
- ability to inject custom Lua logic into request phases
- mature ecosystem for networking and HTTP processing

OpenResty allows building gateway logic without modifying the NGINX core.

This makes it possible to implement advanced gateway behaviors such as:

- request routing
- traffic shaping
- authentication
- observability instrumentation

Many production API gateways use this model, including:

- Kong
- Apache APISIX

---

# 2. Why a Plugin-Based Architecture

Instead of implementing all gateway logic in a single file, the gateway uses a **plugin-based architecture**.

This design provides several benefits:

- modular gateway features
- clear separation of concerns
- easier experimentation with traffic strategies
- easier extensibility

Each gateway capability is implemented as a plugin module.

Examples include:

- traffic routing
- rate limiting
- metrics collection
- shadow execution

The plugin runner executes these modules during request processing.

This approach is inspired by the plugin systems used in real API gateways.

---

# 3. Why Separate Policy Engine and Traffic Router

The architecture separates **policy evaluation** from **traffic execution**.

Components:

Policy Engine  
Traffic Router

The policy engine is responsible for evaluating:

- routing rules
- canary decisions
- blue/green selection
- shadow traffic rules

The traffic router then executes the final decision.

Benefits of this separation include:

- clearer system responsibilities
- easier debugging of routing logic
- easier extension of routing strategies
- improved maintainability

This design mirrors control-plane vs data-plane separation found in modern gateways.

---

# 4. Why Use a Shared Decision Context

Gateway plugins need to exchange routing decisions and request metadata.

Instead of tightly coupling plugins, a shared context object is used.

The decision context is stored in:


ngx.ctx.decision


This context may contain:

- selected upstream
- traffic routing decision
- shadow routing status
- request identifiers

Using `ngx.ctx` allows sharing request-scoped state safely across plugins.

This avoids global variables and keeps plugins loosely coupled.

---

# 5. Why Traffic Routing is Implemented as Policies

Traffic routing strategies are implemented as configurable policies.

Examples include:

- weighted routing
- canary routing
- blue/green deployment
- shadow traffic

Implementing routing as policies allows the gateway to support multiple traffic control strategies without changing core logic.

This design makes it easier to experiment with new routing behaviors.

It also reflects real-world gateway behavior where traffic policies are dynamically configurable.

---

# 6. Why Shadow Traffic is Executed Asynchronously

Shadow traffic mirrors requests to a secondary upstream service.

However, shadow execution is performed **asynchronously**.

Reason:

The client response must not be delayed by shadow execution.

If shadow traffic were synchronous:

- user latency would increase
- upstream instability could affect production traffic

Therefore shadow execution is designed as a fire-and-forget operation.

This mirrors the behavior of production systems that use traffic mirroring for safe experimentation.

---

# 7. Why Reliability Patterns Are Implemented at the Gateway

The gateway implements several resilience patterns:

- timeout protection
- retry policy
- failover routing
- circuit breaker

Implementing these patterns at the gateway provides several benefits:

- protection for unstable upstream services
- centralized resilience logic
- reduced complexity in backend services

In production environments, resilience mechanisms may exist at multiple layers.

However, placing them at the gateway allows early traffic control and improved system stability.

---

# 8. Why Prometheus Metrics Are Used for Observability

The gateway exposes metrics in **Prometheus format**.

Reasons for choosing Prometheus metrics include:

- wide adoption in cloud-native systems
- simple pull-based monitoring model
- compatibility with Grafana dashboards
- easy integration with container environments

Metrics exported include:

- request counters
- upstream latency
- routing decision metrics
- shadow traffic metrics

This allows monitoring gateway behavior during experiments and tests.

---

# 9. Why This Project Uses Docker Compose

The lab environment is implemented using **Docker Compose**.

Reasons include:

- simple local development environment
- easy simulation of multiple upstream services
- reproducible testing environment
- minimal infrastructure requirements

Docker Compose allows running:

- gateway container
- backend services
- observability stack

with a single command.

This keeps the focus on gateway architecture rather than infrastructure complexity.

---

# 10. Why This Project Focuses on Learning Rather Than Feature Completeness

This project intentionally focuses on architectural understanding rather than implementing a production-ready gateway.

Goals include:

- understanding NGINX request lifecycle
- learning OpenResty plugin development
- exploring traffic routing strategies
- implementing reliability patterns
- building observability instrumentation

The system is designed as a **learning-oriented gateway lab** rather than a fully-featured gateway product.

---

# Summary

The design of this gateway lab follows several key principles:

- modular plugin architecture
- policy-driven traffic routing
- loosely coupled gateway components
- observable request processing
- resilience patterns at the gateway layer

These decisions aim to provide insight into how production API gateways are designed while keeping the implementation accessible for experimentation.

專案敘事

本專案是一個以 **OpenResty + Lua** 為核心實作的 API Gateway 學習與實驗專案，目的是透過「從零開始實作 Gateway 核心能力」，深入理解現代 API Gateway 的架構與運作模式。

專案採用 **Lua Plugin Architecture**，模擬實務環境中的 Gateway 設計，實作多種流量控制與可靠性機制，包括：

- Weighted Routing
- Canary Release
- Blue/Green Deployment
- Shadow Traffic（Traffic Mirroring）
- Retry / Failover
- Circuit Breaker
- Prometheus Metrics Observability

Gateway 以 **OpenResty (NGINX + Lua)** 為核心，並透過 Docker 建立可重現的實驗環境，同時提供 Prometheus 相容的 metrics 以模擬生產環境中的 observability 架構。

此專案的目標不只是完成一個 Demo，而是透過實作以下工程概念：

- API Gateway 架構設計
- NGINX / OpenResty request lifecycle
- Plugin-based gateway extension
- Policy-driven traffic management
- Gateway reliability engineering
- Metrics-driven observability

透過本專案，我深入理解現代 Gateway 系統（如 Kong、Apache APISIX、Envoy）背後的設計理念，並將其核心概念以可實驗、可閱讀的方式實作於此 Lab 中。

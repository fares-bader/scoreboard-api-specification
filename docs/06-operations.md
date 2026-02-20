<div align="center">

| [← Exection Flows](05-execution-flows.md) | [Next: Improvments →](07-improvements.md) |
</div>


# 6. Operational Considerations

## 6.1 Infrastructure Requirements

| Component | Specification | Quantity |
|-------------|--------------|----------|
| API Servers | 4 vCPU, 8GB RAM | 3+ instances |
| PostgreSQL | 8 vCPU, 16GB RAM | 1 primary + 1 replica |
| Redis | 4 vCPU, 8GB RAM | 3-node cluster |
| Load Balancer | Application layer (ALB/NGINX) | 2 for HA |

## 6.2 Deployment Configuration

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:pass@primary:5432/scoreboard
DATABASE_REPLICA_URL=postgresql://user:pass@replica:5432/scoreboard

# Redis
REDIS_CLUSTER_NODES=redis-1:6379,redis-2:6379,redis-3:6379

# Security
JWT_PUBLIC_KEY_PATH=/secrets/jwt.pub
HMAC_SECRET_PATH=/secrets/hmac.key
RATE_LIMIT_ACTIONS_PER_MINUTE=10

# Monitoring
DATADOG_API_KEY=...
SENTRY_DSN=...
```
### Health Check Endpoints

```bash
GET /health/live     # Liveness (Kubernetes)
GET /health/ready    # Readiness (DB/Redis connection)
GET /health/metrics  # Prometheus metrics
```

## 6.3 Monitoring & Alerting

| Metric                | Warning  | Critical  | Action             |
| --------------------- | -------- | --------- | ------------------ |
| API latency p99       | >200ms   | >500ms    | Scale horizontally |
| Error rate            | >0.1%    | >1%       | Page on-call       |
| Redis memory          | >70%     | >85%      | Scale cluster      |
| DB connections        | >80%     | >95%      | Increase pool size |
| WebSocket connections | >8k/node | >10k/node | Add nodes          |

### Key Dashboards
 - API Performance: RPS, latency, error rate by endpoint
 - Data Flow: Redis cache hit rate, DB query duration
 - Business Metrics: Actions/minute, score distribution
 - Security: Failed HMAC attempts, rate limit triggers

## 6.4 Backup & Recovery

| Data          | Method                       | RTO    | RPO           |
| ------------- | ---------------------------- | ------ | ------------- |
| PostgreSQL    | Continuous archiving + PITR  | 15 min | 5 min         |
| Redis         | RDB snapshots every 6h + AOF | 30 min | 1 min         |
| Configuration | Git repository               | 5 min  | 0 (immutable) |

### Disaster Recovery Steps

 - Database failure: Promote replica, update DNS
 - Redis failure: Rebuild from PostgreSQL (scripted)
 - API server failure: Kubernetes auto-replacement
 - Complete region failure: Multi-region failover (async replication)
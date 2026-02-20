<div align="center">

| [← Overview](01-overview.md) | [Next: Api Reference →](03-api-reference.md) |
</div>

# 2. Data Model

## 2.1 PostgreSQL Schema

### Users Table
Primary user profile with denormalized score cache.

```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(32) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    current_score INTEGER NOT NULL DEFAULT 0,
    total_actions INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_score ON users(current_score DESC);
```
### Action Events Table
Immutable audit trail of all score-changing actions.

```sql 
CREATE TABLE action_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    action_type VARCHAR(50) NOT NULL,
    action_idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    payload_hash VARCHAR(64) NOT NULL,
    points_awarded INTEGER NOT NULL,
    client_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    server_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verification_method VARCHAR(10) NOT NULL DEFAULT 'HMAC',
    ip_address INET,
    user_agent TEXT,
    
    CONSTRAINT chk_points_positive CHECK (points_awarded > 0),
    CONSTRAINT chk_client_time_valid CHECK (client_timestamp > '2020-01-01')
);

CREATE INDEX idx_action_events_user_time 
    ON action_events(user_id, server_timestamp DESC);
CREATE INDEX idx_action_events_idempotency 
    ON action_events(action_idempotency_key);
```

### Score Ledger Table
Immutable history of all score changes (event sourcing pattern).

```sql
CREATE TABLE score_ledger (
    ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    event_id UUID NOT NULL REFERENCES action_events(event_id),
    previous_score INTEGER NOT NULL,
    new_score INTEGER NOT NULL,
    delta INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT chk_score_consistency CHECK (new_score = previous_score + delta),
    CONSTRAINT chk_score_non_negative CHECK (new_score >= 0)
);

CREATE INDEX idx_ledger_user ON score_ledger(user_id, created_at DESC);
```

## 2.2 Redis Data Structures

### Leaderboard Sorted Set

```bash
# Key pattern
Key: "leaderboard:global"
Type: Sorted Set
Score: current_score (integer)
Member: user_id (string)

# Commands
ZADD leaderboard:global 150 "user-uuid-1"
ZREVRANGE leaderboard:global 0 9 WITHSCORES  # Top 10
ZREVRANK leaderboard:global "user-uuid-1"   # User rank
```
### Rate Limiting

```bash
# Key pattern: ratelimit:{user_id}:{minute_window}
Key: "ratelimit:uuid:1234567890"
Value: count (integer)
TTL: 60 seconds

# Commands
INCR ratelimit:uuid:1234567890
EXPIRE ratelimit:uuid:1234567890 60
```

### Idempotency Cache
 ```bash
 # Key pattern: idempotency:{key}
Key: "idempotency:abc-123-xyz"
Value: event_id (string)
TTL: 86400 seconds (24 hours)

# Commands
SETEX idempotency:abc-123-xyz 86400 "event-uuid"
GET idempotency:abc-123-xyz
```

## 2.3 Data Consistency Rules
 -  Single Source of Truth: PostgreSQL is canonical; Redis is reconstructable
 -  Immutable Events: action_events and score_ledger are append-only
 -  Denormalized Cache: users.current_score is updated via transaction
 -  Tie-Breaking: Equal scores sorted by user_id (lexicographical)


<div align="center">

| [← Data Model](02-data-model.md) | [Next: Security →](04-security.md) |
</div>


# 3. API Reference

## 3.1 Authentication

All endpoints require JWT Bearer token except WebSocket initial connection.

Authorization: Bearer {access_token}
- X-Request-ID: {uuid}              # For tracing
- X-Idempotency-Key: {uuid}        # For action submission
- X-Action-Signature: {hmac}      # For action submission
- X-Client-Timestamp: {ISO8601}   # For action submission

## 3.2 POST /api/v1/actions/submit

Submit a new action for score calculation.

### Request Body

```json
{
  "action_type": "TASK_COMPLETE",
  "action_id": "task_abc_123",
  "metadata": {
    "task_category": "tutorial",
    "completion_time_ms": 4500
  },
  "client_timestamp": "2024-01-15T10:30:00.000Z"
}
```
### Signature Calculation

``` javascript

const payload = [
  action_type,
  action_id,
  client_timestamp,
  user_id  // from JWT sub claim
].join('|');

const signature = crypto
  .createHmac('sha256', CLIENT_SECRET)
  .update(payload)
  .digest('hex');
```
### Success Response (200)

``` json 
{
  "request_id": "req-uuid",
  "status": "accepted",
  "data": {
    "event_id": "evt-uuid",
    "score_update": {
      "previous_score": 150,
      "new_score": 175,
      "delta": 25,
      "new_rank": 12,
      "rank_change": -3
    },
    "leaderboard_snapshot": {
      "top_10": [
        {"rank": 1, "user_id": "u1", "username": "alice", "score": 500}
      ],
      "user_position": 12
    }
  },
  "timestamp": "2024-01-15T10:30:01.123Z"
}
```
### Error Responses

| Status | Code                  | Scenario                 |
| ------ | --------------------- | ------------------------ |
| 400    | INVALID\_ACTION\_TYPE | Unknown action type      |
| 401    | TOKEN\_EXPIRED        | JWT expired              |
| 403    | INVALID\_SIGNATURE    | HMAC verification failed |
| 409    | DUPLICATE\_ACTION     | Idempotency key exists   |
| 429    | RATE\_LIMIT\_EXCEEDED | Too many requests        |

## 3.3 GET /api/v1/leaderboard
Retrieve current top 10 scores.

### Query Parameters
| Param         | Type    | Default | Description                  |
| ------------- | ------- | ------- | ---------------------------- |
| limit         | integer | 10      | Max 100                      |
| include\_user | boolean | true    | Include requester's position |

### Response (200)

``` json

{
  "request_id": "req-uuid",
  "data": {
    "leaderboard": [
      {
        "rank": 1,
        "user_id": "uuid",
        "username": "alice",
        "score": 500,
        "is_current_user": false
      }
    ],
    "user_position": {
      "rank": 12,
      "score": 175,
      "percentile": 85.5,
      "next_milestone": {"rank": 10, "score_needed": 25}
    },
    "meta": {
      "generated_at": "2024-01-15T10:30:00Z",
      "cache_status": "hit",
      "ttl_seconds": 5
    }
  }
}

```
## 3.4 WebSocket /v1/stream
Real-time updates protocol.
### Connection Flow

- Client connects: wss://api.example.com/v1/stream
- Server sends: {"type": "connection.established", "session_id": "sid"}
- Client authenticates: {"type": "auth", "token": "jwt"}
- Server confirms: {"type": "auth.success", "user_id": "uid"}
- Server pushes updates

### Server Events

``` json 

// Leaderboard batch update (max 1/sec)
{
  "type": "leaderboard.update",
  "timestamp": "2024-01-15T10:30:01Z",
  "data": {
    "changes": [{"user_id": "u1", "old_rank": 15, "new_rank": 12}],
    "top_10_snapshot": [...]
  }
}

// Personal immediate update
{
  "type": "user.score_update",
  "timestamp": "2024-01-15T10:30:01Z",
  "data": {
    "new_score": 175,
    "delta": 25,
    "new_rank": 12
  }
}

```

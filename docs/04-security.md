<div align="center">

| [← API Reference](03-api-reference.md) | [Next: Execution Flows →](05-execution-flows.md) |
</div>


# 4. Security Architecture

## 4.1 Threat Model

| Threat | Likelihood | Impact | Mitigation |
|--------|-----------|--------|------------|
| Replay attacks | High | Medium | Timestamp validation + Idempotency |
| Score manipulation | High | Critical | HMAC verification |
| Brute force | Medium | Low | Rate limiting |
| Token theft | Low | High | Short TTL + Refresh rotation |
| Man-in-the-middle | Low | Critical | TLS 1.3 only |

## 4.2 Security Layers

### Layer 1: Transport
- TLS 1.3 mandatory
- Certificate pinning for mobile
- HSTS: `max-age=31536000; includeSubDomains`

### Layer 2: Authentication
- JWT RS256 (asymmetric)
- Access token: 15 minutes
- Refresh token: 7 days with rotation
- Audience claim to prevent cross-service reuse

### Layer 3: Request Validation

**Rate Limiting (Redis):**
- Per user: 10 actions/minute
- Per IP: 100 requests/minute
- Burst: 3 requests allowed

**Timestamp Validation:**
```javascript
const drift = Math.abs(clientTime - serverTime);
if (drift > 120000) reject(); // 2 minutes max
```
### Layer 4: Action Verification

**HMAC-SHA256 Process:**
 - Extract signature from header
 - Reconstruct: action_type|action_id|timestamp|user_id
 - Calculate expected signature with CLIENT_SECRET
 - crypto.timingSafeEqual(expected, actual)
 - Reject on mismatch (403, no retry)

### Layer 5: Business Logic

**Action Validation:**

 - Whitelist: Only predefined action types
 - Anti-farming: Max 5 identical actions/hour
 - Score integrity: Database constraints prevent negative scores

## 4.3 Security Headers

``` plain 
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'none'
X-Request-ID: {uuid}
```
## 4.4 Audit Logging

All security events logged:
  - Failed HMAC verification
  - Rate limit violations
  - Duplicate idempotency keys
  - Timestamp anomalies

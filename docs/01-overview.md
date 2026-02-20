<div align="center">

| [← Home](../README.md) | [Next: Data Model →](02-data-model.md) |
</div>

# 1. System Overview

## 1.1 Purpose

The Scoreboard Live Update API enables real-time tracking and display of user scores on a competitive leaderboard. The system processes user actions, validates their legitimacy, updates scores, and broadcasts changes to connected clients.

## 1.2 Scope

### In Scope
- Score calculation and persistence
- Real-time leaderboard queries (Top 10)
- WebSocket-based live updates
- Action verification and fraud prevention
- Rate limiting and abuse prevention

### Out of Scope
- User authentication/registration (assumed existing)
- Action definition (what constitutes a "task completion")
- Frontend implementation details
- Payment processing or rewards

## 1.3 Stakeholders

| Role | Interest |
|------|----------|
| Backend Engineers | Implementation guidance |
| Frontend Engineers | API contract clarity |
| DevOps/SRE | Deployment and monitoring |
| Security Team | Threat model review |
| Product Managers | Feature verification |

## 1.4 Definitions

| Term | Definition |
|------|------------|
| **Action** | A user activity that potentially increases score |
| **Score Event** | Recorded instance of a validated action |
| **Leaderboard** | Real-time ranked list of top users by score |
| **Idempotency Key** | Client-generated unique identifier preventing duplicates |
| **HMAC Signature** | Cryptographic proof of action authenticity |

## 1.5 Assumptions

1. Users are pre-authenticated via external system (JWT tokens)
2. Client applications can generate HMAC signatures
3. Network latency between client and server < 500ms
4. Database clock synchronization (NTP) is maintained
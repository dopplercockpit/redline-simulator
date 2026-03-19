# DEPLOYMENT_SPEC.md

## Purpose

This document defines the target deployment architecture for Redline Simulator Engine (RSE) as a **web-first educational simulation platform** with a **desktop fallback build**.

This is a forward-looking implementation spec intended to guide buildout, deployment, and operational decisions. It is not a description of transitional prototype behavior.

---

## 1. Canonical Deployment Strategy

### Primary Deployment Mode
Redline must be deployed primarily as a **web application**.

The web deployment is the default delivery channel for:
- classroom use
- remote demos
- portfolio/showcase access
- rapid testing and iteration
- centralized content and AI integration

### Secondary Deployment Mode
Redline must also support a **desktop-native fallback build**.

The desktop build exists for:
- instructor/admin use
- offline or weak-network environments
- browser compatibility failures
- performance-sensitive demos
- contingency deployment

### Strategic Position
The product is **web-first, desktop-safe**.

---

## 2. Canonical Hosting Topology

The deployment topology must be split into distinct layers:

1. **Static frontend delivery**
2. **Backend application/API**
3. **AI integration layer**
4. **Optional persistence/analytics layer**

### 2.1 Frontend Layer
The Godot web export must be deployed as a static web application.

Recommended hosting:
- Vercel static deployment
- or equivalent CDN/static host

Responsibilities:
- serve Godot export artifacts
- serve custom HTML shell
- serve lightweight static UI assets
- handle HTTPS and caching
- provide public entrypoint for the simulation

### 2.2 Backend Layer
The backend must be deployed as a separate web service.

Recommended hosting:
- Render web service
- or equivalent managed API host

Responsibilities:
- AI proxying
- schema validation
- response normalization
- request authentication
- session persistence hooks
- telemetry forwarding
- optional save/load sync endpoints
- future admin tooling endpoints

### 2.3 Persistence Layer
Persistence may initially be lightweight, but the architecture must allow for:
- save snapshots
- session histories
- telemetry logs
- admin reporting
- scenario content version references

Persistence may begin with file/database simplicity but must be designed for later migration without breaking API contracts.

---

## 3. Canonical Client/Server Boundary

### 3.1 Godot Web Client Responsibilities
The Godot client is responsible for:
- rendering scenes and UI
- collecting player input
- showing reports, missions, contracts, and prompts
- maintaining local runtime presentation state
- dispatching approved requests to engine services
- invoking backend endpoints for AI and online services

### 3.2 Engine Responsibilities
The engine remains authoritative for:
- simulation state
- time progression
- decision routing
- accounting consequences
- mission progression
- event processing
- deterministic outcome generation

### 3.3 Backend Responsibilities
The backend is responsible for:
- mediating all model calls
- protecting secrets
- validating payloads
- normalizing model output into approved schemas
- logging request metadata
- enforcing content and cost limits
- returning only approved structured responses

### 3.4 Strict Rule
The client must never call model providers directly in production.

---

## 4. Canonical Web Build Requirements

### 4.1 Rendering Target
The web build must be compatible with browser support requirements of the Godot web export target.

### 4.2 Performance Objective
The simulation must be playable on mainstream desktop browsers without requiring high-end hardware.

### 4.3 Asset Budget Discipline
Web deployment requires strict asset discipline.

Rules:
- background art must be optimized for web delivery
- large texture counts must be minimized
- scene loads should be incremental where possible
- AI/network latency must never block core scene rendering
- front-end boot size should be kept controlled

### 4.4 Custom Shell
The web build must use a custom HTML shell to support:
- branding
- loading states
- error messaging
- analytics hooks
- legal/privacy copy
- API base URL injection
- future feature flags

---

## 5. Canonical Deployment Environments

At minimum, the deployment model should support the following environments:

### 5.1 Local Development
Purpose:
- active coding
- scene debugging
- endpoint mocking
- schema validation
- fast iteration

Characteristics:
- local Godot run
- local backend API
- mock AI mode allowed
- local content files

### 5.2 Staging
Purpose:
- QA
- browser verification
- scenario validation
- AI prompt/output testing
- educator review

Characteristics:
- hosted static frontend
- hosted API backend
- non-production API credentials
- telemetry marked as staging
- scenario version pinning

### 5.3 Production
Purpose:
- classroom/student use
- demos
- stakeholder access
- official showcase deployment

Characteristics:
- stable CDN-hosted frontend
- production backend
- production AI credentials
- monitored telemetry
- versioned content bundles
- rollback-safe release process

---

## 6. Canonical Domain and Network Architecture

### 6.1 Domain Model
Recommended public topology:

- `redline.<domain>` or root app domain for the frontend
- `api.<domain>` for backend services

Examples:
- `app.redline-sim.com`
- `api.redline-sim.com`

### 6.2 HTTPS
All production traffic must use HTTPS.

### 6.3 CORS
CORS must be narrowly configured to allow only trusted frontend origins.

### 6.4 API Versioning
The backend must expose versioned routes, for example:
- `/v1/gen/news`
- `/v1/coach/nudge`

---

## 7. Canonical Backend Service Architecture

The backend should be intentionally thin.

### 7.1 Core Backend Modules
Suggested service modules:
- request validation
- auth and origin verification
- AI provider adapters
- schema enforcement
- response caching
- telemetry dispatch
- content registry lookup
- save/load service layer
- admin hooks

### 7.2 AI Provider Isolation
Model-provider-specific logic must be isolated behind a provider adapter layer.

The rest of the backend should not be tightly coupled to a single provider implementation.

### 7.3 Failure Handling
Backend failures must degrade gracefully.

If an AI call fails:
- the sim must remain playable
- the client should receive a safe fallback payload
- telemetry should log the failure
- the user should receive an intelligible message, not raw nonsense

---

## 8. Canonical Frontend-to-Backend Flow

### 8.1 Example Dynamic Flow
1. Player advances a week.
2. Engine resolves deterministic simulation consequences.
3. Client constructs a constrained context payload.
4. Client requests optional dynamic augmentation from the backend.
5. Backend validates payload.
6. Backend calls model provider.
7. Backend validates model response against schema.
8. Backend returns safe structured JSON.
9. Client renders the approved dynamic content.

### 8.2 Non-Blocking Rule
AI-generated augmentation must not be required for the turn to complete.

The simulation must resolve first.
Dynamic content may arrive after state progression.

---

## 9. Canonical Save/Sync Model

### 9.1 Default Runtime Save
The sim should support local save snapshots for quick continuity.

### 9.2 Online Save Extension
The architecture must allow online save synchronization via backend APIs.

### 9.3 Save Scope
A synchronized save should include:
- scenario identity
- scenario version
- simulation state snapshot
- loop state snapshot
- ledger state snapshot
- mission state
- event history
- deterministic seed data
- player metadata where applicable

### 9.4 Save Integrity
Save payloads must be versioned and validated server-side before acceptance.

---

## 10. Canonical Telemetry and Analytics Deployment

### 10.1 Telemetry Pipeline
Telemetry events should flow from client and/or engine to the backend, then onward to the chosen storage or analytics system.

### 10.2 Telemetry Fail-Safe
Loss of telemetry must never break gameplay.

### 10.3 Minimum Telemetry Categories
- session start
- scenario load
- panel open/close
- week advance
- mission completion
- quiz performance
- AI endpoint usage
- AI fallback usage
- save/load events
- major frontend errors

---

## 11. Canonical Release Packaging

### 11.1 Frontend Package
The frontend release artifact should include:
- Godot Web export
- custom HTML shell
- optimized static assets
- environment-specific configuration injection

### 11.2 Backend Package
The backend release artifact should include:
- API service code
- schema definitions
- prompt templates
- provider adapters
- validation logic
- configuration and secrets wiring

### 11.3 Content Package
Content should be versioned independently where practical:
- scenarios
- missions
- news templates
- contracts
- compendium data
- COA/posting maps

---

## 12. Canonical Configuration Model

### 12.1 Environment Variables
The backend must use environment variables for:
- model provider keys
- API base URLs
- allowed origins
- telemetry targets
- save-store credentials
- environment mode

### 12.2 Client Configuration
The frontend should receive only non-secret configuration such as:
- public API base URL
- build version
- environment label
- feature flags
- telemetry enabled flag

### 12.3 No Secret Leakage
No provider secret or private credential may be shipped in the web client.

---

## 13. Canonical Security and Abuse Constraints

### 13.1 Input Validation
All incoming client payloads must be validated.

### 13.2 Rate Limiting
AI endpoints must be rate-limited and protected against spam or accidental cost explosions.

### 13.3 Payload Size Limits
The backend must enforce payload size caps.

### 13.4 Output Validation
Model output must be schema-validated before it is returned to the client.

### 13.5 Logging Hygiene
Production logs must avoid leaking private user text or secrets beyond what is operationally necessary.

---

## 14. Canonical AI Integration Deployment Rules

### 14.1 AI Is a Backend Concern
The AI provider integration must live behind the backend service boundary.

### 14.2 Structured Contracts
Every AI endpoint must use a strict request and response schema.

### 14.3 Graceful Fallback
For every AI endpoint there must be:
- a fallback response path
- a timeout strategy
- a degraded but safe UX path

### 14.4 Cost Discipline
The backend must support:
- per-endpoint token budgeting
- caching where safe
- prompt template reuse
- future provider substitution

---

## 15. Canonical Desktop Fallback

### 15.1 Purpose
The desktop build is a resilience and instructional fallback, not the primary public platform.

### 15.2 Connectivity Model
The desktop build should be capable of:
- connecting to the same backend API as the web client
- using local-only mode when required
- falling back to static content if AI services are unavailable

### 15.3 Shared Contracts
The desktop and web clients must use the same backend endpoint contracts and content schemas.

---

## 16. Canonical Deployment Milestones

### Milestone 1: Vertical Slice Web Deployment
Deliver:
- one hosted web build
- custom shell
- working API backend
- one AI endpoint
- one deployable scenario slice

### Milestone 2: Stable Staging Pipeline
Deliver:
- staging frontend
- staging backend
- environment separation
- content versioning
- telemetry visibility

### Milestone 3: Production Readiness
Deliver:
- rollback-safe deployment
- monitored API
- graceful AI fallback
- versioned save/load support
- instructor-ready desktop fallback

---

## 17. Final Deployment Statement

Redline must be deployed as a **web-first simulation platform with a separate backend API and a desktop fallback build**.

The frontend serves the simulation.
The engine owns deterministic truth.
The backend brokers AI and online services.
The desktop build provides resilience.
The deployment architecture must preserve security, low friction, and controlled dynamism without sacrificing engine authority.

---


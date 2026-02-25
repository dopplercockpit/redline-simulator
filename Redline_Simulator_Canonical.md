# Redline_Simulator_Canonical

## Product name
**Redline Simulator Engine (RSE)**  
First “skin/module”: **Flightpath – Airport CFO Edition** (small regional airport → international airport)

## Player fantasy
You are the **Finance Head of a scrappy airport** with ambition and political baggage.  
You don’t “manage money.” You **weaponize it**: contracts, covenants, capex, working capital, compliance risk, and stakeholder manipulation. 😇➡️😈

## The promise
**Every single outcome is traceable.**  
The player can click from:

> “We offered a route incentive to Ryanair”  
→ to the **contract clause**  
→ to the **journal entry**  
→ to the **GL account**  
→ to the **line item on the statements**  
→ to the **KPIs and credit pressure**

No black-box math. No “because the game said so.” No bullshit.

---

## Non-Negotiables (your “truths,” but weaponized)
1) **Entertainment first.** If it doesn’t create dopamine, it creates dropouts.  
2) **Addictive progression.** Not grinding — *compulsion*: “one more turn, one more unlock.”  
3) **Graphics are secondary.** The “sexy” is the feedback loop: decision → ledger → results.  
4) **Dynamic economy.** Simple states, meaningful consequences.  
5) **Semi-dynamic scenarios.** Story beats fixed; numbers and outcomes vary by economy + choices + prior state.

---

## Core Loop (the addiction engine) 🔁

### Time structure (already aligned with your repo)
- **1 turn = 1 week**
- **Every 4th turn = month-end close mission**
- Quarter / Year closes are “boss fights.”

### What happens each week
Player chooses **1–2 impactful actions** max (scope control), e.g.:
- negotiate/modify **one contract**
- pull **one financing lever**
- approve **one operational/capex decision**
- respond to **one event** (shock)

Engine runs:
- **Market/Economy update** (macro state shifts)
- **Contract effects**
- **Operational throughput**
- **Ledger postings** (the sacred truth)
- KPIs + risk meters update
- Inbox updates with missions/choices

### Month-end close (your “standard mission”)
Player must:
- reconcile key accounts (cash, AR/AP, deferred revenue, capex, debt)
- explain variance drivers (boardroom quiz)
- earn points / unlocks
- accumulate audit pressure if sloppy

---

## What We Simplify vs Where We Get Nasty 😈

### Simplify (so it stays playable)
**Economy:** 5-state macro model (Markov-ish, deterministic via seed)  
- Boom / Stable / Soft / Recession / Crisis  
Plus 2–3 indices:
- **Tourism index**
- **Interest rate regime**
- **Fuel shock level** (affects airlines → affects your traffic)

**Demand:** 3 demand tiers per segment (Everspace-style, but smarter)
- Passenger: Leisure / Business
- Cargo
Each is Low / Medium / High, driven by macro + airport reputation + capacity constraints.

**Operations:** small number of controllable “dials”
- gate capacity / terminal capacity tier
- service quality tier
- disruption handling tier (resilience spend)

### Scale complexity (where the learning actually lives)
**Contracts.** Contracts are the “combat system.”
- airline route agreements & incentives
- concession leases (fixed + % of sales)
- ground handling/service SLAs
- capex/vendor contracts (penalties, LDs, milestones)
- debt facilities (covenants, margins, step-ups)

Contracts create **ongoing ledger effects**, not one-time “click to win.”

---

## The Big Missing Piece: “Extreme Granularity” = Ledger-First Accounting 🧾
Right now your finance layer is still mostly “summary deltas.” That’s fine for prototyping, but it will never deliver your core promise.

### Canonical accounting rule
**Nothing touches financial statements directly.**  
Everything posts to a **transaction ledger**:

**Transaction**
- id, week, scenario_id, source (“contract”, “event”, “player_action”)
- memo (“Landing fees – Carrier X – Week 12”)
- dimension tags (terminal, airline, shop, project, debt instrument)

**Journal Entry**
- list of debit/credit lines to GL accounts

Statements are generated as:
- **TB (trial balance) → IS/BS/CF rollups**
- drill-down always available to transaction → journal lines

This is how you get your “trace every transaction” requirement **without** adding a million moving parts.

---

## Progression & Leveling (the “one more turn” feeling) 🎮
You already have the bones in `LoopState`:
- `points`
- `audit_score`
- `hq_strength`
- `unlocks`

### Canonical leveling choice (tradeoffs)
When a scenario completes, player chooses **one upgrade**, which buffs one system and nerfs another (because adulthood is pain):
- **Commercial Power** (better contract terms) but higher audit attention
- **Operational Resilience** (less disruption loss) but higher fixed cost
- **Financial Engineering** (more financing tools) but tighter covenants
- **Compliance Armor** (lower audit risk) but slower growth
- **People/Morale** (productivity boost) but higher SG&A

### Audit system (keep your twisted rule, but clarify it)
- Audit pressure rises from:
  - wrong answers
  - aggressive accounting
  - high-risk contract clauses
  - “hack” activity
- When threshold hits: **Audit Boss Fight**
  - player must defend postings + reconcile inconsistencies
  - fail = penalty, restriction, forced refinance, reputation hit

---

## Scenario Structure (12 fixed beats, semi-dynamic parameters)
Each scenario is:
- fixed narrative setup + characters + objective
- **variable parameters** (ranges sampled from seed + economy)
- multiple win paths
- persistent consequences

Here’s a clean 12-pack that fits the airport growth arc:

1) **“The Regional Trap”** — stabilize cash + fix leaky revenue recognition  
2) **Route Incentive Offer** — attract a carrier without selling your soul  
3) **Concessions War** — duty-free/food lease negotiation (fixed + % rent)  
4) **Disruption Week** — weather/strike; choose resilience spend vs cancellations  
5) **Capex Temptation** — apron upgrade; vendor penalties and milestone accounting  
6) **Debt Desk Opens** — refinance / covenant intro mission  
7) **Cargo Pivot** — warehouse lease + service SLA + working capital crunch  
8) **Security/Compliance Spike** — regulation; pass audit or get wrecked  
9) **Terminal Expansion Phase 1** — staged build, capitalized interest, grants  
10) **Airline Power Play** — dominant carrier tries to squeeze fees  
11) **Full Audit Event** — forensic month close under hostile questioning  
12) **Exit Strategy** — sale/IPO/PPP deal; valuation depends on your ledger reality

---

## Architecture Canonical (mapped to your current repo)
You *already* have the correct “spine”:
- `RSE` autoload (`res://engine/engine.gd`)
- `GameManager` weekly progression + month-end trigger
- `DecisionResolver` gatekeeping mutations
- `MissionManager` inbox + boardroom quiz wiring
- `LoopSystem/LoopState` for progression state

### Canonical modules (Airport edition)
Keep the same module philosophy, but define airport domain objects:
- **Market/Economy**: macro state + indices + passenger/cargo demand
- **Ops**: capacity tiers, disruptions, service quality
- **Contracts**: clause engine + schedule + triggers
- **Finance**: ledger posting + TB + statements + KPIs
- **Events**: deterministic shocks and choice forks
- **Scoring**: objectives + unlock rules
- **Telemetry**: useful, minimal, not creepy

### The big pivot
Your current `GameStateData` is airline-ish (`fleet/routes/fuel`).  
Airport CFO edition state becomes stuff like:
- terminals/gates capacity tier
- carrier mix (not fleet)
- revenue streams (landing, passenger fees, retail, parking, cargo)
- contract portfolio
- capex projects
- debt stack + covenants
- reputation/service quality indices

But again: **the ledger is the truth**, so state doesn’t need to explode.

---

## Scope Guardrails (so you don’t recreate the real world and die of sadness)
- **No micromanaging 10,000 entities.** You’re not building Airport CEO 2.
- Weekly decisions are **few but consequential**.
- Complexity comes from:
  - contract structure
  - accounting recognition/timing
  - covenants and tradeoffs
  - scenario branching consequences

That’s the “educational sim” differentiator: fewer moving parts, deeper causality.

---

**Milestone: Ledger-first finance loop**
1) Add a ledger layer (transaction + journal entries)
2) Make Finance generate statements from ledger (TB → IS/BS/CF)
3) Update 2–3 example actions to post real entries:
   - landing fee invoice + cash collection
   - concession rent (fixed + variable)
   - debt draw + interest accrual + covenant check
4) Replace “financial deltas” with postings for those flows
5) Build drill-down UI: statement line → GL → transaction list

Once that’s in, everything else becomes *content and tuning*, not existential architecture decisions.

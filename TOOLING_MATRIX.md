# 🛠️ TOOLING_MATRIX.md - Company Equipment Registry

This matrix defines the "loadout" for each departmental role. Agents are equipped ONLY with the tools necessary for their domain to minimize token waste and prevent hallucination.

## 🏛️ Departmental Loadouts

### 👑 CEO (The Orchestrator)
- **Primary Goal:** Strategic decomposition & management.
- **Tool Loadout:**
    - `sessions_spawn` / `sessions_yield`: Summon and manage employees.
    - `cron`: Schedule heartbeats and watchdogs.
    - `AgentPulse (All)`: Manage the company task board.
    - `Rectify Docs`: Manage the company wiki/SOPs.
    - `memory_store` / `memory_recall`: Long-term company strategic memory.

### 📈 Growth Lead (Top-of-Funnel)
- **Primary Goal:** Attention $\rightarrow$ Lead.
- **Tool Loadout:**
    - `web_search` / `web_fetch`: Market research and trend spotting.
    - `watercrawl`: Deep scraping of competitor sites and forums.
    - `socialbu`: Content distribution and social listening.
    - `image_generate` / `video_generate`: Creating high-converting visual assets.

### 💰 Sales Lead (Middle-of-Funnel)
- **Primary Goal:** Lead $\rightarrow$ Closed Won.
- **Tool Loadout:**
    - `breakcold`: Lead sourcing and cold outreach.
    - `message`: Direct communication with prospects.
    - `boost-space`: Managing the CRM, deal stages, and contact records.
    - `memory_recall`: Accessing lead-specific preferences for personalization.

### 🛠️ Product Lead (Bottom-of-Funnel)
- **Primary Goal:** Sale $\rightarrow$ Delivered Value.
- **Tool Loadout:**
    - `exec` / `write` / `edit` / `apply_patch`: Full codebase management.
    - `github-publish`: Deploying deliverables to the client's repo.
    - `pdf`: Analyzing technical requirement documents.
    - `node_inference`: Running local specialized models for code generation.

### ♻️ Success Lead (LTV/Retention)
- **Primary Goal:** Delivered Value $\rightarrow$ Expansion.
- **Tool Loadout:**
    - `feishu_doc` / `feishu_chat`: Client onboarding and reporting.
    - `boost-space`: Tracking LTV and identifying upsell opportunities.
    - `memory_store`: Logging client feedback and "winning" patterns.

## ⚠️ Tooling Gaps (Identified)
- **Email Automation:** We have `breakcold` for leads, but no dedicated high-volume email sequence tool (only general `message`).
- **Payment Gateway:** No direct API for Stripe/PayPal to verify "Closed Won" payments automatically.
- **Analytical Dashboard:** We have AgentPulse for tasks, but no real-time revenue/LTV dashboard (depends on `boost-space` manual reporting).

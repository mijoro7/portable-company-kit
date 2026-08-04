# 🧪 PROTOTYPE_SOP: The First Loop (Growth $\rightarrow$ Sales)

## 🟢 Stage 1: Discovery (Growth Lead)
- **Input:** CEO Goal (e.g., "Get 5 new B2B leads for [Offer]").
- **Action:** 
    - Search `web_search` for target audience watering holes.
    - Scrape `watercrawl` for high-intent prospects.
    - Store raw leads in `boost-space` (CRM).
- **Trigger:** When 5+ leads are in `boost-space` with status `NEW`.

## 🟡 Stage 2: Qualification (Sales Lead)
- **Input:** `boost-space` leads with status `NEW`.
- **Action:** 
    - Use `breakcold` to enrich lead data.
    - Send personalized outreach via `message`.
    - Update `boost-space` status to `QUALIFIED` or `LOST`.
- **Trigger:** When a lead replies "Interested."

## 🔴 Stage 3: Closing (Sales Lead)
- **Input:** `QUALIFIED` lead.
- **Action:** 
    - Schedule a call or send a proposal via `feishu_doc`.
    - Update `boost-space` to `CLOSED WON`.
- **Trigger:** Payment verified / Contract signed.

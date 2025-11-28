# B2B SaaS Marketing Analytics Project  
### Full-Funnel, Attribution, Influence, and LTV Analysis for a SaaS Analytics Company

---

# 📥 Get the Tableau Workbook

**▶ View on Tableau Public:**  
[[***Add your Tableau Public link here**](https://public.tableau.com/app/profile/ben.mikola/viz/CRMFullFunnelSalesMarketingAnalytics/2025Overview)]

All dashboard images referenced below are stored in:  
`/images/`

---

# 📸 Dashboard Previews

- **Dashboard Images (click to open):**  
  - [2025 Overview](/images/2025_overview.PNG)  
  - [Sales Funnel](/images/sales_funnel.PNG)  
  - [LTV & Churn](/images/ltv_churn.PNG)  
  - [Channel Influence](/images/influence_buy_channel.PNG)  
  - [Lead Source Performance](/images/lead_source_performance.PNG)  
  - [Attribution](/images/attribution.PNG)  
---
# 🚀 What This Project Demonstrates

## ✔ SQL Data Cleaning
- Built staging tables (`*_stg`) with cleaned, deduped records  
- Fixed dirty data: mixed date formats, duplicate IDs, missing emails, inconsistent casing  
- Standardized channel naming, UTM parameters, and funnel fields  
- Created analytical datasets for attribution, funnel performance, LTV, and influence analysis

## ✔ Multi-Model Attribution
Calculated 3 attribution models using SQL window functions:
- **First Touch Attribution**  
- **Last Touch Attribution**  
- **Multi-Touch Linear Attribution**

Models output revenue attribution at the **channel**, **UTM medium**, and **UTM campaign** levels.

## ✔ Channel Influence Analysis
Measures how often each channel participated in the customer journeys—separate from attribution credits.

Includes:
- Opportunity Influence %  
- Closed-Won Influence %  
- Pipeline Influence %

## ✔ Full Funnel + Conversion Rates
End-to-end funnel from:  
**Lead → MQL → SQL → Opportunity → Closed-Won**

Includes:
- Lead-to-Opportunity rate  
- Opportunity-to-Win rate  
- Lead-to-Win rate  
- Monthly funnel performance

## ✔ Lead Source Performance
Based strictly on the **original lead source**, not attribution touches.

Includes:
- Lead volume by lead source  
- MQL volume by lead source  
- SQL/Opportunity creation by lead source  
- Win rate by lead source  
- Pipeline & revenue by lead source

## ✔ Cohort-Based LTV & Churn Analysis
Built using subscription & customer lifecycle data:
- Customer-level LTV  
- Average LTV  
- Churn rate  
- **LTV by Industry**  
- **LTV by ABM vs non-ABM**

---

#  Dashboards Included in the Tableau Workbook

All dashboards shown above are included inside:

`CRM Full Funnel Sales & Marketing Analytics.twb`

### **1. 2025 Overview Dashboard**
- Total Leads  
- Total Opportunities  
- Win Rate  
- CAC, ACV  
- Revenue & Spend  
- Monthly trends

### **2. Sales Funnel Dashboard**
- Leads → Opportunities → Closed-Won  
- Conversion rates (L→O, O→W, L→W)  
- Funnel visuals and KPIs

### **3. LTV & Churn Dashboard**
- Average LTV  
- ABM vs Non-ABM LTV  
- LTV by Industry  
- Churn by cohort or segment

### **4. Channel Influence Dashboard**
- % of Opps influenced  
- % of Closed-Won influenced  
- % of Pipeline influenced  
- Channel comparison bars

### **5. Lead Source Performance Dashboard**
- Lead → MQL → SQL → Opp → Closed-Won metrics  
- Win rate per source  
- Revenue & pipeline per source

### **6. Attribution Dashboard**
Toggle between:
- **First Touch**  
- **Last Touch**  
- **Multi-Touch (Linear)**  

See attribution by:
- Channel  
- UTM Medium  
- UTM Campaign



# GeM Saathi — Product Requirements

Version 1.0 · 9 September 2026 · Product owner: Amay

## Purpose
Help Pune and Maharashtra small business owners decide whether to pursue Government e-Marketplace selling, understand their business classification and financial assumptions, and leave with a saved next action. Deliver one Flutter application for Android and the web, backed by Supabase when configured.

The supplied brief describes a diagnostic survey of 20 SME owners: awareness and eligibility uncertainty dominate, while revenue and effort clarity are low. These are provisional project inputs: the original response data, field dates and interview transcripts have not been supplied. They must not be represented as independently verified research.

## Users and outcomes
| User state | Main question | Entry point |
|---|---|---|
| Unaware | What is GeM? | Short educational module |
| Uncertain | Can my business sell? | Eligibility and classification |
| Paperwork-ready | What could I earn? | Revenue scenario and pricing |
| Cautious | Is the effort worth it? | ROI and effort |
| Ready | What should I do today? | Readiness tracker and action hub |

Users may move through several states. Tools are independently accessible; no account or learning-module gate is imposed. Every result offers another relevant step and the combined report. Opting out of government sales is a distinct user choice, not an eligibility failure.

The user owns the registration process on the official GeM website. This application does not register sellers, submit bids or promise orders.

## Delivered product scope
1. Responsive home, tool directory and GeM 101.
2. Eligibility/classification checker with document gaps and conditional guidance.
3. Revenue scenario estimator with optional published, sourced procurement evidence.
4. Pricing and gross margin calculator.
5. ROI/effort calculator combining saved revenue and margin inputs.
6. Persistent readiness tracker, including conditional document/deposit checks.
7. Combined report with text download/share, copy and user-initiated WhatsApp sharing.
8. Official-portal action hub and authenticated self-reported milestone submission.
9. Email-code authentication and cross-device state restoration via Supabase.
10. Workshop-interest, CA-referral and guidance requests, with explicit follow-up consent.
11. Optional research telemetry, referral attribution, evidence review and operator research export.
12. English/Hindi interface and local guest persistence.

## Information architecture
- `/` Home
- `/learn` GeM 101
- `/tools` Tool directory
- `/eligibility`, `/revenue`, `/pricing`, `/roi`, `/tracker`
- `/report` Combined report
- `/register` Official registration hub and milestone reporting
- `/account` Email sign-in, sync, research consent and data deletion
- `/support` Workshop and partner requests
- `/about` Project, limitations and source register

Web uses Flutter's hash routes, e.g. `/#/revenue`; distribution URLs use `/?ref=ca_pune_01#/eligibility`. Android uses the same Navigator routes within the app. Android campaign/install attribution is not implemented; web query attribution is supported.

## Functional rules and acceptance
### Eligibility
Inputs: organisation type, category, investment and turnover in lakh, self-classification, PAN/identity readiness, bank readiness, GST status, Udyam status, prior public supply and interest.
- Determine classification using **both** investment and turnover. Effective 1 April 2025: micro ≤₹2.5 crore/₹10 crore, small ≤₹25 crore/₹100 crore, medium ≤₹125 crore/₹500 crore. Crossing either limit moves upward.
- Correct a conflicting self-classification visibly.
- “Yes” means ready to explore registration, never official approval.
- “Partial” identifies missing identity/bank information, uncertain GST applicability or a category needing review.
- GST exemption requires confirmation; the tool does not give a tax determination.
- Missing Udyam and no government experience alone are not disqualifiers.
- A business outside MSME limits is not automatically barred from GeM.
- The brief’s blanket “No” verdict is intentionally not inferred from these limited questions: no validated exclusion rule was supplied. Opt-out is a separate result.
- Do not fabricate fixed time-to-fix claims; state that local timing evidence is pending.

### Revenue
- Category and location scope any published benchmark rows.
- Default values are labelled editable examples, never official category averages.
- Revenue range = assumed order value × cautious/optimistic annual order counts.
- Lower count must not exceed upper; zero is valid. Revenue is gross and can be zero in practice.
- Buyer counts, procurement frequency and order value are unavailable unless curated evidence is published with URL, as-of date, sample size and methodology.
- Procurement demand is not seller earnings. No unsupported mapping from GMV to expected seller revenue.

### Pricing
- Cost per unit = inputs + allocated overhead + logistics/other costs.
- Target price = cost / (1 − margin/100). Margin is profit divided by sale price, not markup.
- Optional comparable quote gives actual margin at that quote; negative margin remains visible.
- 17.5% is attributed to the brief's survey median (n=20; field date unavailable), not GeM market pricing.
- L1 means lowest evaluated eligible offer. MSE purchase preference within L1+15% is conditional and requires matching L1 under applicable tender/policy rules; an award is never automatic.
- Taxes, financing and platform order fees must be considered separately.

### ROI and effort
- Reuse saved revenue and pricing inputs; allow user edits. Recalculating upstream tools invalidates the old ROI result to prevent stale reports.
- Setup economic cost = cash outlay + hours × hourly value.
- Annual revenue = order value × assumed annual order count.
- Published fee model: zero at order value ≤₹10 lakh; otherwise 0.3% of **total** order value, capped at ₹3 lakh per order. Source: PIB 21 September 2024, policy effective 9 August 2024. Fee tax is excluded; confirm the current GeM terms before real bidding.
- Annual contribution = annual revenue × contribution margin − annual platform fees − additional annual operating costs.
- Horizon contribution = annual contribution × max(0, horizon months − start delay)/12 − setup cost.
- Payback months = start delay + setup/(annual contribution/12), only if annual contribution is positive. Otherwise show no payback.
- Outputs are contribution, not guaranteed income, discounted investment value or cash-flow forecasts. Constant annual volume and margin are explicit assumptions. Payment delay, financing, working capital, fee GST and tax are not modelled.

### Tracker, report and action hub
Nine steps include identity/bank, GST applicability, Udyam benefits, account, catalogue, applicable deposits, bids, fulfilment and ratings. This refines the original unconditional eight-step journey. Document answers prefill the first steps; users may confirm completion or non-applicability. Step order is guidance, not a hard gate. Claims of registration/first orders go into a distinct outcome table as self-reported. Only trusted operators can verify or reject them.

### Persistence, consent and support
- Guest progress is stored in device/browser preferences. Clearing browser data removes it. Browser profiles on shared devices are not private accounts.
- Email OTP sign-in is optional. Cloud profiles are scoped to authenticated user IDs with RLS.
- On sign-in, newer saved account state wins; guest data seeds an empty account. This is snapshot restoration, not collaborative multi-device merging.
- Financial inputs are not copied into analytics properties.
- Research consent is off by default. Consented guest events stay locally queued until sign-in; therefore central telemetry does **not** measure all anonymous visitors. Analysis must disclose that selection limitation.
- Referral is first-touch `ref`, restricted to 64 alphanumeric/underscore/hyphen characters. Never place phone numbers/emails in codes.
- Research withdrawal stops new telemetry and clears unsent events. Project-data deletion removes uploaded project data. Authentication identity remains and may be deleted separately by an operator if requested.
- Cloud errors preserve local work and show a pending-sync state. Support/milestone submissions require connectivity and do not pretend to succeed offline.
- Workshop interest is not a scheduled booking. CA availability and follow-up remain human operations; no outgoing email or WhatsApp is sent automatically.

## Trust and content governance
Do not publish the supplied FY26 GMV, MSE denominator or Maharashtra figures without dated, comparable official evidence. Live official statistics are linked instead. A 20-person convenience survey cannot support national population claims. Do not label revenue scenarios “benchmarked” unless the data actually supports that use.

Benchmark publication requires a defensible sampling window, category/geography definition, deduplication procedure and metric definition. Bid estimates and awarded values must not be mixed. An operator publishes rows; clients cannot change policy evidence.

## Research and impact plan
- Phase 1: 15–20 structured interviews across 3–4 categories; consent, codebook and ranked barriers.
- Phase 2: tools distributed through 2–3 CA partners and SME/college networks using unique referrals.
- Phase 3: pre-register follow-up windows and comparison assignment, then measure awareness → engagement → intent → verified registration → verified first order.
- Targets in the brief (25 registrations, 15 first orders, 150 awareness participants, >70% module-to-tool transition) are aspirations, not current impact or promises.
- Count users once per outcome, separate self-reports from verified outcomes, identify opt-outs, report attrition and incomplete observation windows.
- Fisher's exact test is supplied for a small-sample two-group comparison; significance does not establish causality in a non-randomised design. Do not invent a comparison group.

## Release acceptance and external dependencies
The local application must pass Dart analysis, model/store tests and mobile/desktop widget checks; web release and Android debug APK builds should compile. Supabase migrations and access controls must pass isolated SQL checks. Live OTP delivery, cross-device cloud sync and end-to-end hosted requests require real project configuration and smoke testing.

Before public launch: provide Supabase URL and publishable/anon key, apply migrations, configure email OTP template and SMTP, test two-user isolation, supply a research/partner operator, validate financial inputs and translations with Pune owners, choose Android application ID/signing, and choose the web host. No service-role key may enter Flutter builds.

## Sources
- [Official Udyam thresholds](https://udyamregistration.gov.in/Important.aspx), effective April 2025.
- [PIB fee-policy announcement](https://www.pib.gov.in/Pressreleaseshare.aspx?PRID=2057276), 21 September 2024.
- [MSME CHAMPIONS procurement guidance](https://champions.gov.in/Ministry-of-MSME/skills%2Cloan%2Ccredit_guarantee%2CPM-atmnirbhar-Economic-Package%2Celigibility_criteria%2Cguidelines_Schemes/query_questions_FAQs.htm).
- [GeM statistics](https://gem.gov.in/statistics), live dashboard.
- [GeM seller prerequisite PDF](https://assets-bg.gem.gov.in/resources/pdf/seller-registration-pre-requisites-v1.2.pdf), indexed but direct automated retrieval returned 403; final portal-specific eligibility must be confirmed manually.
- [Supabase Flutter OTP](https://supabase.com/docs/reference/dart/auth-signinwithotp) and [verification](https://supabase.com/docs/reference/dart/auth-verifyotp).

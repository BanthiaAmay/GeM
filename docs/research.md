# Research and operator workflow

## Before recruiting
Obtain consent, confirm partner availability, date the survey, preserve raw interview data separately from the app, and pre-register the primary outcome and observation window. Do not collect Aadhaar/PAN scans in support notes. The proposed 25/15 outcome targets and 150 workshop attendees are goals, not baseline facts.

The application stores optional event telemetry only for consenting users and uploads it only after sign-in. Anonymous/non-consenting traffic is not part of the central measurement denominator. Describe this selection bias in the paper. Tool usage alone cannot establish causal improvement.

## Referral distribution
Give each partner a stable non-identifying code, e.g. `ca_pune_01`, `ecell_02`. Use `https://YOUR_HOST/?ref=ca_pune_01#/eligibility`. First touch is saved in the current profile. Do not encode business names, phone numbers or emails. Android install attribution is outside this version.

## Support requests
Use Supabase's operator dashboard to inspect `support_requests`. Authenticated identity maps to the account email in Authentication → Users. Contact only for the request's stated purpose and consent. Update `status` as `contacted` or `closed`; no application code sends automatic outbound messages. A pending workshop request is not a booking.

## Verify outcomes
Review a self-reported seller/order reference with participant consent. Record the evidence location and method without duplicating sensitive documents in free text. In a trusted SQL/operator session:

```sql
select public.review_outcome(
  'OUTCOME_UUID'::uuid,
  'verified',
  'Seller record checked on DATE by OPERATOR; evidence retained under REFERENCE'
);
```

Use `rejected` with a substantive reason when evidence fails. The function writes a verification audit. Client apps cannot execute this RPC or set verification fields. Self-reports and checklist ticks do not count as verified registrations or first orders.

## Benchmark publication
Insert only real, sampled data into `benchmarks`. All fields are required: category, city, metric, low/high, unit, source title/HTTPS URL, date, sample size, methodology and publication flag. Supported metrics: `order_value`, `active_buyers`, `procurements_per_month`.

Document whether a metric uses bids, awarded contracts or seller orders; geographic scope, sampling dates, repeated buyers and categories, exclusions, and currency/tax units. Do not use buyer-demand estimates to claim expected seller income. There are deliberately no production seed benchmarks.

## Cohort analysis
An operator inserts consented participants into `research_assignments` with a pre-specified group (`tool_assisted` or `comparison`), assignment method, enrolment time and follow-up due date. Do not infer group assignment retrospectively from whether someone used a tool. Comparison-group observation and outcome follow-up are human research tasks.

Export the `research_export` view as CSV via an authorised database session. It excludes contact data and raw business finances but still contains pseudonymous participant IDs; treat the export as research data. Keep exports under `research/exports/` (gitignored).

```sh
python3 research/analyze.py research/exports/cohort.csv --as-of 2026-12-01T00:00:00Z
python3 -m unittest discover -s research -p 'test_*.py'
```

The script excludes unfinished observation windows, reports participant counts, Wilson intervals, opt-outs and verified outcomes, and computes two-sided Fisher's exact p for the primary verified-registration outcome only when both groups exist. Opt-outs remain in assigned-cohort denominators; report them separately rather than silently removing them. Missing follow-up is not proof of no registration: the export is an observed-verified-outcome analysis, and attrition needs separate fieldwork accounting. Non-randomised groups do not establish a causal effect. Cohort CSVs should never be published with contact mappings.

## Retention
Set a retention interval and project contact before real recruitment. Users can delete project records in the app; the separate Supabase Auth identity remains until an operator removes it. Backup retention follows the Supabase project policy. Review and delete stale support/research records at project close, and document the retained aggregate statistics. A production retention automation is not configured by this repository.

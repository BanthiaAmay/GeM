# GST workspace: boundaries and integration plan

This module is a **preparation workspace**. It does not file a return, certify a GSTIN, create an official challan, make a payment or log in to the GST/GeM portals. An AI browser agent using a taxpayer's password/OTP to do those tasks would make errors and accountability difficult to control. The safer path is local document extraction, deterministic checks, user correction, an accountant review if desired, and an explicit final action through the official portal or a properly authorised GSP/ASP integration.

The current Android/web app imports text PDFs locally, extracts a first draft of invoice number/date/GSTIN/amount fields, and requires field review. It cannot read image-only scans; those open with blank fields for manual entry. No invoice bytes are sent to an AI service. Uploading a PDF to private Supabase storage is a separate, signed-in option. Extracted numbers sync to the signed-in account through RLS; guests have device-local metadata only. Never store credentials or OTPs.

The checks catch missing data, GSTIN syntax/checksum problems, duplicate keys, tax arithmetic mismatch, and conflicting IGST/CGST+SGST entries. GSTIN syntax is not proof that registration is active. The app does not decide the correct HSN/SAC tax rate, place-of-supply treatment, reverse-charge rules, credit-note treatment, ITC eligibility, or filing scheme. Those require policy-aware review and, where useful, a CA.

The GSTR-2B comparison accepts an explicit CSV template with supplier GSTIN, invoice number, taxable value, CGST, SGST, IGST. It highlights missing/mismatched purchase entries. GST portal exports may have different headers and sections; the adapter must be verified against real official exports before claiming direct import. No purchase tax is labelled claimable ITC without a GSTR-2B and eligibility review.

## Next authorised integration stages
1. Validate extraction against a consented invoice set across real formats; measure field-level precision and force manual correction for low confidence.
2. Add OCR for scans behind an explicit data-sharing choice and contracted processor, with retention/deletion terms. Server AI may suggest fields; deterministic calculations and user confirmation remain the source of truth.
3. Obtain a licensed GSP/ASP integration or supported GSTN route for authenticated return data, live GSTIN status, GSTR-2B, GSTR-1 and GSTR-3B preparation. Scope each permission and use a sandbox first.
4. Map every return field and special treatment with a tax professional, generate a reviewable draft, log amendments, and compare to official portal previews.
5. If challan/payment integration is authorised, show official amount and destination, require user approval and redirect/hand off to the official flow. Never store a GST portal password, OTP, card or bank credentials in this app.
6. Maintain tax-rule versioning and a service-owned deadline calendar. Do not infer dates from a fixed monthly pattern because scheme, state and extensions can change.

## Sources checked 22 September 2026
- [GST portal GSTR-1 guide](https://tutorial.gst.gov.in/userguide/returns/Creation_of_Outward_Supplies_Return_in_GSTR-1.htm): online, offline tool and ASP/GSP preparation, with final preview.
- [GST portal GSTR-3B guide](https://tutorial.gst.gov.in/userguide/returns/GSTR3B_-_File_Nil_Return.htm): authorised signatory, declaration and DSC/EVC at filing.
- [GST taxpayer search](https://services.gst.gov.in/services/quicklinks/searchtxp): official status check.
- [GST QRMP advisory](https://tutorial.gst.gov.in/offlineutilities/returns/QRMP_Advisory.pdf): scheme-specific payment timing and challan steps.

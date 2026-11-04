// Saathi: the in-app assistant. Runs as a Supabase Edge Function so the
// Gemini key never ships inside the app. For each question it:
//   1. verifies the caller's Supabase session,
//   2. counts the question against a daily limit (saathi_take_question),
//   3. gathers that user's own data server-side (profile answers,
//      readiness, calculator results, alert settings, recent alerts and
//      live matching bids with their bid-document details), and
//   4. asks Gemini with an app-specific brief.
// Questions and answers are not stored.
//
// Secrets (supabase secrets set …): GEMINI_API_KEY; optional GEMINI_MODEL
// (default gemini-3.5-flash-lite) and SAATHI_DAILY_LIMIT (default 40).
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are
// provided by Supabase.
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = Deno.env.get("GEMINI_MODEL") || "gemini-3.5-flash-lite";
const DAILY_LIMIT = Number(Deno.env.get("SAATHI_DAILY_LIMIT") || "40");
const LANGUAGES: Record<string, string> = {
  en: "English", hi: "Hindi", mr: "Marathi", bn: "Bengali", gu: "Gujarati",
  pa: "Punjabi", ta: "Tamil", te: "Telugu", kn: "Kannada",
};
// Onboarding answers that may be shared with the model. Contact details
// and identity numbers are never included (PAN/Aadhaar are never collected;
// only yes/no readiness answers are).
const PROFILE_KEYS = [
  "fullName", "businessName", "businessForm", "businessFormOther", "sector",
  "sectorOther", "role", "roleOther", "state", "district", "authorisedReady",
  "turnoverLatest", "turnoverFY2024_25", "turnoverFY2023_24",
  "pastOrderExperience", "pastOrderCount", "pastOrderValueRange", "records",
  "panReady", "checklist", "gemGuide", "bidKeywords",
];
const TOOL_KEYS = ["eligibility", "revenue", "pricing", "roi"];
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Turn = { role: "user" | "model"; text: string };

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function clip(value: unknown, limit: number): string {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length > limit ? text.slice(0, limit - 1) + "…" : text;
}

function pick(source: Record<string, unknown>, keys: string[]) {
  return Object.fromEntries(
    keys.filter((k) => source[k] !== undefined && source[k] !== null && source[k] !== "")
      .map((k) => [k, source[k]]),
  );
}

const APP_GUIDE = `Bid2Scale helps Indian small businesses sell to the government on GeM
(Government e-Marketplace, gem.gov.in). The app has:
- Onboarding questions about the business (sector, what it supplies, turnover, experience, documents ready).
- Home: dashboard of preparation progress, notifications, bids for you, quick actions.
- Bid alerts (bell icon / menu "Bid alerts"): matches new GeM bids to the seller's keywords and sends app notifications, an email digest and (when enabled) WhatsApp. Keywords and delivery states can be changed there.
- Live GeM bids (menu): open bids matching the seller, with documents required, experience, turnover and EMD from the bid document.
- Tools and Calculators: eligibility checker (MSME class, PAN/bank/GST/Udyam readiness), revenue estimator, pricing & margin, ROI & effort, readiness tracker.
- Financial Hub, GeM registration guide, documentation and bid-preparation guides (menu), smart search.
GeM facts to rely on: sellers register at https://mkp.gem.gov.in with PAN, Aadhaar-linked mobile of the authorised person, bank account and (where applicable) GST and Udyam; bids list eligibility (turnover, past experience), documents required, EMD and buyer's additional terms (ATC); MSEs and startups may get relaxations and EMD exemptions as stated in each bid; GeM transaction charges and rules change, so the official portal is the source of truth.`;

function systemPrompt(language: string, context: unknown) {
  const now = new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata" });
  return `You are Saathi, the assistant inside the Bid2Scale app. Today is ${now} IST.
${APP_GUIDE}

How to answer:
- Reply in ${LANGUAGES[language] ?? "English"}. Keep GeM terms (GeM, EMD, ATC, PAN, GST, Udyam, MSE, L1) in English.
- Be short and practical: a direct answer first, then at most 5 short bullet points. Plain text, no tables.
- Use the seller's data below to personalise answers (their sector, what they supply, readiness, calculator results, matching bids). Mention bid numbers when you refer to a bid.
- Only state facts that are in the data below or in the guide above. If something is not there (e.g. a bid's exact clause), say you don't have it and tell them where to check: the bid document on GeM or the relevant app screen.
- Eligibility and money: give guidance, never a guarantee. For legal or tax decisions suggest a CA.
- Never ask for or repeat PAN, Aadhaar, bank account numbers, passwords or OTPs. Remind them never to share a GeM OTP with anyone.
- Stay on the seller's business, GeM and this app. Politely decline unrelated requests.

The seller's data (JSON; may be partial):
${JSON.stringify(context)}`;
}

async function sellerContext(admin: any, asUser: any, userId: string) {
  const [profileRow, prefs, notes, bids] = await Promise.all([
    admin.from("profiles").select("state").eq("id", userId).maybeSingle(),
    admin.from("bid_alert_preferences")
      .select("keywords,states,in_app_enabled,email_enabled,whatsapp_opt_in")
      .eq("user_id", userId).maybeSingle(),
    admin.from("bid_notifications").select("title,body,created_at,read_at")
      .eq("user_id", userId).order("created_at", { ascending: false }).limit(10),
    asUser.rpc("my_matching_bids", { p_limit: 8 }),
  ]);
  const state = (profileRow.data?.state ?? {}) as Record<string, unknown>;
  const profile = pick((state.profile ?? {}) as Record<string, unknown>, PROFILE_KEYS);
  return {
    language: state.language ?? "en",
    alreadyOnGem: state.alreadyOnGem ?? null,
    profile,
    readinessChecklistDone: state.checklist ?? null,
    calculatorResults: pick(state, TOOL_KEYS),
    alertSettings: prefs.data ?? null,
    recentAlerts: (notes.data ?? []).map((n: any) => ({
      bid: clip(n.title, 120), detail: clip(n.body, 120), at: n.created_at,
      read: n.read_at != null,
    })),
    matchingOpenBids: (bids.data ?? []).map((b: any) => {
      const d = b.details ?? {};
      return {
        bidNumber: b.source_id, item: clip(b.title, 160), buyer: clip(b.organisation || b.buyer, 100),
        ministry: clip(b.ministry, 80), state: b.state, quantity: b.quantity,
        closesAtIST: new Date(b.closes_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }),
        documentsRequired: d.documents_required, experience: d.experience,
        turnover: d.bidder_turnover ?? d.oem_turnover, emd: d.emd_amount ?? d.emd_required,
        technicalClarificationTime: d.technical_clarification_time,
        evaluation: d.evaluation_method, mseRelaxation: d.mse_relaxation,
        buyerTerms: clip(d.atc, 600), link: b.source_url,
      };
    }),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return reply({ error: "not_configured" }, 503);

  const url = Deno.env.get("SUPABASE_URL")!;
  const auth = req.headers.get("Authorization") ?? "";
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: who } = await asUser.auth.getUser();
  if (!who?.user) return reply({ error: "sign_in_required" }, 401);
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  let body: { messages?: Turn[]; language?: string };
  try {
    body = await req.json();
  } catch {
    return reply({ error: "bad_request" }, 400);
  }
  const turns = (Array.isArray(body.messages) ? body.messages : [])
    .filter((t) => (t?.role === "user" || t?.role === "model") && typeof t.text === "string")
    .slice(-12)
    .map((t) => ({ role: t.role, text: clip(t.text, 2000) }))
    .filter((t) => t.text);
  if (!turns.length || turns[turns.length - 1].role !== "user") {
    return reply({ error: "bad_request" }, 400);
  }

  const { data: allowed, error: quotaError } = await admin.rpc("saathi_take_question", {
    p_user: who.user.id, p_daily_limit: DAILY_LIMIT,
  });
  if (quotaError) return reply({ error: "unavailable" }, 503);
  if (!allowed) return reply({ error: "daily_limit" }, 429);

  const context = await sellerContext(admin, asUser, who.user.id);
  const language = LANGUAGES[body.language ?? ""] ? body.language! : String(context.language);
  const gemini = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt(language, context) }] },
        contents: turns.map((t) => ({ role: t.role, parts: [{ text: t.text }] })),
        generationConfig: { temperature: 0.3, maxOutputTokens: 900 },
      }),
    },
  );
  if (!gemini.ok) {
    console.error("Gemini", gemini.status, (await gemini.text()).slice(0, 400));
    return reply({ error: "model_unavailable" }, 502);
  }
  const result = await gemini.json();
  const answer = (result?.candidates?.[0]?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "").join("").trim();
  if (!answer) return reply({ error: "no_answer" }, 502);
  return reply({ answer });
});

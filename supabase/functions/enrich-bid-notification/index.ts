import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// enrich-bid-notification
//
// Called by a Supabase Database Webhook on INSERT to bid_notifications.
// Payload: { type: "INSERT", record: { id, source_url, ... } }
//
// 1. Fetches the GeM bid PDF from source_url
// 2. Extracts ministry, bid_start_date, bid_end_date, eligibility via regex
// 3. UPDATEs the bid_notifications row with the extracted fields
// ---------------------------------------------------------------------------

const MONTH_MAP: Record<string, string> = {
  jan: "01", feb: "02", mar: "03", apr: "04", may: "05", jun: "06",
  jul: "07", aug: "08", sep: "09", oct: "10", nov: "11", dec: "12",
};

// Attempt to normalise a date string found in the PDF to ISO-8601 (YYYY-MM-DD).
// Handles common GeM formats: "15/11/2024", "15-11-2024", "15 Nov 2024", "Nov 15, 2024"
function normDate(raw: string): string | null {
  raw = raw.trim();
  // dd/mm/yyyy or dd-mm-yyyy
  const dmy = raw.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
  if (dmy) return `${dmy[3]}-${dmy[2].padStart(2, "0")}-${dmy[1].padStart(2, "0")}`;
  // dd Mon yyyy  or  Mon dd, yyyy
  const alpha = raw.match(
    /^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})$|^([A-Za-z]{3})\s+(\d{1,2}),?\s+(\d{4})$/
  );
  if (alpha) {
    const [, d1, m1, y1, m2, d2, y2] = alpha;
    const day = (d1 ?? d2).padStart(2, "0");
    const mon = MONTH_MAP[(m1 ?? m2).toLowerCase()];
    const yr = y1 ?? y2;
    if (mon) return `${yr}-${mon}-${day}`;
  }
  return null;
}

// Pull plain text out of a PDF buffer using a lightweight streaming parse.
// Only reads the stream objects — good enough for text-heavy government PDFs.
function pdfToText(buf: Uint8Array): string {
  const str = new TextDecoder("latin1").decode(buf);
  const chunks: string[] = [];
  // Extract text from BT ... ET blocks (PDF content streams)
  const btRe = /BT([\s\S]*?)ET/g;
  let m: RegExpExecArray | null;
  while ((m = btRe.exec(str)) !== null) {
    // Tj / TJ operators carry the visible text
    const tjRe = /\(([^)]*)\)\s*Tj|\[((?:[^[\]]*\([^)]*\)[^[\]]*)*)\]\s*TJ/g;
    let tj: RegExpExecArray | null;
    while ((tj = tjRe.exec(m[1])) !== null) {
      const seg = tj[1] ?? tj[2];
      // Unescape common PDF string escapes
      chunks.push(seg.replace(/\\n/g, "\n").replace(/\\r/g, " ").replace(/\\\(/g, "(").replace(/\\\)/g, ")").replace(/\\\\/g, "\\"));
    }
  }
  return chunks.join(" ");
}

// --- Field extractors -------------------------------------------------------

function extractMinistry(text: string): string | null {
  // GeM PDFs typically open with "Ministry of …" or "M/o …" in the header
  const patterns = [
    /Ministry\s+of\s+([A-Z][^\n,]{3,60})/i,
    /M\/o\s+([A-Z][^\n,]{3,60})/i,
    /Department\s+of\s+([A-Z][^\n,]{3,60})/i,
  ];
  for (const p of patterns) {
    const m = text.match(p);
    if (m) return m[0].trim().replace(/\s+/g, " ").slice(0, 80);
  }
  return null;
}

function extractDate(text: string, labels: string[]): string | null {
  for (const label of labels) {
    const re = new RegExp(label + "[:\\s]+([\\d]{1,2}[\\s\\/\\-][A-Za-z\\d]{2,3}[\\s\\/\\-][\\d]{4})", "i");
    const m = text.match(re);
    if (m) {
      const iso = normDate(m[1]);
      if (iso) return iso;
    }
  }
  return null;
}

function extractEligibility(text: string): string | null {
  // Find the first substantial sentence after an "Eligibility" heading
  const m = text.match(/Eligibility[^:]*:?\s*([A-Z][^.\n]{20,}[.?\n])/i);
  if (m) return m[1].trim().slice(0, 120);
  // Fallback: look for MSME / seller-category mentions
  const msme = text.match(/((?:MSME|micro|small|medium|seller)[^.\n]{10,}[.?\n])/i);
  if (msme) return msme[1].trim().slice(0, 120);
  return null;
}

function extractDeliveryArea(text: string): string | null {
  const labels = [
    "Delivery Location",
    "Consignee Location",
    "Place of Delivery",
    "Service Location",
    "Delivery Place",
  ];
  for (const label of labels) {
    const re = new RegExp(label + "[:\\s]+([A-Z][^\\n,]{2,60})", "i");
    const m = text.match(re);
    if (m) return m[1].trim().slice(0, 60);
  }
  return null;
}

// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: { type?: string; record?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  if (payload.type !== "INSERT" || !payload.record) {
    return new Response("Not an INSERT event", { status: 200 });
  }

  const record = payload.record;
  const id = record["id"] as string;
  const sourceUrl = record["source_url"] as string | undefined;

  if (!id || !sourceUrl) {
    return new Response("Missing id or source_url", { status: 200 });
  }

  // Initialise Supabase admin client (service role key injected as a secret)
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Fetch the PDF
  let pdfText = "";
  try {
    const resp = await fetch(sourceUrl, {
      headers: { "User-Agent": "Bid2Scale/1.0" },
      signal: AbortSignal.timeout(20_000),
    });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const bytes = new Uint8Array(await resp.arrayBuffer());
    pdfText = pdfToText(bytes);
  } catch (err) {
    console.error("PDF fetch failed:", err);
    // Non-fatal — still update the row with nulls so we don't retry endlessly
  }

  // Parse ministry + delivery_area from body field as a reliable fallback.
  // body format: "Buyer · [Location · ] GEM/YYYY/B/NNNNNNN"
  const bodyStr = (record["body"] as string | undefined) ?? "";
  const bodyParts = bodyStr.split(" · ");
  const bodyMinistry =
    bodyParts.length >= 1 && !bodyParts[0].startsWith("GEM/")
      ? bodyParts[0].trim()
      : null;
  const bodyLocation =
    bodyParts.length >= 3 && !bodyParts[1].startsWith("GEM/")
      ? bodyParts[1].trim()
      : null;

  const updates: Record<string, string | null> = {
    // PDF/HTML extraction first; fall back to body parsing if null
    ministry: extractMinistry(pdfText) ?? bodyMinistry,
    bid_start_date: extractDate(pdfText, [
      "Bid Start Date", "Start Date", "Opening Date", "Bid Opening",
    ]),
    bid_end_date: extractDate(pdfText, [
      "Bid End Date", "End Date", "Closing Date", "Bid Closing", "Last Date",
    ]),
    eligibility: extractEligibility(pdfText),
    delivery_area: extractDeliveryArea(pdfText) ?? bodyLocation,
  };

  const { error } = await supabase
    .from("bid_notifications")
    .update(updates)
    .eq("id", id);

  if (error) {
    console.error("Supabase update failed:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true, id, updates }), {
    headers: { "Content-Type": "application/json" },
  });
});

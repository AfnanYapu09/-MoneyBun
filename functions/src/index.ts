/**
 * MoneyBun Cloud Functions.
 *
 * `verifySlip` proxies a Thai slip-verify provider (EasySlip by default; SlipOK
 * is a drop-in alternative) so the API key stays server-side and never ships in
 * the app. It accepts either a QR payload (preferred — exact and cheap) or a
 * base64 image, and returns a normalized result the Flutter app understands.
 *
 * Setup:
 *   firebase functions:secrets:set EASYSLIP_TOKEN
 *   firebase deploy --only functions
 */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";

admin.initializeApp();

const EASYSLIP_TOKEN = defineSecret("EASYSLIP_TOKEN");

// EasySlip verify endpoint. Override via the EASYSLIP_URL env var if needed.
const EASYSLIP_URL =
  process.env.EASYSLIP_URL ?? "https://developer.easyslip.com/api/v1/verify";

interface VerifyRequest {
  payload?: string;
  imageBase64?: string;
}

interface NormalizedSlip {
  verified: boolean;
  amountCents: number | null;
  occurredAtMs: number | null;
  senderName: string | null;
  senderBank: string | null;
  receiverName: string | null;
  receiverBank: string | null;
  transRef: string | null;
  bankCode: string | null;
}

export const verifySlip = onCall(
  {secrets: [EASYSLIP_TOKEN], region: "asia-southeast1", cors: true},
  async (request): Promise<NormalizedSlip> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const data = (request.data ?? {}) as VerifyRequest;
    if (!data.payload && !data.imageBase64) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a QR payload or a base64 image."
      );
    }

    // Dedup cache by transaction ref to protect the provider's free tier.
    const cacheRef = data.payload ?
      admin.firestore().collection("slip_cache").doc(hash(data.payload)) :
      null;
    if (cacheRef) {
      const cached = await cacheRef.get();
      if (cached.exists) return cached.data() as NormalizedSlip;
    }

    const body: Record<string, string> = {};
    if (data.payload) body.payload = data.payload;
    if (data.imageBase64) body.image = data.imageBase64;

    let providerJson: unknown;
    try {
      const res = await fetch(EASYSLIP_URL, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${EASYSLIP_TOKEN.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
      providerJson = await res.json();
    } catch (err) {
      throw new HttpsError("unavailable", `Slip provider error: ${err}`);
    }

    const normalized = normalize(providerJson);
    if (cacheRef && normalized.verified) {
      await cacheRef.set(normalized).catch(() => undefined);
    }
    return normalized;
  }
);

/**
 * Map a provider response to {@link NormalizedSlip}. Written defensively against
 * the EasySlip v1 shape `{ data: { amount: { amount }, date, sender, receiver,
 * transRef } }`. Adjust the field paths here if your provider/plan differs.
 */
function normalize(json: unknown): NormalizedSlip {
  const root = (json ?? {}) as Record<string, unknown>;
  const d = (root.data ?? root) as Record<string, unknown>;

  // EasySlip nests as data.amount.amount (object); some plans return a flat number.
  const amount = pickNumber(d, ["amount", "amount"]) ?? pickNumber(d, ["amount"]);
  const dateStr = pickString(d, ["date"]) ?? pickString(d, ["dateTime"]);
  const sender = (d.sender ?? {}) as Record<string, unknown>;
  const receiver = (d.receiver ?? {}) as Record<string, unknown>;

  return {
    verified: true,
    amountCents: amount == null ? null : Math.round(amount * 100),
    occurredAtMs: dateStr ? Date.parse(dateStr) || null : null,
    senderName: accountName(sender),
    senderBank: bankName(sender),
    receiverName: accountName(receiver),
    receiverBank: bankName(receiver),
    transRef: pickString(d, ["transRef"]) ?? pickString(d, ["ref"]),
    bankCode: pickString(d, ["bankCode"]),
  };
}

function accountName(party: Record<string, unknown>): string | null {
  const account = (party.account ?? {}) as Record<string, unknown>;
  const name = (account.name ?? {}) as Record<string, unknown>;
  return (
    pickString(name, ["th"]) ??
    pickString(name, ["en"]) ??
    pickString(party, ["name"])
  );
}

function bankName(party: Record<string, unknown>): string | null {
  const bank = (party.bank ?? {}) as Record<string, unknown>;
  return pickString(bank, ["name"]) ?? pickString(bank, ["short"]);
}

function pickNumber(obj: Record<string, unknown>, path: string[]): number | null {
  let cur: unknown = obj;
  for (const key of path) {
    if (cur && typeof cur === "object" && key in cur) {
      cur = (cur as Record<string, unknown>)[key];
    } else {
      return null;
    }
  }
  return typeof cur === "number" ? cur : null;
}

function pickString(obj: Record<string, unknown>, path: string[]): string | null {
  let cur: unknown = obj;
  for (const key of path) {
    if (cur && typeof cur === "object" && key in cur) {
      cur = (cur as Record<string, unknown>)[key];
    } else {
      return null;
    }
  }
  return typeof cur === "string" ? cur : null;
}

/** Tiny stable hash for cache keys (not cryptographic). */
function hash(input: string): string {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (Math.imul(31, h) + input.charCodeAt(i)) | 0;
  }
  return `s${(h >>> 0).toString(16)}`;
}

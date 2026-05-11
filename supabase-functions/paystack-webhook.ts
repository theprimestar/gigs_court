import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { initializeApp, cert, getApps } from "npm:firebase-admin/app";
import { getFirestore, FieldValue } from "npm:firebase-admin/firestore";

const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

// Initialize Firebase Admin if not already initialized
if (getApps().length === 0) {
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
  initializeApp({
    credential: cert(serviceAccount),
  });
}

const firestore = getFirestore();

serve(async (req) => {
  try {
    const body = await req.json();

    // Only process successful charges
    if (body.event !== "charge.success") {
      return new Response(JSON.stringify({ message: "Not a charge.success event" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const reference = body.data.reference;

    // Verify with Paystack
    const verifyRes = await fetch(
      `https://api.paystack.co/transaction/verify/${reference}`,
      {
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        },
      }
    );
    const verifyData = await verifyRes.json();

    if (!verifyData.status || verifyData.data.status !== "success") {
      return new Response(JSON.stringify({ error: "Verification failed" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const amount = verifyData.data.amount;
    const metadata = verifyData.data.metadata || {};
    const userId = metadata.user_id;
    const credits = metadata.credits;

    if (!userId || !credits) {
      return new Response(JSON.stringify({ error: "Missing metadata" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Update Firestore
    await firestore.collection("profiles").doc(userId).update({
      credits: FieldValue.increment(credits),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Record purchase
    await firestore.collection("credit_purchases").add({
      user_id: userId,
      amount_paid: amount,
      credits_purchased: credits,
      paystack_reference: reference,
      status: "completed",
      created_at: FieldValue.serverTimestamp(),
    });

    return new Response(JSON.stringify({ success: true, credits }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { GoogleAuth } from "npm:google-auth-library@9"

const PAYSTACK_SECRET_KEY = Deno.env.get('PAYSTACK_SECRET_KEY')!
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!
const PROJECT_ID = "the-gigscourt-project"
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`

const auth = new GoogleAuth({
  credentials: JSON.parse(FIREBASE_SERVICE_ACCOUNT),
  scopes: ["https://www.googleapis.com/auth/datastore"],
})

async function firestoreRequest(method: string, url: string, body?: any) {
  const client = await auth.getClient()
  const token = await client.getAccessToken()
  
  const headers: any = {
    'Authorization': `Bearer ${token.token}`,
    'Content-Type': 'application/json',
  }
  
  return fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  })
}

serve(async (req) => {
  try {
    const bodyText = await req.text()
    
    // Verify Paystack signature
    const signature = req.headers.get("x-paystack-signature")
    if (!signature) {
      return new Response(JSON.stringify({ error: "Missing signature" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      })
    }

    const encoder = new TextEncoder()
    const keyData = encoder.encode(PAYSTACK_SECRET_KEY)
    const cryptoKey = await crypto.subtle.importKey(
      "raw", keyData, { name: "HMAC", hash: "SHA-512" }, false, ["sign"]
    )
    const sigBuffer = await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(bodyText))
    const expectedSignature = Array.from(new Uint8Array(sigBuffer))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("")

    if (signature !== expectedSignature) {
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      })
    }

    const body = JSON.parse(bodyText)

    if (body.event !== "charge.success") {
      return new Response(JSON.stringify({ message: "Not a charge.success event" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    const reference = body.data.reference

    // Verify with Paystack
    const verifyRes = await fetch(
      `https://api.paystack.co/transaction/verify/${reference}`,
      { headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` } }
    )
    const verifyData = await verifyRes.json()

    if (!verifyData.status || verifyData.data.status !== "success") {
      return new Response(JSON.stringify({ error: "Verification failed" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      })
    }

    const amount = verifyData.data.amount
    const metadata = verifyData.data.metadata || {}
    const userId = metadata.user_id
    const credits = metadata.credits

    if (!userId || !credits) {
      return new Response(JSON.stringify({ error: "Missing metadata" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      })
    }

    // IDEMPOTENCY: Try to create purchase document with reference as ID
    const purchaseRes = await firestoreRequest(
      'POST',
      `${FIRESTORE_BASE}/credit_purchases?documentId=${encodeURIComponent(reference)}`,
      {
        fields: {
          user_id: { stringValue: userId },
          credits_purchased: { integerValue: String(credits) },
          amount_paid: { integerValue: String(amount) },
          paystack_reference: { stringValue: reference },
          status: { stringValue: "completed" },
          created_at: { timestampValue: new Date().toISOString() }
        }
      }
    )

    if (purchaseRes.status === 409) {
      return new Response(JSON.stringify({ message: "Already processed" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    }

    if (purchaseRes.status !== 200) {
      return new Response(JSON.stringify({ error: "Failed to record purchase" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      })
    }

    // ATOMIC INCREMENT using documents:commit
    await firestoreRequest(
      'POST',
      `${FIRESTORE_BASE}:commit`,
      {
        writes: [
          {
            transform: {
              document: `projects/${PROJECT_ID}/databases/(default)/documents/profiles/${userId}`,
              fieldTransforms: [
                {
                  fieldPath: "credits",
                  increment: { integerValue: credits }
                },
                {
                  fieldPath: "updatedAt",
                  setToServerValue: "REQUEST_TIME"
                }
              ]
            }
          }
        ]
      }
    )

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  } catch (error) {
    console.error("Webhook error:", error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";

const FIREBASE_PROJECT_ID = "the-gigscourt-project";

// Supabase JWT signing secret (provided by Supabase runtime)
const SUPABASE_JWT_SECRET = Deno.env.get("SUPABASE_JWT_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

serve(async (req: Request) => {
  try {
    const { firebase_token } = await req.json();

    // 1. Fetch Firebase public keys
    const res = await fetch(
      "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    );
    const googleKeys = await res.json();

    // 2. Verify Firebase JWT
    const { payload } = await jose.jwtVerify(
      firebase_token,
      jose.createLocalJWKSet(googleKeys),
      {
        issuer: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
        audience: FIREBASE_PROJECT_ID,
      }
    );

    const firebaseUid = payload.sub;

    // 3. Create Supabase client and mint a new JWT
    const supabaseAdmin = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Generate Supabase JWT for this Firebase user
    const secret = new TextEncoder().encode(SUPABASE_JWT_SECRET);
    const supabaseToken = await new jose.SignJWT({
      sub: firebaseUid,
      role: "authenticated",
      aud: "authenticated",
    })
      .setProtectedHeader({ alg: "HS256" })
      .setExpirationTime("1h")
      .sign(secret);

    return new Response(
      JSON.stringify({ supabase_token: supabaseToken }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }
});

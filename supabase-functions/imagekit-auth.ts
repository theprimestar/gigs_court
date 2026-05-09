import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  const privateKey = Deno.env.get("IMAGEKIT_PRIVATE_KEY");
  if (!privateKey) {
    return new Response(
      JSON.stringify({ error: "Private key not configured" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  const token = btoa(`${privateKey}:`);
  const expire = Math.floor(Date.now() / 1000) + 3600;

  return new Response(
    JSON.stringify({ token, expire }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});

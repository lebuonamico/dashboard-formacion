import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Método no permitido." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  const bearer = authorization?.match(/^Bearer\s+(\S+)$/i);
  if (!bearer) return json({ error: "Sesión requerida." }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key) {
    return json({ error: "Servicio no disponible." }, 503);
  }

  try {
    // All database reads use the caller's JWT and remain subject to RLS.
    const supabase = createClient(url, key, {
      global: { headers: { Authorization: authorization! } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await supabase.auth.getUser(bearer[1]);
    if (authError || !user?.email) {
      return json({ error: "Sesión inválida." }, 401);
    }

    const { data: allowed, error: allowlistError } = await supabase
      .schema("public")
      .from("usuarios_autorizados")
      .select("activo")
      .eq("email", user.email.trim().toLowerCase())
      .eq("activo", true)
      .is("ff_bloqueo", null)
      .is("ff_eliminar", null)
      .maybeSingle();
    if (allowlistError) {
      return json({ error: "No se pudo validar el acceso." }, 503);
    }
    if (!allowed) return json({ error: "Acceso denegado." }, 403);

    const token = Deno.env.get("MOODLE_TOKEN");
    if (!token) return json({ error: "Servicio no disponible." }, 503);

    // The caller cannot choose credentials, endpoint or Moodle operation.
    const upstream = await fetch(
      "https://academia-test.finneg.com/webservice/rest/server.php",
      {
        method: "POST",
        body: new URLSearchParams({
          wstoken: token,
          wsfunction: "core_course_get_courses",
          moodlewsrestformat: "json",
        }),
        signal: AbortSignal.timeout(25_000),
      },
    );
    if (!upstream.ok) {
      return json({ error: "No se pudieron consultar los cursos." }, 502);
    }
    const courses: unknown = await upstream.json();
    if (!Array.isArray(courses)) {
      return json({ error: "No se pudieron consultar los cursos." }, 502);
    }

    return json(courses
      .filter((course) => course !== null && typeof course === "object" &&
        (typeof course.id === "number" || typeof course.id === "string") &&
        typeof course.fullname === "string")
      .map((course) => ({ id: course.id, fullname: course.fullname })));
  } catch {
    // Never return upstream errors, URLs, credentials or database details.
    return json({ error: "No se pudieron consultar los cursos." }, 502);
  }
});

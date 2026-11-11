// Edge Function `notificar-pendientes`.
//
// Recibe legajos e IDs de curso desde el dashboard y le manda a cada persona
// un mail con sus cursos pendientes en el LMS, usando Resend.
//
// Seguridad:
// - Lee los datos con el JWT de quien llama, así RLS aplica su alcance: un
//   líder solo puede notificar a las personas que ve en la app.
// - Ignora mails o nombres que pudiera mandar el cliente: los toma de
//   `empleados` y vuelve a confirmar en `finalizaciones_cursos` que cada curso
//   siga pendiente.
// - La clave de Resend y la service role solo existen en el servidor.
//
// Secrets: RESEND_API_KEY y RESEND_FROM (obligatorios), LMS_URL (opcional).
// SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY los inyecta
// Supabase.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const MAX_RECIPIENTS = 500;
const MAX_COURSES_PER_RECIPIENT = 100;
const MAX_ID_LENGTH = 100;
const RESEND_BATCH_SIZE = 100;
const PAGE_SIZE = 1000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Recipient = { legajo: string; cursos: string[] };

type Email = {
  legajo: string;
  correo: string;
  nombre: string;
  cursos: string[];
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

const isId = (value: unknown): value is string =>
  typeof value === "string" &&
  value.trim().length > 0 &&
  value.length <= MAX_ID_LENGTH;

/** Null when the body does not have the expected shape. */
function parseRecipients(body: unknown): Recipient[] | null {
  const list = (body as { destinatarios?: unknown } | null)?.destinatarios;
  if (!Array.isArray(list) || list.length === 0) return null;
  if (list.length > MAX_RECIPIENTS) return null;
  const recipients: Recipient[] = [];
  for (const item of list) {
    const { legajo, cursos } = (item ?? {}) as Record<string, unknown>;
    if (!isId(legajo) || !Array.isArray(cursos)) return null;
    if (cursos.length === 0 || cursos.length > MAX_COURSES_PER_RECIPIENT) {
      return null;
    }
    if (!cursos.every(isId)) return null;
    recipients.push({
      legajo: legajo.trim(),
      cursos: [...new Set(cursos.map((id) => id.trim()))],
    });
  }
  return recipients;
}

/** PostgREST caps each response: reads every page. */
async function readAll<T>(
  page: (from: number, to: number) => PromiseLike<{
    data: T[] | null;
    error: unknown;
  }>,
): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await page(from, from + PAGE_SIZE - 1);
    if (error) throw error;
    rows.push(...(data ?? []));
    if (!data || data.length < PAGE_SIZE) return rows;
  }
}

async function isAuthorized(
  client: SupabaseClient,
  email: string,
): Promise<boolean> {
  const { data, error } = await client
    .from("usuarios_autorizados")
    .select("activo,ff_eliminar,ff_bloqueo")
    .eq("email", email.trim().toLowerCase())
    .maybeSingle();
  if (error) throw error;
  return data?.activo === true && data.ff_eliminar == null &&
    data.ff_bloqueo == null;
}

/** Only what the caller can see and is still pending. */
async function buildEmails(
  client: SupabaseClient,
  recipients: Recipient[],
): Promise<{ emails: Email[]; skipped: number }> {
  const legajos = recipients.map((r) => r.legajo);
  const courseIds = [...new Set(recipients.flatMap((r) => r.cursos))];

  const [employees, pending, courses] = await Promise.all([
    readAll<{
      legajo: unknown;
      nombre: string | null;
      apellido: string | null;
      correo: string | null;
      activo: boolean | null;
    }>((from, to) =>
      client
        .from("empleados")
        .select("legajo,nombre,apellido,correo,activo")
        .in("legajo", legajos)
        .order("legajo")
        .range(from, to)
    ),
    readAll<{ legajo: unknown; curso_id: unknown }>((from, to) =>
      client
        .from("finalizaciones_cursos")
        .select("legajo,curso_id")
        .in("legajo", legajos)
        .eq("finalizo", false)
        .order("legajo")
        .order("curso_id")
        .range(from, to)
    ),
    readAll<{ id_curso: unknown; nombre: string | null }>((from, to) =>
      client
        .from("cursos")
        .select("id_curso,nombre")
        .in("id_curso", courseIds)
        .order("id_curso")
        .range(from, to)
    ),
  ]);

  const employeeById = new Map(employees.map((e) => [String(e.legajo), e]));
  const courseName = new Map(
    courses.map((c) => [String(c.id_curso), (c.nombre ?? "").trim()]),
  );
  const pendingPairs = new Set(
    pending.map((p) => `${String(p.legajo)}|${String(p.curso_id)}`),
  );

  const emails: Email[] = [];
  let skipped = 0;
  for (const recipient of recipients) {
    const employee = employeeById.get(recipient.legajo);
    const correo = (employee?.correo ?? "").trim();
    const names = recipient.cursos
      .filter((id) => pendingPairs.has(`${recipient.legajo}|${id}`))
      .map((id) => courseName.get(id) || id)
      .sort((a, b) => a.localeCompare(b, "es"));
    if (
      !employee || employee.activo !== true || !/^\S+@\S+\.\S+$/.test(correo) ||
      names.length === 0
    ) {
      skipped++;
      continue;
    }
    emails.push({
      legajo: recipient.legajo,
      correo,
      nombre: (employee.nombre ?? "").trim(),
      cursos: names,
    });
  }
  return { emails, skipped };
}

function message(email: Email, from: string, lmsUrl: string | undefined) {
  const greeting = email.nombre ? `Hola ${email.nombre},` : "Hola,";
  const intro = email.cursos.length === 1
    ? "Te recordamos que tenés pendiente este curso en el LMS:"
    : "Te recordamos que tenés pendientes estos cursos en el LMS:";
  const link = lmsUrl
    ? `<p><a href="${escapeHtml(lmsUrl)}">Ir al LMS</a></p>`
    : "";
  const html = `<p>${escapeHtml(greeting)}</p>
<p>${intro}</p>
<ul>${email.cursos.map((c) => `<li>${escapeHtml(c)}</li>`).join("")}</ul>
${link}
<p>¡Gracias!<br>Academia Finnegans</p>`;
  const text = [
    greeting,
    "",
    intro,
    ...email.cursos.map((c) => `- ${c}`),
    "",
    ...(lmsUrl ? [`Ir al LMS: ${lmsUrl}`, ""] : []),
    "¡Gracias!",
    "Academia Finnegans",
  ].join("\n");
  return {
    from,
    to: [email.correo],
    subject: email.cursos.length === 1
      ? "Tenés un curso pendiente en el LMS"
      : "Tenés cursos pendientes en el LMS",
    html,
    text,
  };
}

type SendOutcome = { email: Email; id: string | null; error: string | null };

async function sendWithResend(
  emails: Email[],
  apiKey: string,
  from: string,
  lmsUrl: string | undefined,
): Promise<{ outcomes: SendOutcome[]; rateLimited: boolean }> {
  const outcomes: SendOutcome[] = [];
  let rateLimited = false;
  for (let start = 0; start < emails.length; start += RESEND_BATCH_SIZE) {
    // Resend limits requests per second.
    if (start > 0) await new Promise((resolve) => setTimeout(resolve, 600));
    const chunk = emails.slice(start, start + RESEND_BATCH_SIZE);
    try {
      const response = await fetch("https://api.resend.com/emails/batch", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(chunk.map((e) => message(e, from, lmsUrl))),
      });
      if (!response.ok) {
        if (response.status === 429) rateLimited = true;
        const detail = `resend_${response.status}`;
        console.error("Resend rechazó el lote", response.status,
          await response.text());
        outcomes.push(...chunk.map((email) => ({ email, id: null, error: detail })));
        continue;
      }
      const body = await response.json() as { data?: { id?: string }[] };
      chunk.forEach((email, i) =>
        outcomes.push({ email, id: body.data?.[i]?.id ?? null, error: null })
      );
    } catch (error) {
      console.error("No se pudo llamar a Resend", error);
      outcomes.push(...chunk.map((email) => ({ email, id: null, error: "fetch" })));
    }
  }
  return { outcomes, rateLimited };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json(405, { code: "METHOD_NOT_ALLOWED" });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json(401, { code: "UNAUTHENTICATED" });
  }

  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("RESEND_FROM");
  if (!apiKey || !from) {
    console.error("Faltan los secrets RESEND_API_KEY o RESEND_FROM");
    return json(503, { code: "EMAIL_NOT_CONFIGURED" });
  }
  const lmsUrl = Deno.env.get("LMS_URL") || undefined;

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  // The caller's client: every read goes through RLS.
  const userClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    },
  );

  const token = authorization.slice("Bearer ".length);
  const { data: userData, error: userError } = await userClient.auth.getUser(
    token,
  );
  const callerEmail = userData?.user?.email;
  if (userError || !callerEmail) {
    return json(401, { code: "UNAUTHENTICATED" });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json(400, { code: "INVALID_ARGUMENT" });
  }
  const recipients = parseRecipients(body);
  if (!recipients) return json(400, { code: "INVALID_ARGUMENT" });

  try {
    if (!await isAuthorized(userClient, callerEmail)) {
      return json(403, { code: "PERMISSION_DENIED" });
    }

    const { emails, skipped } = await buildEmails(userClient, recipients);
    if (emails.length === 0) {
      return json(200, { enviados: 0, fallidos: 0, omitidos: skipped });
    }

    const { outcomes, rateLimited } = await sendWithResend(
      emails,
      apiKey,
      from,
      lmsUrl,
    );
    const sent = outcomes.filter((o) => o.error == null).length;
    const failed = outcomes.length - sent;

    // The audit is written by the server only: clients cannot insert.
    const admin = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const { error: auditError } = await admin
      .from("notificaciones_pendientes")
      .insert(outcomes.map((o) => ({
        enviado_por: callerEmail.toLowerCase(),
        legajo: o.email.legajo,
        correo: o.email.correo,
        cursos: o.email.cursos,
        estado: o.error == null ? "enviado" : "error",
        resend_id: o.id,
        detalle: o.error,
      })));
    // The emails already left: a failed audit is logged, not reported.
    if (auditError) console.error("No se pudo registrar la auditoría", auditError);

    if (sent === 0 && rateLimited) {
      return json(429, { code: "RESOURCE_EXHAUSTED" });
    }
    return json(200, { enviados: sent, fallidos: failed, omitidos: skipped });
  } catch (error) {
    // Never echo internal errors to the browser.
    console.error("Error al notificar pendientes", error);
    return json(500, { code: "INTERNAL" });
  }
});

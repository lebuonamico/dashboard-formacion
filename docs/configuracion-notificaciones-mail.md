# Configuración de las notificaciones por mail

Este instructivo explica cómo poner en marcha y mantener los avisos de cursos pendientes del Dashboard de Formación. Está pensado para quien administra el proyecto de Supabase y el dominio de mail de la empresa, aunque no conozca el código.

## Qué hace la funcionalidad

En **Certificaciones LMS**, el botón **Notificar pendientes por mail** le manda a cada colaborador filtrado un mail con los cursos que todavía tiene **pendientes** en el LMS. Antes de enviar, la app muestra quién lo recibe y con qué cursos.

```text
App (navegador) ──legajos e IDs de curso──▶ Edge Function "notificar-pendientes" (Supabase)
                                              │  lee mails y estados con los permisos del usuario (RLS)
                                              ├──▶ Resend (envía los mails)
                                              └──▶ tabla notificaciones_pendientes (auditoría)
```

- La app **nunca** conoce la clave de Resend. Solo la tiene la Edge Function.
- Cada usuario solo puede notificar a quienes ve en la app: un líder, solo a su área o equipo.
- Cada envío queda registrado en la tabla `notificaciones_pendientes`.

El código Flutter **no hace falta tocarlo** para nada de lo que sigue.

## Requisitos

| Qué | Para qué |
| --- | --- |
| Acceso de administrador al proyecto de **Supabase** | Cargar secrets, correr SQL y desplegar la función |
| Una cuenta de **Resend** ([resend.com](https://resend.com)) | Es el servicio que envía los mails |
| Acceso al panel **DNS** del dominio remitente (por ejemplo, el de `empresa.com`) | Verificar el dominio en Resend |
| **Node.js** instalado | Usar la CLI de Supabase con `npx` |
| Este repositorio | Contiene la función y el SQL |

Archivos involucrados:
- [supabase/functions/notificar-pendientes/index.ts](../supabase/functions/notificar-pendientes/index.ts): la Edge Function, incluido el texto del mail.
- [supabase/sql/notificaciones_pendientes.sql](../supabase/sql/notificaciones_pendientes.sql): la tabla de auditoría.

## Configuración inicial

Se hace una sola vez por proyecto de Supabase. En los comandos, `<REF>` es el identificador del proyecto: la parte de la URL antes de `.supabase.co`. Por ejemplo, en `https://abcdxyz.supabase.co` el `<REF>` es `abcdxyz`.

### 1. Verificar el dominio en Resend

Así Gmail y Outlook aceptan los mails como legítimos y no los mandan a spam.

1. En Resend, entrá a **Domains → Add Domain**.
2. Escribí un **subdominio** dedicado, por ejemplo `notificaciones.empresa.com`. Usar un subdominio evita tocar la configuración del mail principal de la empresa.
3. Resend muestra varios registros DNS (de tipo TXT y MX): el **SPF**, que autoriza a Resend a enviar por ese dominio, y el **DKIM**, la clave pública con la que se verifica la firma de cada mail. Cargalos tal cual en el panel DNS del dominio.
4. Volvé a Resend y tocá **Verify**. La propagación puede tardar desde minutos hasta unas horas. Cuando el dominio figure como **Verified**, seguí.

### 2. Crear la API key de Resend

1. En Resend, entrá a **API Keys → Create API Key**.
2. Permission: **Sending access**. Domain: el dominio verificado.
3. Copiá la clave (`re_...`): **se muestra una sola vez**. Guardala en un gestor de contraseñas.

### 3. Cargar los secrets en Supabase

En el panel de Supabase: **Edge Functions → Secrets** (o **Project Settings → Edge Functions**, según la versión del panel).

| Name | Value | Obligatorio |
| --- | --- | --- |
| `RESEND_API_KEY` | La clave `re_...` | Sí |
| `RESEND_FROM` | Nombre y remitente, por ejemplo `Academia <academia@notificaciones.empresa.com>`. El dominio tiene que ser **el verificado** | Sí |
| `LMS_URL` | La dirección del LMS (por ejemplo, `https://lms.empresa.com`). Si está cargada, el mail incluye un enlace "Ir al LMS" | No |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` las inyecta Supabase automáticamente: **no hay que cargarlas**.

Se recomienda cargar los secrets desde el panel y no por comando, para que la clave no quede en el historial de la terminal.

### 4. Crear la tabla de auditoría

1. En Supabase, entrá a **SQL Editor → New query**.
2. Pegá el contenido de `supabase/sql/notificaciones_pendientes.sql` y tocá **Run**.
3. Supabase advierte de "operaciones destructivas" por las líneas `drop policy if exists` y `revoke`. Es esperable: solo afectan a esta tabla nueva y no borran datos. Confirmá con **Run query**.
4. El resultado esperado es: *Success. No rows returned*.

El script se puede correr más de una vez sin problema.

### 5. Desplegar la función

Desde la raíz del repositorio, en una terminal:

```console
npx supabase login
npx supabase functions deploy notificar-pendientes --remote=<REF> --use-api
```

- `login` abre el navegador para autorizar la CLI. Se hace una vez por computadora.
- `deploy` sube la función. Si la CLI pide confirmación, respondé que sí.
- Dejá activada la verificación de JWT, que es el valor por defecto. Es lo que exige que quien llama tenga una sesión válida.

### 6. Probar

1. Iniciá sesión en el Dashboard con un usuario autorizado.
2. En **Certificaciones LMS**, filtrá por **Persona** a un colaborador de prueba con un curso pendiente y tocá **Notificar pendientes por mail**.
3. Revisá el pop-up y tocá **Enviar 1 mail**. La app debería avisar *"Se envió 1 mail."*.
4. Comprobá:
   - que el mail llegó a la bandeja;
   - que en Supabase, **Table Editor → `notificaciones_pendientes`**, aparece una fila con `estado = enviado`;
   - que en Resend, en la sección **Emails**, figura el envío como *Delivered*.

## Qué tocar cuando algo cambia

| Situación | Qué hacer | ¿Redesplegar la función? |
| --- | --- | --- |
| **Cambia el remitente** (otro nombre u otra dirección del mismo dominio) | Editar el secret `RESEND_FROM` | No |
| **Cambia el dominio** | Verificar el dominio nuevo en Resend (paso 1) y actualizar `RESEND_FROM` | No |
| **Rotar la API key** (vence, se filtró o cambia el responsable) | En Resend, crear una clave nueva, reemplazar el valor de `RESEND_API_KEY` en Supabase y **borrar la clave vieja** en Resend | No |
| **Agregar o cambiar el enlace al LMS** | Editar el secret `LMS_URL` | No |
| **Cambiar el texto, el asunto o la firma del mail** | Editar la función `message` en `supabase/functions/notificar-pendientes/index.ts` | **Sí** (paso 5) |
| **Cambiar de cuenta de Resend** | Verificar el dominio en la cuenta nueva y reemplazar `RESEND_API_KEY` | No |
| **Mudar la app a otro proyecto de Supabase** | En el proyecto nuevo, repetir los pasos 3, 4 y 5 con su `<REF>` | Sí, en el proyecto nuevo |
| **Se envían más mails que los que permite el plan de Resend** | Revisar los límites diarios y mensuales del plan en Resend y cambiar de plan si hace falta | No |
| **Cambiar quién puede leer la auditoría** | Editar la política `notificaciones_pendientes_select` del SQL y volver a correrlo. Hoy la leen Administrador y Academia | No |

Los cambios de secrets se aplican a los envíos siguientes, sin redesplegar la función ni la app.

## Cómo diagnosticar problemas

Hay tres lugares donde mirar:
1. **El mensaje de la app** después de enviar.
2. **La tabla `notificaciones_pendientes`**: la columna `detalle` dice por qué falló cada mail.
3. **Los logs de la función**: en Supabase, **Edge Functions → notificar-pendientes → Logs**. Ahí aparece la respuesta completa de Resend cuando rechaza un envío.

| Mensaje en la app | Causa probable | Solución |
| --- | --- | --- |
| *El envío de mails no está configurado en el servidor.* | Faltan `RESEND_API_KEY` o `RESEND_FROM` | Cargar los secrets (paso 3) |
| *No tenés permiso para enviar notificaciones.* | El usuario no está activo en `usuarios_autorizados`, o está bloqueado o eliminado | Revisarlo en el Panel de administración |
| *La sesión venció. Volvé a iniciar sesión.* | La sesión de Google o Supabase expiró | Cerrar sesión y volver a entrar |
| *Se alcanzó el límite de envíos. Probá más tarde.* | Resend limitó la cantidad de envíos (por segundo o por día) | Esperar, o revisar el plan de Resend |
| *No hubo respuesta del servidor.* | Problema de red o la función tardó demasiado | Reintentar; si persiste, mirar los logs |
| *No se enviaron los mails. Intentá nuevamente.* | Error inesperado; también aparece si la función **no está desplegada** | Verificar que `notificar-pendientes` figure en **Edge Functions** y revisar los logs |
| *Se enviaron 0 mails (N con error).* | Resend rechazó los mails. Ver `detalle` en la auditoría (tabla siguiente) | — |
| *… (N sin enviar).* | Al volver a revisar, la función descartó personas: sin mail o inactivas en la nómina, el curso ya figura finalizado o el usuario no tiene alcance sobre esa persona | Es el comportamiento esperado; revisar la nómina si no debería pasar |

Valores de `detalle` en `notificaciones_pendientes`:

| `detalle` | Significado | Solución |
| --- | --- | --- |
| `resend_401` | API key inválida o borrada | Generar una nueva y actualizar `RESEND_API_KEY` |
| `resend_403` | El dominio de `RESEND_FROM` no está verificado, o se usa el remitente de prueba `onboarding@resend.dev`, que solo puede escribirle al dueño de la cuenta | Verificar el dominio (paso 1) y usarlo en `RESEND_FROM` |
| `resend_422` | `RESEND_FROM` está mal escrito o algún dato del mail es inválido | Revisar el formato: `Nombre <direccion@dominio>` |
| `resend_429` | Límite de envíos de Resend | Esperar o cambiar de plan |
| `fetch` | La función no pudo comunicarse con Resend | Reintentar; revisar el estado de Resend |

**Los mails llegan a spam:** verificar que el dominio figure como *Verified* en Resend y que `RESEND_FROM` use exactamente ese dominio. También ayuda agregar un registro **DMARC** al dominio; Resend explica cómo en la página del dominio.

## Seguridad

- La clave de Resend vive **solo** en los secrets de Supabase. Nunca se pone en la app, en `config/*.json` ni en el repositorio.
- La `service_role` de Supabase **nunca** se usa en la app. La función la usa del lado del servidor solo para escribir la auditoría.
- Si la clave de Resend se expone, hay que rotarla de inmediato, como se indica en "Qué tocar cuando algo cambia".

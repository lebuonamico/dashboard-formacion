# Dashboard de Formación · Finnegans

**Proyecto final de ORT** · Portal interno para el seguimiento de la formación de colaboradores.

El sistema reúne la nómina de empleados, el catálogo de cursos, las horas declaradas en CRM y las finalizaciones del LMS. Permite consultar el avance de la capacitación por persona, equipo y área, con indicadores de horas, objetivos y cumplimiento.

## Contenido

- [Tecnologías y módulos](#tecnologías-y-módulos)
- [Cómo ejecutar](#cómo-ejecutar)
- [Acceso, roles y seguridad](#acceso-roles-y-seguridad)
- [Reglas de negocio principales](#reglas-de-negocio-principales)
- [Importación de datos](#importación-de-datos)
- [Referencias QA](#referencias-qa)
- [Arquitectura y estructura](#arquitectura-y-estructura)
- [Asistente de IA](#asistente-de-ia)
- [Mejora futura](#mejora-futura)

## Tecnologías y módulos

| Tecnología | Uso |
| --- | --- |
| Flutter / Flutter Web y Dart | Interfaz y ejecución web en Chrome. |
| Riverpod (`Notifier`, `AsyncNotifier`, `FutureProvider`) | Estado, derivados y selección de dependencias. |
| go_router | Navegación (`go` entre secciones, `push` a los detalles) y protección de rutas. |
| Supabase / PostgreSQL | Persistencia remota y seguridad mediante RLS. |
| Google OAuth / Supabase Auth | Inicio de sesión y mantenimiento de la sesión. |
| SharedPreferencesAsync | Solo la preferencia de tema claro u oscuro. |
| excel, csv y file_picker | Selección y lectura de archivos. |
| pdf y printing | Reportes imprimibles de Dashboard, Equipos y Áreas. |

| Módulo | Función |
| --- | --- |
| Inicio / Dashboard | Resumen de formación, categorías, evolución mensual, proyección y avance por áreas. |
| Áreas | Consulta de áreas y detalle de sus colaboradores y equipos. |
| Equipos | Seguimiento mensual y anual, filtros y detalle por equipo. |
| Empleados | Nómina, búsqueda y perfil individual con su proyección a fin de año. |
| Cursos | Catálogo con personas, horas CRM y finalizaciones por curso. |
| Carga de horas CRM | Horas declaradas por colaborador y curso. |
| Certificaciones LMS | Finalizaciones por legajo o curso. |
| Configuración | Importación de las cuatro fuentes y editor del plan de formación por seniority. |
| Panel de administración | Usuarios autorizados y líderes de áreas y equipos (Administrador y Academia). |

## Cómo ejecutar

### Requisitos

- Flutter SDK con Dart **>= 3.11.3 y < 4.0.0**, según `pubspec.yaml`. No se fija una versión independiente de Flutter.
- Comandos `flutter` y `dart` disponibles en `PATH`.
- Google Chrome instalado.

Desde la raíz del proyecto, instalar las dependencias:

```console
flutter pub get
```

El runner Dart admite únicamente `local` y `supabase`, funciona en macOS, Windows y Linux y abre Chrome en **http://localhost:3000**.

### Desarrollo en modo local

```console
dart run tool/run.dart local
```

Ejecuta Flutter con `USE_SUPABASE=false`, sin conectar a Supabase. Cada feature usa un repositorio **en memoria** con un seed coherente: dos áreas, tres equipos, unos diez colaboradores con fecha de ingreso, cursos de las cuatro categorías, horas CRM, finalizaciones LMS, usuarios y líderes. En **julio, agosto y septiembre de 2026** se ven los tres estados de equipo (en objetivo, en riesgo y crítico); como el período inicial es el mes actual, hay que elegir esos meses.

Los datos importados viven mientras la app está abierta: recargar la página vuelve al seed. La pantalla inicial conserva su botón de acceso, que en este modo lleva al Dashboard sin Google OAuth.

### Desarrollo con Supabase real

Crear `config/supabase.local.json` a partir de [config/supabase.example.json](config/supabase.example.json) y completar:

| Nombre | Configuración |
| --- | --- |
| `USE_SUPABASE` | Establecer en `true` para utilizar el backend remoto. |
| `SUPABASE_URL` | URL del proyecto Supabase. |
| `SUPABASE_ANON_KEY` | Clave pública de cliente del proyecto; nunca `service_role`. |

Luego ejecutar:

```console
dart run tool/run.dart supabase
```

El runner carga el archivo mediante `--dart-define-from-file=config/supabase.local.json`. Si no existe, informa el problema y termina con código de salida `1`.

**`config/supabase.local.json` está ignorado por Git y no debe subirse al repositorio.**

### Verificación

```console
flutter analyze lib test
flutter test
```

`flutter analyze` sin rutas también revisa carpetas que no son de la app; para el código se usa `lib test`. Algunos tests de repositorios Supabase solo corren con `--dart-define=USE_SUPABASE=true` y una URL y clave de prueba.

## Acceso, roles y seguridad

```text
Google OAuth → Supabase Auth → usuarios_autorizados → Dashboard
```

- Flutter consulta `public.usuarios_autorizados` por el email autenticado y exige que esté activo, sin bloqueo ni eliminación, antes de mostrar las rutas privadas. Ante una denegación, cierra la sesión y muestra el motivo en el login.
- Los roles deciden qué datos se ven:

| Rol | Ve | Configuración y panel |
| --- | --- | --- |
| Administrador | Toda la empresa | Sí |
| Academia | Toda la empresa | Sí |
| Área | Los colaboradores de las áreas que lidera | No |
| Líder de equipo | Los integrantes de los equipos que lidera | No |

- Las áreas y los equipos salen de la importación de nómina; en el panel solo se asignan sus líderes. Una asignación no se borra: quitar un líder le pone fecha de baja (`ff_baja`) y volver a asignarlo la reactiva.
- La validación en Flutter mejora la experiencia de acceso. La protección de los datos corresponde a **Row Level Security (RLS)** en Supabase, con el mismo criterio de alcance que la app.

El entorno remoto requiere Google habilitado en Supabase, el email autorizado y las políticas RLS configuradas. En Flutter Web, el callback usa el origen actual (`Uri.base.origin`); para este runner, permitir `http://localhost:3000/**` en las URLs de redirección de Supabase.

La aplicación consume un esquema existente con `empleados`, `empleado_historial`, `cursos`, `horas_capacitacion`, `finalizaciones_cursos`, `importaciones`, `usuarios_autorizados`, `areas`, `equipos`, `area_lideres`, `equipo_lideres` y `plan_formacion`. Los scripts SQL (áreas y equipos con su RLS, plan de formación y baja lógica de líderes) se corren a mano en el SQL Editor y no se versionan en este repositorio; **tienen que estar aplicados antes de desplegar la app**. **Nunca utilizar `service_role` en el frontend ni publicar credenciales privadas.**

## Reglas de negocio principales

El objetivo de cada colaborador es mensual y depende de su seniority, repartido entre **Habilidades de negocio**, **Habilidades blandas**, **Libres / Exploración** y **Dictado de capacitaciones**. El plan por defecto suma **8 horas por mes**; se edita en Configuración y queda versionado por mes, así un cambio no reescribe los meses anteriores.

- **Negocio y Blandas:** cada curso finalizado en el LMS acredita la carga horaria del catálogo. Las horas cargadas en el CRM para esos cursos quedan como declaradas.
- **Libres y Dictado:** se acreditan con las horas del CRM según su clasificación.
- Cada categoría suma como máximo su objetivo, y una categoría sin objetivo no suma al cumplimiento. No se compensa entre categorías.

```text
Cumplimiento = horas válidas aplicables / horas objetivo del período × 100
```

Un equipo está **en objetivo** con 100 % o más y todos sus integrantes cumpliendo; **en riesgo** con 70 % o más o algún integrante cumpliendo; y **crítico** en otro caso.

### Seguimiento mensual

- La elegibilidad considera la fecha de ingreso y el estado histórico activo al cierre del mes, sin reinterpretar el pasado con el estado actual.
- Para períodos anteriores al primer historial, se usa ese primer estado conocido, siempre que la persona ya haya ingresado.
- Un equipo con colaboradores elegibles aparece aunque tenga **0 horas**.
- Sin ningún registro CRM o LMS del mes, las pantallas muestran **“Sin datos”**, sin interpretar la ausencia de información como incumplimiento.

### Seguimiento anual

Se acumulan únicamente los meses con registros CRM o LMS. Las horas y los objetivos anuales suman sus resultados mensuales, respetando altas, bajas y cambios de equipo mes a mes.

**Colaboradores** cuenta legajos únicos elegibles en al menos uno de esos meses. El cumplimiento divide las horas válidas acumuladas por el objetivo acumulado; no se calcula como cantidad de personas × horas fijas. Dashboard, Equipos, Áreas, el perfil del colaborador y el asistente usan el mismo cálculo.

## Importación de datos

Las cargas se realizan desde **Configuración**. Cada importación pide confirmación después de elegir el archivo y avisa el resultado. Las importaciones distinguen maestros vigentes de movimientos históricos:

| Fuente | Formatos | Comportamiento |
| --- | --- | --- |
| Nómina | `.xlsx`, `.csv` | Foto vigente por `legajo`: presentes activos, ausentes inactivos y reapariciones activas nuevamente. Sin eliminación física; registra antes las áreas y equipos nuevos. En Supabase, el trigger existente registra cambios en `empleado_historial`. |
| Cursos | `.xlsx`, `.csv` | Foto vigente por ID: activa presentes, inactiva ausentes y permite reactivación, sin eliminación física. |
| Horas CRM | `.xlsx`, `.csv` | UPSERT por `transaccion_id`: inserta claves nuevas y actualiza existentes. La ausencia en otra carga no elimina movimientos. |
| Finalizaciones LMS | `.xlsx` | UPSERT por `legajo` + `curso_id`: inserta combinaciones nuevas y actualiza existentes. La ausencia en otra carga no implica `finalizo=false`. |

Los CSV aceptan fin de línea CRLF, LF o CR y BOM UTF-8. CRM resuelve la columna `Curso` contra el nombre del catálogo, sin usar `Choras - XX` como identificador. Las fechas inválidas se rechazan, sin reemplazarlas por la fecha actual.

La auditoría registra el archivo, tipo, fecha, estado, procesados, insertados, actualizados y errores (en Supabase, en `public.importaciones`).

### Dataset base

Cargar en este orden:

1. **Nómina** de empleados.
2. **Catálogo de cursos**.
3. **Horas CRM**.
4. **Finalizaciones LMS**.

Los archivos de datos no están incluidos en este repositorio y deben obtenerse por separado.

## Referencias QA

Valores de referencia de la validación manual del **dataset base 01–04**, para contrastar un entorno con esa misma base. No son datos hardcodeados de la aplicación.

| Fuente | Registros de referencia |
| --- | ---: |
| Empleados activos | 96 |
| Cursos activos | 25 |
| Horas CRM | 601 |
| Finalizaciones LMS | 608 |

**Equipos · mensual 2026**

| Período | Colaboradores | Horas válidas | Objetivo | Cumplimiento |
| --- | ---: | ---: | ---: | ---: |
| Julio 2026 | 80 | 640 h | 640 h | 100% |
| Agosto 2026 | 90 | 462 h | 720 h | 64,2% |
| Septiembre 2026 | 96 | 547 h | 768 h | 71,2% |

**Equipos · anual 2026**, acumulando esos tres meses:

| Colaboradores únicos | Horas válidas | Objetivo acumulado | Cumplimiento |
| ---: | ---: | ---: | ---: |
| 96 | 1649 h | 2128 h | 77,5% |

## Arquitectura y estructura

El código está organizado **por features**, cada una con tres capas, y todos los identificadores están en inglés (los textos de la interfaz, las rutas visibles y los nombres de Supabase siguen en español).

```text
presentation (pantallas, widgets, providers y Notifiers)
     ↓
domain       (entidades, services con las reglas y contratos de repositorio)
     ↑
data         (repositorios en memoria con seed y repositorios Supabase)
```

- Las **entidades** solo tienen datos (`copyWith`, `toJson`/`fromJson`); los cálculos viven en services del dominio.
- Cada pantalla mira providers; las mutaciones las hace un `Notifier` dueño de su estado, y la UI avisa con SnackBars y pide confirmación en las acciones sensibles.
- Los widgets no consultan Supabase: cada feature tiene su provider de repositorio, que elige la implementación en memoria o la de Supabase según `USE_SUPABASE`. Los nombres físicos de tablas y columnas están solo en `data/`.

```text
lib/
├── core/                 # Router, navegación, tema, período, filtros, widgets compartidos
└── features/
    ├── admin/            # Usuarios autorizados
    ├── areas/  teams/    # Seguimiento por área y por equipo
    ├── assistant/        # Chat con el asistente de IA
    ├── auth/             # Sesión, autorización y roles
    ├── certifications/   # Finalizaciones LMS
    ├── compliance/       # Regla de acreditación y cumplimiento por período
    ├── courses/          # Catálogo y categorías
    ├── dashboard/        # Inicio
    ├── employees/        # Nómina, historial y perfil
    ├── imports/          # Lectura de archivos e importaciones
    ├── org_structure/    # Áreas, equipos, líderes y alcance del usuario
    ├── pending_reminders/# Mails de cursos pendientes desde Certificaciones LMS
    ├── projection/       # Proyección a fin de año
    ├── reports/          # Reportes PDF
    ├── settings/         # Pantalla de configuración
    ├── time_entries/     # Horas CRM
    └── training_plan/    # Plan de formación versionado
config/                   # Ejemplo de configuración por dart-define
supabase/                 # Edge Function y SQL de las notificaciones por mail
tool/run.dart             # Runner local / Supabase
test/                     # Pruebas, con la misma estructura que lib/
web/                      # Entrada y recursos de Flutter Web
```

## Asistente de IA

Las pantallas internas incluyen un chat flotante conectado a la Edge Function existente `asistente-ia`. Utiliza la sesión de Supabase; la clave de Gemini permanece en el servidor. En modo local se puede ver la interfaz, pero no consulta a la IA.

Con `IA_CONTEXTO_REAL` (dart-define, activo por defecto) la consulta envía los indicadores reales del período que interpreta la pregunta, con el alcance del usuario: un líder solo envía los datos de lo que lidera. Nunca viajan el legajo, el mail ni la URL.

## Notificación de cursos pendientes por mail

En **Certificaciones LMS**, el botón **Notificar pendientes por mail** toma lo que muestran los filtros (Tipo, Área, Equipo, Curso, Persona y Estado) y le manda a cada colaborador un mail con los cursos que tiene **pendientes** dentro de esa selección. Antes de enviar, un diálogo muestra a quién se le escribe, qué cursos recibe cada persona y quiénes se omiten por estar fuera de la nómina, inactivos o sin mail.

- Lo pueden usar todos los roles, cada uno dentro de su alcance.
- Flutter solo envía legajos e IDs de curso a la Edge Function `notificar-pendientes` ([supabase/functions/notificar-pendientes/index.ts](supabase/functions/notificar-pendientes/index.ts)). La función lee mails y estados con el JWT de quien llama, así RLS aplica el mismo alcance que la app, y envía los mails con **Resend**.
- Cada envío queda en `public.notificaciones_pendientes` ([supabase/sql/notificaciones_pendientes.sql](supabase/sql/notificaciones_pendientes.sql)). La tabla la escribe solo la función y la leen Administrador y Academia.
- En modo local el diálogo funciona igual, pero no se envía ningún mail.
- Requiere los secrets `RESEND_API_KEY` y `RESEND_FROM` (y `LMS_URL`, que es opcional) en Supabase. La configuración completa está en [docs/configuracion-notificaciones-mail.md](docs/configuracion-notificaciones-mail.md).

## Mejora futura

Historizar atributos de los cursos, como **tipo/categoría** y **carga horaria**, permitiría preservar la interpretación de métricas pasadas cuando cambien esos valores. Actualmente se consulta el catálogo disponible.

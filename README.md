# Dashboard de Formación · Finnegans

**Proyecto final de ORT** · Portal interno para el seguimiento de la formación de colaboradores.

El sistema reúne la nómina de empleados, el catálogo de cursos, las horas declaradas en CRM y las finalizaciones del LMS. Permite consultar el avance de la capacitación por persona, equipo y área, con indicadores de horas, objetivos y cumplimiento.

## Contenido

- [Tecnologías y módulos](#tecnologías-y-módulos)
- [Cómo ejecutar](#cómo-ejecutar)
- [Acceso y seguridad](#acceso-y-seguridad)
- [Reglas de negocio principales](#reglas-de-negocio-principales)
- [Importación de datos](#importación-de-datos)
- [Referencias QA](#referencias-qa)
- [Arquitectura y estructura](#arquitectura-y-estructura)
- [Mejora futura](#mejora-futura)

## Tecnologías y módulos

| Tecnología | Uso |
| --- | --- |
| Flutter / Flutter Web y Dart | Interfaz y ejecución web en Chrome. |
| Riverpod | Estado, providers y selección de dependencias. |
| go_router | Navegación y protección de rutas. |
| Supabase / PostgreSQL | Persistencia remota y seguridad mediante RLS. |
| Google OAuth / Supabase Auth | Inicio de sesión y mantenimiento de la sesión. |
| SharedPreferences | Persistencia local y preferencias. |
| excel, csv y file_picker | Selección y lectura de archivos. |

| Módulo | Función |
| --- | --- |
| Inicio / Dashboard | Resumen de formación, categorías y avance por áreas. |
| Áreas | Consulta de áreas y detalle de sus colaboradores y equipos. |
| Equipos | Seguimiento mensual y anual, filtros y detalle por equipo. |
| Empleados | Nómina, búsqueda y detalle individual de formación. |
| Cursos | Consulta del catálogo y filtros por tipo. |
| Carga de horas CRM | Consulta de horas declaradas por colaborador y curso. |
| Certificaciones LMS | Consulta de finalizaciones por legajo o curso. |
| Métricas | Alcance, proyección y formación impartida; ruta `/metricas`. |
| Configuración | Importación de las cuatro fuentes y opción de sincronizar cursos desde Moodle. |

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

### Desarrollo con mocks/local

```console
dart run tool/run.dart local
```

Ejecuta Flutter con `USE_SUPABASE=false`. Utiliza los repositories locales y mocks existentes, con persistencia en SharedPreferences, sin conectar a Supabase. La pantalla inicial conserva su botón de acceso: en este modo lleva al Dashboard sin realizar Google OAuth.

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

## Acceso y seguridad

```text
Google OAuth → Supabase Auth → usuarios_autorizados → Dashboard
```

- Flutter consulta `public.usuarios_autorizados` por el email autenticado y exige `activo=true` antes de mostrar las rutas privadas. Ante una denegación, cierra la sesión y muestra el mensaje correspondiente.
- Las sesiones válidas se restauran y vuelven a validar. Los cambios de autenticación actualizan la navegación; el logout utiliza Supabase Auth.
- `rol` se conserva en el estado de Auth para uso futuro, sin permisos diferenciados por rol.
- La validación en Flutter mejora la experiencia de acceso. La protección de los datos corresponde a **Row Level Security (RLS)** en Supabase.

El entorno remoto requiere Google habilitado en Supabase, el email autorizado y las políticas RLS configuradas. En Flutter Web, el callback usa el origen actual (`Uri.base.origin`); para este runner, permitir `http://localhost:3000/**` en las URLs de redirección de Supabase.

La aplicación consume un esquema existente con `empleados`, `empleado_historial`, `cursos`, `horas_capacitacion`, `finalizaciones_cursos`, `importaciones` y `usuarios_autorizados`. El repositorio no incluye migraciones SQL para crearlo. **Nunca utilizar `service_role` en el frontend ni publicar credenciales privadas.**

## Reglas de negocio principales

El objetivo general es de **8 horas por colaborador por mes**, distribuidas según seniority entre **Habilidades de negocio**, **Habilidades blandas**, **Libres / Exploración** y **Dictado de capacitaciones**.

Las horas válidas provienen de CRM y requieren la finalización del curso en LMS. Se limitan por la carga máxima del curso y por el objetivo de cada categoría; una categoría sin objetivo no suma al cumplimiento.

```text
Cumplimiento = horas válidas aplicables / horas objetivo del período × 100
```

### Seguimiento mensual de Equipos

- La elegibilidad considera la fecha de ingreso y el estado histórico activo al cierre del mes, sin reinterpretar el pasado únicamente con el estado actual.
- Para períodos anteriores al primer historial, se usa ese primer estado conocido, siempre que la persona ya haya ingresado.
- Un equipo con colaboradores elegibles aparece aunque tenga **0 horas**. No se excluyen personas por falta de actividad.
- Sin ningún registro CRM o LMS del mes, Equipos muestra **“Sin datos”**, sin interpretar la ausencia de información como incumplimiento.

### Seguimiento anual de Equipos

Se acumulan únicamente los meses con registros CRM o LMS. Las horas y los objetivos anuales suman sus resultados mensuales, respetando altas, bajas y cambios de equipo mes a mes.

**Colaboradores** cuenta legajos únicos elegibles en al menos uno de esos meses. Por equipo, se cuentan quienes tuvieron objetivo en ese equipo durante el año. El cumplimiento divide las horas válidas acumuladas por el objetivo acumulado; no se calcula como cantidad de personas × 96 horas.

Estas reglas históricas y anuales describen **Equipos**; los demás módulos conservan sus propios providers de indicadores.

## Importación de datos

Las cargas se realizan desde **Configuración**. Las importaciones por archivo distinguen maestros vigentes de movimientos históricos:

| Fuente | Formatos | Comportamiento |
| --- | --- | --- |
| Nómina | `.xlsx`, `.csv` | Snapshot autoritativo por `legajo`: presentes activos, ausentes de una carga válida inactivos y reapariciones activas nuevamente. Sin eliminación física; en Supabase, el trigger existente registra cambios en `empleado_historial`. |
| Cursos | `.xlsx`, `.csv` | Snapshot por ID: activa presentes, inactiva ausentes y permite reactivación, sin eliminación física. |
| Horas CRM | `.xlsx`, `.csv` | UPSERT por `transaccion_id` en PostgreSQL (`id` en Dart): inserta claves nuevas y actualiza existentes. La ausencia en otra carga no elimina movimientos. |
| Finalizaciones LMS | `.xlsx` | UPSERT por `legajo` + `curso_id`: inserta combinaciones nuevas y actualiza existentes. La ausencia en otra carga no implica `finalizo=false`. |

CRM resuelve la columna `Curso` contra el nombre normalizado del catálogo (`NombreCurso`), sin usar `Choras - XX` como identificador. Las fechas inválidas se rechazan, sin reemplazarlas por la fecha actual.

La auditoría remota registra en `public.importaciones` el archivo, tipo, fecha, estado, procesados, insertados, actualizados y errores. El modo local conserva los repositories existentes, sin auditoría remota ni reconstrucción desde `empleado_historial`.

La sincronización directa de cursos desde Moodle utiliza UPSERT; la inactivación de ausentes descrita arriba corresponde a la importación por archivo.

### Dataset base

Cargar en este orden:

1. **Nómina** de empleados.
2. **Catálogo de cursos**.
3. **Horas CRM**.
4. **Finalizaciones LMS**.

Los archivos QA adicionales de desarrollo no forman parte del dataset base. Los archivos de datos no están incluidos en este repositorio y deben obtenerse por separado.

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

```text
UI → Providers → Services / Repositories → Supabase
                                        → Persistencia local / mocks
```

La UI consume providers; los servicios concentran cálculos y coordinación de importaciones, y los repositories implementan el acceso a datos. Los widgets no consultan Supabase directamente. La autorización se centraliza en `AuthController`.

```text
lib/
├── core/                       # Router y configuración de Supabase
├── domain/
│   ├── modelos/                 # Entidades y resultados de formación
│   ├── servicios/               # Cumplimiento, equipos e importaciones
│   ├── repositorios/            # Contratos de acceso a datos
│   └── importacion/             # Conversión y validación de valores
├── data/                       # Repositories locales y cliente Moodle
│   └── supabase/               # Repositories remotos y mappings
└── presentation/               # Pantallas, providers, widgets y utilidades
config/                         # Ejemplo de configuración por dart-define
tool/run.dart                   # Runner local / Supabase
test/                           # Pruebas existentes
web/                            # Entrada y recursos de Flutter Web
```

La selección del backend y los mappings físicos están en `core_providers.dart`; `USE_SUPABASE` determina qué implementaciones se utilizan.

## Mejora futura

Historizar atributos de los cursos, como **tipo/categoría** y **carga horaria**, permitiría preservar la interpretación de métricas pasadas cuando cambien esos valores. Actualmente se consulta el catálogo disponible.

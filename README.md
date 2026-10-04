# Dashboard de Formación

La importación conserva la selección de archivos, parsing y validaciones existentes.
Las nuevas cargas realizan UPSERT; los repositories locales y mocks se mantienen
para validar gradualmente el reemplazo. Una primera carga local guarda únicamente
los registros importados; las siguientes conservan los registros anteriores.
CRM resuelve `Curso` por nombre normalizado del catálogo LMS, conserva la
trazabilidad original y rechaza fechas inválidas.

## Preparación de Supabase

Copiar `config/supabase.example.json` a `config/supabase.local.json` (ignorado por Git).
Ejecutar `flutter run --dart-define-from-file=config/supabase.local.json`.
`USE_SUPABASE=false` mantiene los repositories locales. Para activarlo, configurar
URL/clave pública y suministrar `SupabaseMappings` mediante un override de
`supabaseMappingsProvider` en `ProviderScope`; no hay nombres físicos ni claves
por defecto. La inicialización conserva la sesión de Supabase Auth.

Pendientes del diseño SQL: tablas/columnas, restricciones de UPSERT, PK/FK,
índices, RLS, histórico de finalizaciones y bajas de maestros. El contrato y hooks
de auditoría están preparados; `importacionesRepositoryProvider` queda sin
persistencia hasta definir su implementación. Insertados/actualizados permanecen
sin valor hasta disponer de conteos confiables. No se generó SQL.

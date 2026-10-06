# Dashboard de Formación

La importación conserva la selección de archivos, parsing y validaciones existentes.
Las nuevas cargas realizan UPSERT; los repositories locales y mocks se mantienen
para validar gradualmente el reemplazo. Una primera carga local guarda únicamente
los registros importados; las siguientes conservan los registros anteriores.
CRM resuelve `Curso` por nombre normalizado del catálogo LMS, conserva la
trazabilidad original y rechaza fechas inválidas.

## Ejecución

Flutter debe estar disponible en `PATH`. Ambos comandos abren Chrome en el puerto 3000.

### Desarrollo con mocks/local

```console
dart run tool/run.dart local
```

### Desarrollo con Supabase real

```console
dart run tool/run.dart supabase
```

Requiere `config/supabase.local.json`, con `USE_SUPABASE=true` y la configuración
existente de Supabase. Este archivo está ignorado por Git y no debe subirse al repositorio.

## Preparación de Supabase

Copiar `config/supabase.example.json` a `config/supabase.local.json` (ignorado por Git).
`USE_SUPABASE=false` mantiene los repositories locales. Para activarlo, configurar
URL/clave pública y suministrar `SupabaseMappings` mediante un override de
`supabaseMappingsProvider` en `ProviderScope`; no hay nombres físicos ni claves
por defecto. La inicialización conserva la sesión de Supabase Auth.

Pendientes del diseño SQL: tablas/columnas, restricciones de UPSERT, PK/FK,
índices, RLS, histórico de finalizaciones y bajas de maestros. El contrato y hooks
de auditoría están preparados; `importacionesRepositoryProvider` queda sin
persistencia hasta definir su implementación. Insertados/actualizados permanecen
sin valor hasta disponer de conteos confiables. No se generó SQL.

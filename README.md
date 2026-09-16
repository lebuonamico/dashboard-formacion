# Dashboard de Formación

La pantalla de configuración guarda localmente el trimestre, las horas base y los
datos importados. La información queda disponible al volver a abrir la app.

## Importación Excel / CSV

El botón **Subir Archivo** acepta un archivo `.xlsx` o `.csv`. En Excel recorre
todas las hojas y detecta el tipo de registro a partir de sus encabezados. Si un
tipo de registro reemplaza la colección local correspondiente, evitando mezclar la
nómina importada con los datos mock.

Encabezados esperados:

- Empleados: `legajo,nombre,apellido,seniority,area,mail,equipo,gerente`
- Cursos: `id,nombre,tipo,areaCurso,instructorLegajo,cargaHorariaHs`
- Cursadas: `id,cursoId,empleadoLegajo,fecha`

Los valores de `seniority` y `tipo` deben coincidir con los nombres definidos en
los enums de la aplicación. El botón **Restablecer Datos Mock** elimina la copia
local y vuelve a mostrar la semilla de desarrollo.

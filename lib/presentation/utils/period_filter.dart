bool coincidePeriodo(DateTime fecha, {int? anio, int? mes}) =>
    (anio == null || fecha.year == anio) && (mes == null || fecha.month == mes);

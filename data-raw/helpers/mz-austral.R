## Modificar la región de ejecución y la macrozona de aquellas personas que su institución
## principal contenga la palabra 'MAGALLANES' y su región de ejecución no fuera la Región de
## Magallanes, ni fuera de macrozona 'MULTIREGIONAL'
proyectosanid_raw[
  i = institucion_principal %like% "MAGALLANES" &
    region_ejecucion != "12. MAGALLANES Y ANTARTICA CHILENA" &
    macrozona != "MULTIREGIONAL",
  j = `:=`(region_ejecucion = "12. MAGALLANES Y ANTARTICA CHILENA",
           macrozona = "AUSTRAL")
]

## Modificar la región de ejecución y la macrozona de aquellas personas que su institución
## principal contenga la palabra 'AYSEN' y su macrozona no sea 'MULTIREGIONAL'
proyectosanid_raw[
  i = institucion_principal %like% "AYSEN" &
    macrozona != "MULTIREGIONAL",
  j = `:=`(region_ejecucion = "11. AYSEN",
           macrozona = "AUSTRAL")
]

## Modificar la región de ejecución, la institución principal y la macrozona de aquellas
## personas que en entrevistas indicaron que se habían cambiado de institución
proyectosanid_raw[
  i = codigo_proyecto %in% c(3200226, 3180754),
  j = `:=`(institucion_principal = "UNIVERSIDAD DE AYSEN",
           region_ejecucion = "11. AYSEN",
           macrozona = "AUSTRAL")
]

## Eliminar registros de proyectos a los cuales los responsables renunciaron al financiamiento
proyectosanid_raw = proyectosanid_raw[!codigo_proyecto %in% c("3170733", "3180280", "PAI77180074")]

## Eliminar registros duplicado
proyectosanid_raw = proyectosanid_raw[n != 21894]


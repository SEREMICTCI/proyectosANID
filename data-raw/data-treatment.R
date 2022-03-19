# Cargamos librerias --------------------------------------------------------------------------

  library(data.table)
  library(stringi)
  library(tibble)

# Descargar los datos -------------------------------------------------------------------------


  ## Descargamos el archivo si no existe
  if (!file.exists("data-raw/rawdata.csv")) {
    ## Obtenemos URL del repositorio donde están alojados los datos
    url = "https://raw.githubusercontent.com/ANID-GITHUB/Historico-de-Proyectos-Adjudicados/master/BDH_Proyectos.csv"

    ## Descargamos los datos
    download.file(url, "data-raw/rawdata.csv"); rm(url)
  }

  ## Cargamos los datos
  proyectosanid_raw = data.table::fread("data-raw/rawdata.csv", dec = ",", sep = ";")

  ## Cambiamos nombres de columnas
  names(proyectosanid_raw) = c("codigo_proyecto", "n", "subdireccion", "programa",
                           "instrumento", "nombre_concurso", "ano_curso", "ano_fallo",
                           "nombre_proyecto", "area_ocde", "disciplina", "grupo_evaluacion",
                           "duracion_meses", "tipo_beneficiario", "nombre_responsable",
                           "sexo", "institucion_principal", "macrozona",
                           "region_ejecucion", "monto_adjudicado_miles", "nota_monto")


# Estandarización de nombre de las instituciones ----------------------------------------------


  ## Cargamos nuestra hoja de consulta
  th_ip = data.table::fread("data-raw/helpers/th-institucion_principal.csv")

  ## Eliminamos los carácteres especiales (non-ASCII)
  proyectosanid_raw[, institucion_principal := iconv(institucion_principal, to = "ASCII", sub = "")]

  ## Comprobamos que las instituciones de búsqueda del tesauro son las mismas que las de la base de datos
  x <- sort(th_ip$institucion_principal)
  y <- sort(unique(proyectosanid_raw$institucion_principal))

  cbind(y[y != x], x[y != x])  ## Si hay incongruencias
  y[which(y != x)]             ## aparecerán aquí

  identical(x, y); rm(x, y)    ## Si los elementos no son idénticos se devolverá FALSE

  ## Asignamos las instituciones estandarizadas
  proyectosanid_raw[th_ip, institucion_principal := i.cambio, on = "institucion_principal"]; rm(th_ip)

  ## Eliminamos aquellas que dicen SIN INFORMACION
  proyectosanid_raw[institucion_principal %like% "SIN INFO", institucion_principal := NA]


# Estandarización general ---------------------------------------------------------------------

  ## Transformación de variables a su formato correspondiente

  str(proyectosanid_raw)

  ## Duración meses a numérico
  proyectosanid_raw[grepl("[A-Z]", duracion_meses), duracion_meses := NA]
  proyectosanid_raw[, duracion_meses := as.integer(x = gsub(",", ".", duracion_meses, fixed = TRUE))]

  ## Todas variables no-numéricas a mayúscula
  char_vars = names(proyectosanid_raw[, .SD, .SDcols = !is.numeric])
  proyectosanid_raw[, (char_vars) := lapply(.SD, toupper), .SDcols = char_vars]


# Transformación de carácteres no-ASCII -------------------------------------------------------

  ## Los caracteres con codificación latina (i.e., {ñ, á, é, í, ó, ú }) se
  ## modificarán a su versión compatible ASCII (e.g., ñ -> n; é -> e; etc).
  ## Cualquier otro carácter o elemento será eliminado.

  ## Nombre concurso
  proyectosanid_raw[, nombre_concurso := stringi::stri_trans_general(nombre_concurso, id = "latin-ascii")]
  proyectosanid_raw[, nombre_concurso := iconv(nombre_concurso, to = "ASCII", sub = "")]

  ## Nombre proyecto
  proyectosanid_raw[, nombre_proyecto := stringi::stri_trans_general(nombre_proyecto, id = "latin-ascii")]
  proyectosanid_raw[, nombre_proyecto := iconv(nombre_proyecto, to = "ASCII", sub = "")]
  proyectosanid_raw[nombre_proyecto %like% "SIN INFO", nombre_proyecto := NA]

  ## Nombre de responsable
  proyectosanid_raw[, nombre_responsable := stringi::stri_trans_general(nombre_responsable, id = "latin-ascii")]
  proyectosanid_raw[, nombre_responsable := iconv(nombre_responsable, to = "ASCII", sub = "")]
  proyectosanid_raw[, nombre_responsable := gsub(".", "", nombre_responsable, fixed = TRUE)]
  proyectosanid_raw[nombre_responsable %like% "SIN INFO", nombre_responsable := NA]

  ## Region_ejecucion
  proyectosanid_raw[, region_ejecucion := stringi::stri_trans_general(region_ejecucion, id = "latin-ascii")]
  proyectosanid_raw[region_ejecucion %like% "SIN INFO", region_ejecucion := NA]

  ## Instrumento
  proyectosanid_raw[, instrumento := stringi::stri_trans_general(instrumento, id = "latin-ascii")]
  proyectosanid_raw[, instrumento := iconv(instrumento, to = "ASCII", sub = "")]

  ## Area OCDE
  proyectosanid_raw[area_ocde %like% "SIN INFO", area_ocde := NA]

  ## Código de proyecto
  proyectosanid_raw[codigo_proyecto %like% "SIN INFO", codigo_proyecto := NA]

  ## Nota monto
  proyectosanid_raw[nota_monto %like% "SIN INFO", nota_monto := NA]

  ## Código proyecto
  proyectosanid_raw[, codigo_proyecto := stringi::stri_trans_general(codigo_proyecto, id = "latin-ascii")]
  proyectosanid_raw[, codigo_proyecto := iconv(codigo_proyecto, to = "ASCII", sub = "")]

  ## Disciplina
  proyectosanid_raw[, disciplina := stringi::stri_trans_general(disciplina, id = "latin-ascii")]
  proyectosanid_raw[, disciplina := iconv(disciplina, to = "ASCII", sub = "")]

  ## Eliminamos todos los espacios en blanco extras
  proyectosanid_raw[, (char_vars) := lapply(.SD, trimws), .SDcols = char_vars]; rm(char_vars)

# Corrección de entradas de datos -------------------------------------------------------------

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


# Creación de variables -----------------------------------------------------------------------


  ## Año de finalización
  proyectosanid_raw[, ano_finalizacion := (ano_fallo + (duracion_meses / 12))]

  ## Ubicación de la institución
  proyectosanid_raw[, ubicacion_institucion := region_ejecucion]

  ## Estado: Pospuesto hasta obtener una solución más transversal
  ## y permanente que vaya más allá de la macrozona austral.
  ## Posiblemente una hoja de consulta pueda ser una alternativa.


# Estandarización de nombres ------------------------------------------------------------------


  ## Mediante computación paralela generamos una comparación de cada uno de los
  ## elementos con cada elemento en busca de coincidencias aproximada (fuzzy matching)
  # search. = unique(proyectosanid_raw$nombre_responsable)

  ## Fijamos clusteres para computación paralela
  # cl = parallel::makeCluster(20)

  ## Buscamos los nombres más próximos entre si para mediante fuzzy matching
  ## Advertencia: Computación larga (i.e., 3 a 5 minutos)
  # m_names = parallel::parSapply(cl, search., agrep, search., value = TRUE, max.distance = 0)
  # m_names = Filter(x = m_names, f = function(i) length(i) > 1)

  ## Para cada conjunto de nombres similares, se asigna el nombre con
  ## el mayor número de carácteres al resto de los nombres similares
  # for (x in m_names) {
  #   proyectosanid_raw[
  #     i = nombre_responsable %chin% x,
  #     j = nombre_responsable := x[which.max(nchar(x))]
  #   ]
  # }

  # rm(search., cl, m_names)


# Estandarización nombres ---------------------------------------------------------------------


  ## MZ Austral
  th_nr <- fread("data-raw/helpers/th-mz_austral-nombres_responsables.csv")
  proyectosanid_raw[th_nr, nombre_responsable := i.cambio, on = "nombre_responsable"]; rm(th_nr)


# Exportación final ---------------------------------------------------------------------------


  ## Lo traspasamos a formato tibble - más amigable para explorar los datos
  proyectosanid = tibble::as_tibble(proyectosanid_raw); rm(proyectosanid_raw)

  ## Guardamos una versión en CSV para compartir más fácilmente
  data.table::fwrite(proyectosanid, file = "data-raw/clean-data/proyectosanid.csv")

  ## Instalamos los datos en el paquete para que sean de fácil acceso
  usethis::use_data(proyectosanid, overwrite = TRUE)

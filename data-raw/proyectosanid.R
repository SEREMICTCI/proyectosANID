
# Código para preparar los datos `proyectosanid` van aquí -------------------------------------

library(data.table)
library(stringi)
library(parallel)
library(tibble)

# Descargar los datos -------------------------------------------------------------------------

## Obtenemos URL
url <- "https://raw.githubusercontent.com/ANID-GITHUB/Historico-de-Proyectos-Adjudicados/master/BDH_Proyectos.csv"
## Descargamos los datos
proyectosanid_raw <- data.table::fread(url, encoding = "UTF-8")
## Cambiamos nombres de columnas
names(proyectosanid_raw) <- c("codigo_proyecto", "n", "subdireccion", "programa",
                         "instrumento", "nombre_concurso", "ano_curso", "ano_fallo",
                         "nombre_proyecto", "area_ocde", "disciplina", "grupo_evaluacion",
                         "duracion_meses", "tipo_beneficiario", "nombre_responsable",
                         "sexo", "institucion_principal", "macrozona",
                         "region_ejecucion", "monto_adjudicado_miles", "sinfo_nosolicita")

# Procesamos los datos ------------------------------------------------------------------------

## Transformamos codificación no-ASSCI a su interpretación latina
proyectosanid_raw <- proyectosanid_raw[, lapply(.SD, stringi::stri_trans_general, id = "latin-ascii")]
## Transformación de formato de la duración meses a numérico
proyectosanid_raw[, duracion_meses := as.numeric(gsub(",", ".", duracion_meses))] |>
  suppressWarnings()
## Todos los carácteres de nombre del proyecto, responsable e institución  principal las
## transformamos a mayúsculas
proyectosanid_raw[j = `:=`(
  nombre_proyecto = toupper(nombre_proyecto),
  nombre_responsable = toupper(nombre_responsable),
  nombre_concurso = toupper(nombre_concurso),
  institucion_principal = toupper(institucion_principal)
)]
## Cambiamos carácteres especiales no leídos de la codificación original
proyectosanid_raw[j = `:=`(
  nombre_responsable = gsub("Ã‘", "Ñ", nombre_responsable),
  nombre_concurso = gsub("â€“", "", nombre_concurso))
][j = nombre_concurso := gsub("Ã‘", "Ñ", nombre_concurso)
][j = nombre_responsable := gsub("Ã±", "Ñ", nombre_responsable)]
## Cambiamos los dobles espacios por un espacio de los nombres de los responsables
proyectosanid_raw[i = nombre_responsable %like% "  ",
             j = nombre_responsable := gsub("  ", " ", nombre_responsable, useBytes = TRUE)]
## Eliminamos los puntos de los nombres de los responsables
proyectosanid_raw[i = nombre_responsable %like% "\\.",
             j = nombre_responsable := gsub("\\.", "", nombre_responsable, useBytes = TRUE)]
## Modificar la región de ejecución y la macrozona de aquellas personas que su institución
## principal contenga la palabra 'MAGALLANES' y su región de ejecución no fuera la Región de
## Magallanes, ni fuera de macrozona 'MULTIREGIONAL'
proyectosanid_raw[i = institucion_principal %like% "MAGALLANES" &
               region_ejecucion != "12. MAGALLANES Y ANTARTICA CHILENA" &
               macrozona != "MULTIREGIONAL",
             j = `:=`(region_ejecucion = "12. MAGALLANES Y ANTARTICA CHILENA",
                      macrozona = "AUSTRAL")]
## Modificar la región de ejecución y la macrozona de aquellas personas que su institución
## principal contenga la palabra 'AYSEN' y su macrozona no sea 'MULTIREGIONAL'
proyectosanid_raw[i = institucion_principal %like% "AYSEN" &
               macrozona != "MULTIREGIONAL",
             j = `:=`(region_ejecucion = "11. AYSEN",
                      macrozona = "AUSTRAL")]
## Modificar la región de ejecución, la institución principal y la macrozona de aquellas
## personas que en entrevistas indicaron que se habían cambiado de institución
proyectosanid_raw[i = codigo_proyecto %in% c(3200226, 3180754),
             j = `:=`(institucion_principal = "UNIVERSIDAD DE AYSEN",
                      region_ejecucion = "11. AYSEN",
                      macrozona = "AUSTRAL")]
## Eliminar registros de proyectos a los cuales los responsables renunciaron al financiamiento
proyectosanid_raw <- proyectosanid_raw[!codigo_proyecto %in% c("3170733", "3180280", "PAI77180074")]
## Eliminar registros duplicado
proyectosanid_raw <- proyectosanid_raw[n != 21894]
## Modificar código de proyecto 'repetido'
proyectosanid_raw <- proyectosanid_raw[n == 12840, codigo_proyecto := "SIN INFORMACION2"]
## Mediante computación paralela generamos una comparación de cada uno de los elementos (i)
## con cada elemento (i') en busca de coincidencias aproximada (fuzzy matching)
search. <- unique(proyectosanid_raw$nombre_responsable)
## Fijamos clusteres para computación paralela
cl <- parallel::makeCluster(20)
## Computación larga ~ 2 a 3 minutos
m_names <- parallel::parSapply(cl, search., agrep, search., value = TRUE, max.distance = 0) |> # 1 a 3 minutos usando computación paralela
  Filter(f = function(i) length(i) > 1)

for (i in m_names) {
  proyectosanid_raw[nombre_responsable %chin% i, nombre_responsable := i[which.max(nchar(i))]]
}
## Normalizar CENTRO DE ESTUDIOS DEL CUATERNARIO DE FUEGO-PATAGONIA Y ANTARTICA-CEQUA
proyectosanid_raw[i = institucion_principal %like% "CUATERNARIO",
             j = institucion_principal := "CEQUA"]
## Normalizar institución CIEP
proyectosanid_raw[i = institucion_principal %like% "ECOSISTEMAS" &
               institucion_principal %like% "PATAG" |
               institucion_principal %like% "CIEP",
             j = `:=`(institucion_principal = "CIEP",
                      macrozona = "AUSTRAL",
                      region_ejecucion = "11. AYSEN")]
## Normalizar UNIVERSIDAD DE MAGALLANES
proyectosanid_raw[i = institucion_principal %like% "UNIV" &
               institucion_principal %like% "MAG",
             j = institucion_principal := "UNIVERSIDAD DE MAGALLANES"]
## Normalizar UNIVERSIDAD DE AYSEN
proyectosanid_raw[i = institucion_principal %like% "UNIV" &
               institucion_principal %like% "AYSEN",
             j = institucion_principal := "UNIVERSIDAD DE AYSEN"]
## Normalizar INSTITUTO ANTARTICO CHILENO
proyectosanid_raw[i = institucion_principal %like% "INST" &
               institucion_principal %like% "ANTAR",
             j = institucion_principal := "INSTITUTO ANTARTICO CHILENO"]
## Normalizar ESCUELA ARTURO PRAT
proyectosanid_raw[i = institucion_principal %like% "ARTURO" &
               institucion_principal %like% "PRAT" &
               !institucion_principal %like% "UNIV" &
               region_ejecucion == "12. MAGALLANES Y ANTARTICA CHILENA",
             j = institucion_principal := "ESCUELA CAPITAN ARTURO PRAT"]
## Normalizar ESCUELA ARTURO PRAT
proyectosanid_raw[i = institucion_principal %like% "LICEO SAN JOSE ",
             j = institucion_principal := "LICEO SAN JOSE U.R."]
## Normalizar COLEGIO SANTA TERESA DE LOS ANDES
proyectosanid_raw[i = institucion_principal %like% "SANTA TERESA" &
               institucion_principal %like% "ANDES",
             j = institucion_principal := "COLEGIO SANTA TERESA DE LOS ANDES"]
## Año de finalización
proyectosanid_raw[, ano_finalizacion := round(as.numeric(ano_fallo) + (duracion_meses/12))]

# Subset de macrozona AUSTRAL -----------------------------------------------------------------

## Transformamos Ñ por N en nombre responsable solo en aquellos de macrozona austral
proyectosanid_raw[i = region_ejecucion %chin% c("11. AYSEN", "12. MAGALLANES Y ANTARTICA CHILENA") |
                    institucion_principal %like% "MAGALLANES" &
                    nombre_responsable %like% "Ñ",
                  j = nombre_responsable := gsub("Ñ", "N", nombre_responsable, useBytes = TRUE)]

## Normalizamos el INSTITUTO DE INVESTIGACIONES AGROPECUARIAS por INIA MAGALLANES
proyectosanid_raw[i = region_ejecucion %chin% c("11. AYSEN", "12. MAGALLANES Y ANTARTICA CHILENA") |
                    institucion_principal %like% "MAGALLANES" &
                    institucion_principal %like% "AGROPECUARIAS",
                  j = institucion_principal := "INIA MAGALLANES"]


## Creamos nueva columna 'ubicacion_institucion' usando una lista de cotejo con la ubicacion
## de las instituciones basado en la región de ejecución y la institución principal
hoja_consulta <- data.table::fread(input = "data-raw/ubicacion_institucion.csv")
proyectosanid <- data.table::merge.data.table(x = proyectosanid_raw, y = hoja_consulta, by = c("region_ejecucion", "institucion_principal"), all.x = TRUE)

## Lo traspasamos a formato tibble - más amigable para explorar los datos
proyectosanid <- tibble::as_tibble(proyectosanid)

# Comprobación final --------------------------------------------------------------------------

usethis::use_data(proyectosanid, overwrite = TRUE)

library(dplyr)
library(stringr)
library(readr)
library(writexl)
library(lubridate)
library(slider)
library(timetk) ## questioning
library(here)


# 1.0 urls, static files and params  ----
url_incidenza <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-regioni/dpc-covid19-ita-regioni.csv"
url_dati_rif <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-statistici-riferimento/popolazione-istat-regione-range.csv"
url_vaccini <- "https://raw.githubusercontent.com/italia/covid19-opendata-vaccini/master/dati/somministrazioni-vaccini-latest.csv"
static_data <- read_excel(here("data", "data-raw", "static_data.xlsx"))


delta <- 7
efficacia <- 0.95



# 2.0 dati prepped (4 months ago)  ----
# dati relativi a popolazione per ogni regione
dati_statistici_riferimento <- read_csv(url_dati_rif, show_col_types = FALSE) %>%
  count(denominazione_regione,
        wt = totale_generale,
        name = "popolazione_totale",
        sort = T
  )



# 3 Incidenza ----
incidenza_prepped <- read_csv(url_incidenza, show_col_types = FALSE) %>%
  select(data, denominazione_regione, totale_casi, terapia_intensiva, ricoverati_con_sintomi) %>%
  mutate(
    data = str_extract(data, "([^\\s]+)"),
    data = ymd(data)
  )

inciddenza_per_settimana <- incidenza_prepped %>%
  group_by(denominazione_regione) %>%
  mutate(
    totale_casi_lag = lag(totale_casi, n = delta),
    incremento = totale_casi - totale_casi_lag
  ) %>%
  ungroup()


# 4  Vaccini  ----
vaccini_prepped <- read_csv(url_vaccini, show_col_types = FALSE) %>%
  select(data = data_somministrazione, denominazione_regione = nome_area, fascia_anagrafica, fornitore, prima_dose, seconda_dose, pregressa_infezione) %>%
  mutate(
    data = ymd(data),
    denominazione_regione = case_when(
      denominazione_regione == "Friuli-Venezia Giulia" ~ "Friuli Venezia Giulia",
      denominazione_regione == "Provincia Autonoma Bolzano / Bozen" ~ "P.A. Bolzano",
      denominazione_regione == "Provincia Autonoma Trento" ~ "P.A. Trento",
      denominazione_regione == "Valle d'Aosta / Vallée d'Aoste" ~ "Valle d'Aosta",
      TRUE ~ denominazione_regione
    )
  ) %>%
  group_by(data, denominazione_regione, fornitore) %>%
  summarise(across(where(is.numeric), sum)) %>%
  mutate(totale = case_when(
    fornitore == "Janssen" ~ prima_dose + pregressa_infezione,
    TRUE ~ seconda_dose + pregressa_infezione
  ))

vaccini_per_settimana <- vaccini_prepped %>%
  group_by(data, denominazione_regione) %>%
  summarise(nuovi_vaccinati = sum(totale)) %>%
  group_by(denominazione_regione) %>%
  mutate(vaccinati = cumsum(nuovi_vaccinati))


# 5 output ----

output <- inciddenza_per_settimana %>%
  left_join(static_data) %>%
  left_join(vaccini_per_settimana) %>%
  mutate(
    incidenza = incremento / (popolazione / 100000),
    saturazione_ti = terapia_intensiva / PL_terapia_intensiva,
    saturazione_area_non_critica = ricoverati_con_sintomi / PL_area_non_critica,
    casi_soglia_50 = popolazione / 100000 * 50,
    casi_soglia_150 = popolazione / 100000 * 150,
    casi_soglia_250 = popolazione / 100000 * 250,
    vaccinati_suscettibili = round(vaccinati * (1 - efficacia), 0),
    suscettibili = round(popolazione - vaccinati + vaccinati_suscettibili, 0),
    casi_soglia_50_suscettibili = suscettibili / 100000 * 50,
    casi_soglia_150_suscettibili = suscettibili / 100000 * 150,
    casi_soglia_250_suscettibili = suscettibili / 100000 * 250,
    soglia_50_effettiva = round(casi_soglia_50_suscettibili / (popolazione / 100000), 0),
    soglia_150_effettiva = round(casi_soglia_150_suscettibili / (popolazione / 100000), 0),
    soglia_250_effettiva = round(casi_soglia_250_suscettibili / (popolazione / 100000), 0),
    moltiplicatore_vaccini = casi_soglia_50 / casi_soglia_50_suscettibili,
    soglia_50_equivalente = round(50 * moltiplicatore_vaccini, 0),
    soglia_150_equivalente = round(150 * moltiplicatore_vaccini, 0),
    soglia_250_equivalente = round(250 * moltiplicatore_vaccini, 0),
    indicatore_stress = (incidenza) / soglia_50_equivalente
  ) %>%
  mutate_if(is.numeric, round, digits = 2)




#
#
# write_xlsx(
#   list(
#     input = input,
#       suscettibili = suscettibili,
#     soglia_effettiva = soglia_effettiva,
#     soglia_equivalente = soglia_equivalente,
#     rischio_zona_gialla = rischio_zona_gialla,
#     all = risultati
#   ),
#   paste0("data/risultati-",Sys.Date(),"-",sample(10,1),".xlsx")
# )
#



# 6 Visualization Data ----


## 6.1 tabella semplice
## 6.2 mappa
## 6.3 scatterplot
## 6.4 Range Plot
## 6.5 Time series (settimanale)
## 6.6 Time series (giornaliero)

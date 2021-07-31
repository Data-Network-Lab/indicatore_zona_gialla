library(dplyr)
library(stringr)
library(readr)
library(writexl)
library(lubridate)
library(slider)
library(timetk) ## questioning
library(here)



## 0 utils ----
## week_slider
week_summary <- function(data) {
  group_by(data, denominazione_regione) %>%
    summarise(
      start = min(data),
      end = max(data),
      totale_casi_da_inizio = last(totale_casi),
      terapia_intensiva = sum(terapia_intensiva),
      ricoverati_con_sintomi = sum(ricoverati_con_sintomi)
    )
}


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


incidenza_prepped <- read_csv(url_incidenza, show_col_types = FALSE) %>%
  select(data, denominazione_regione, totale_casi, terapia_intensiva, ricoverati_con_sintomi) %>%
  mutate(
    data = str_extract(data, "([^\\s]+)"),
    data = ymd(data)
  )




# 3 Incidenza ----
## 3.1 grouped by week lag 1 (rolling from today) ----
## Can control how many weeks with argument .before
#
#   .before: How many elements before the current one should be included in the window?
#
#   .after: How many elements after the current one should be included in the window?
#
#   .complete: Should .f only be evaluated when there is enough data to make a complete window?
#
#   .step: The number of elements to shift forward between calls to .f.
#
incidenza_nicco <- incidenza_prepped %>%
  slide_period_dfr(
    incidenza_prepped$data,
    "week",
    week_summary
  ) %>%
  group_by(denominazione_regione) %>%
  mutate(
    totale_casi_lag = lag(totale_casi_da_inizio, n = 1),
    incremento = totale_casi_da_inizio - totale_casi_lag
  ) %>%
  ungroup()


## 3.3 grouped by day lag 7
## delta = 7
incidenza_vinc <- incidenza_prepped %>%
  group_by(denominazione_regione) %>%
  mutate(
    totale_casi_lag = lag(totale_casi, n = delta),
    incremento = totale_casi - totale_casi_lag
  ) %>%
  ungroup()


# 4  Vaccini  ----
## week_slider
week_summary_vacc <- function(data) {
  group_by(data, denominazione_regione) %>%
    summarise(start = min(data), end = max(data), nuovi_vaccinati = sum(totale))
}


## 4.1 vaccinati by day ----
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


## 4.2 grouped by week  ----
vaccini_nicco <- vaccini_prepped %>%
  slider::slide_period_dfr(
    vaccini_prepped$data,
    "week",
    week_summary_vacc
  ) %>%
  group_by(denominazione_regione) %>%
  mutate(vaccinati = cumsum(nuovi_vaccinati))




## 4.3 grouped by day ----
vaccini_vinc <- vaccini_prepped %>%
  group_by(data, denominazione_regione) %>%
  summarise(nuovi_vaccinati = sum(totale)) %>%
  group_by(denominazione_regione) %>%
  mutate(vaccinati = cumsum(nuovi_vaccinati))



output_nicco <- incidenza_nicco %>%
  left_join(static_data) %>%
  left_join(vaccini_nicco) %>%
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

output_vinc <- incidenza_vinc %>%
  left_join(static_data) %>%
  left_join(vaccini_vinc) %>%
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



output_vinc


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

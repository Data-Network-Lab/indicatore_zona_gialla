library(dplyr)
library(stringr)
library(readr)
library(readxl)
library(writexl)
library(lubridate)
library(timetk)
library(tidyr)
library(here)

## 0 params ----
efficacia <- 0.95
last_days <- 10


# 1 urls & params  ----
url_incidenza <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-regioni/dpc-covid19-ita-regioni.csv"
url_dati_rif <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-statistici-riferimento/popolazione-istat-regione-range.csv"
url_vaccini <- "https://raw.githubusercontent.com/italia/covid19-opendata-vaccini/master/dati/somministrazioni-vaccini-latest.csv"
static_data <- read_excel(here("data", "data-raw", "static_data.xlsx"))


# 2 dati_statistici_riferimento (4 months ago)  ----
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


## metti solo date complete . complete argument
## in slider_period_dfr
incidenza_per_settimana <- incidenza_prepped %>%
  group_by(denominazione_regione) %>%
  summarise_by_time(
    .date_var = data,
    .by = "week", .type = "ceiling",
    totale_casi_da_inizio = last(totale_casi),
    terapia_intensiva = sum(terapia_intensiva),
    ricoverati_con_sintomi = sum(ricoverati_con_sintomi)
  ) %>%
  tk_augment_lags(
    .value = totale_casi_da_inizio,
    .lags = 1
  ) %>%
  mutate(
    incremento_settimanale = totale_casi_da_inizio - totale_casi_da_inizio_lag1
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
  )


vaccini_per_settimana <- vaccini_prepped %>%
  group_by(data, denominazione_regione, fornitore) %>%
  summarise_by_time(
    .date_var = data,
    .by = "week",
    .type = "ceiling",
    across(where(is.numeric), sum)
  ) %>%
  mutate(
    totale = case_when(
      fornitore == "Janssen" ~ prima_dose + pregressa_infezione,
      TRUE ~ seconda_dose + pregressa_infezione
    )
  ) %>%
  group_by(data, denominazione_regione) %>%
  summarise(nuovi_vaccinati = sum(totale)) %>%
  group_by(denominazione_regione) %>%
  mutate(vaccinati = cumsum(nuovi_vaccinati))



# 5 output -----
output <- incidenza_per_settimana %>%
  left_join(static_data) %>%
  left_join(vaccini_per_settimana) %>%
  mutate(
    incidenza = incremento_settimanale / (popolazione / 100000),
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
  mutate(across(where(is.numeric), round, digits = 2))



write_csv(
  x = output,
  file = here("data", "indicatore_stress.csv"),
  append = TRUE
)



# 6 Visualization Data ----

## 6.1 tabella semplice
output %>%
  filter_by_time(
    .date_var = data,
    .start_date = today() - 6,
    .end_date = today()
  ) %>% 
write_csv(
  file = here("data", "graph-data", "tabella_semplice.csv"),
  append = TRUE
)

## 6.2 mappa
output %>%
  select(denominazione_regione, indicatore_stress) %>%
  write_csv(
    file = here("data", "graph-data", "mappa.csv"),
    append = TRUE
  )


## 6.3 scatterplot
output %>%
  select(
    denominazione_regione,
    indicatore_stress,
    incidenza
  ) %>%
  write_csv(
    file = here("data", "graph-data", "scatterplot.csv"),
    append = TRUE
  )

## 6.4 Arrow Plot
output %>%
  filter_by_time(
    .date_var = data,
    .start_date = today() - 13,
    .end_date = today()
  ) %>% 
  select(data, denominazione_regione, indicatore_stress) %>% 
  pivot_wider(names_from = data, values_from = indicatore_stress) %>% 
  write_csv(
    file = here("data", "graph-data", "arrow_plot.csv"),
    append = TRUE
  )

## 6.5 Time series (settimanale) per tante settimane

output %>%
  filter_by_time(
    .date_var = data,
    .start_date = ymd("2021-01-01"),
    .end_date = today()
  ) %>%
  group_by(data) %>%
  pivot_wider(names_from = denominazione_regione, names_prefix = "regione ", values_from = indicatore_stress) %>%
  select(contains("regione")) %>% 
  fill(contains("regione"), .direction = 'updown') %>%  
  ungroup() %>% 
  write_csv(
    file = here("data", "graph-data", "variazione_settimanale.csv"),
    append = TRUE
  )

## 6.6 Time series (giornaliero) per l'ultima settimana

output %>%
  filter_by_time(
    .date_var = data,
    .start_date = today() -6,
    .end_date = today()
  ) %>%
  group_by(data) %>%
  pivot_wider(names_from = denominazione_regione, names_prefix = "regione ", values_from = indicatore_stress) %>%
  select(contains("regione")) %>% 
  fill(contains("regione"), .direction = 'updown') %>%  
  ungroup() %>% 
  write_csv(
    file = here("data", "graph-data", "variazione_ultima_settimana.csv"),
    append = TRUE
  )

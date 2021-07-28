library(dplyr)
library(readxl)
library(lubridate)

url_dpc <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-regioni/dpc-covid19-ita-regioni.csv"
url_vaccini <- "https://raw.githubusercontent.com/italia/covid19-opendata-vaccini/master/dati/somministrazioni-vaccini-latest.csv"
data_dpc <- read.csv(url_dpc)
data_vaccini <- read.csv(url_vaccini)
static_data <- read_excel("static_data.xlsx")


efficacia <- 0.95
delta <- 7

vaccini <- data_vaccini %>% 
  select(data = data_somministrazione, denominazione_regione = nome_area, fascia_anagrafica, fornitore, prima_dose, seconda_dose, pregressa_infezione) %>% 
  mutate(data = as_date(data), 
         denominazione_regione = case_when(denominazione_regione == "Friuli-Venezia Giulia" ~ "Friuli Venezia Giulia", 
                                           denominazione_regione == "Provincia Autonoma Bolzano / Bozen" ~ "P.A. Bolzano",
                                           denominazione_regione == "Provincia Autonoma Trento" ~ "P.A. Trento",
                                           denominazione_regione == "Valle d'Aosta / Vallée d'Aoste" ~ "Valle d'Aosta",
                                           TRUE ~ denominazione_regione)) %>% 
  group_by(data, denominazione_regione, fornitore) %>% 
  summarise_if(is.numeric, sum) %>% 
  rowwise() %>% 
  mutate(totale = case_when(fornitore == "Janssen" ~ prima_dose + pregressa_infezione, 
                            TRUE ~ seconda_dose + pregressa_infezione)) %>% 
  group_by(data, denominazione_regione) %>% 
  summarise(nuovi_vaccinati = sum(totale)) %>% 
  group_by(denominazione_regione) %>% 
  mutate(vaccinati = cumsum(nuovi_vaccinati))


output <- data_dpc %>% 
  select(data, denominazione_regione, totale_casi, terapia_intensiva, ricoverati_con_sintomi) %>% 
  mutate(data=as_date(data)) %>% 
  group_by(denominazione_regione) %>% 
  mutate(totale_casi_lag = lag(totale_casi, n = delta), 
         incremento = totale_casi-totale_casi_lag) %>% 
  ungroup() %>% 
  left_join(static_data) %>% 
  left_join(vaccini) %>% 
  mutate(incidenza = incremento/(popolazione/100000), 
         saturazione_ti = terapia_intensiva/PL_terapia_intensiva, 
         saturazione_area_non_critica = ricoverati_con_sintomi/PL_area_non_critica,
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
          indicatore_stress = (incidenza) / soglia_50_equivalente) %>% 
  mutate_if(is.numeric, round, digits=2) 

output

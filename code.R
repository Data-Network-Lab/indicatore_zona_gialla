library(readxl)
library(dplyr)
library(here)

data <- read_excel(here::here("input_indicatore_22luglio - AGGIORNATO.XLSX"))
names(data)[1:3] <- c("regione", "popolazione", "vaccinati")
efficacia <- 0.95


risultati <- data %>%
  mutate(
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
    indicatore_soglia_gialla = (incidenza) / soglia_50_equivalente
  )

input <- risultati %>%
  select(regione, popolazione, vaccinati, incidenza)

suscettibili <- risultati %>%
  select(regione, popolazione, suscettibili)

soglia_effettiva <- risultati %>%
  select(regione, soglia_50_effettiva, soglia_150_effettiva, soglia_250_effettiva)

soglia_equivalente <- risultati %>%
  select(regione, moltiplicatore_vaccini, soglia_50_equivalente, soglia_150_equivalente, soglia_250_equivalente)


rischio_zona_gialla <- risultati %>%
  select(regione, vaccinati, incidenza, soglia_50_equivalente, indicatore_soglia_gialla)


writexl::write_xlsx(
  list(
    input = input,
    suscettibili = suscettibili,
    soglia_effettiva = soglia_effettiva,
    soglia_equivalente = soglia_equivalente,
    rischio_zona_gialla = rischio_zona_gialla,
    all = risultati
  ),
  here::here("data", "risultati_20210722_aggiornato.xlsx")
)

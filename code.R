library(dplyr)
library(stringr)
library(purrr)
library(readr)
library(readxl)
library(lubridate)
library(here)
library(logger)
library(tidyr)
library(httr)


# 0 utils ----
# thx https://sherif.io/2016/06/30/checking-links-responses-httr-r.html





check_url_status <- function(href) {
  log_info("Checking ", href, "...\n")
  tryCatch(
    {
      check_head <- HEAD(href)
      status <- check_head$status_code %>% as.integer()
      if (status == "0" | status == "522") {
        return(log_error("Timed out"))
      }
      if (status == "520") {
        return(log_error("Unknown error: (520)"))
      }
      msg <- status %>%
        http_status() %>%
        .$message

      return(log_info(msg))
    },
    error = function(e) {
      return(log_error("no status code..."))
    }
  )
}


# 1.0 urls, static files and params  ----



urls <- list(
  url_incidenza <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-regioni/dpc-covid19-ita-regioni.csv",
  url_dati_rif <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-statistici-riferimento/popolazione-istat-regione-range.csv",
  url_vaccini <- "https://raw.githubusercontent.com/italia/covid19-opendata-vaccini/master/dati/somministrazioni-vaccini-latest.csv"
)

log_info("Parsing Data Sources")
log_info("...")
map(urls, check_url_status)


static_data <- read_excel(here("data", "data-raw", "static_data.xlsx"))


delta <- 7
efficacia <- 0.95



# 2.0 dati_statistici_riferimento prepped   ----
# (4 months ago)

log_info("read & prepping dati_statistici_riferimento")

tryCatch(
  {
    dati_statistici_riferimento <- 
    read_csv(pluck(urls, 2), show_col_types = FALSE) %>%
      count(denominazione_regione,
            wt = totale_generale,
            name = "popolazione_totale",
            sort = T
      )
    log_info("read dati_statistici_riferimento success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong with dati_statistici_riferimento, error: \n {e}"))
    
  }
)

# 3 Incidenza ----


log_info("read and prepping incidenza")
tryCatch(
  {
    withCallingHandlers(
      {
        incidenza_prepped <- read_csv(pluck(urls, 1), show_col_types = FALSE) %>%
          select(data, denominazione_regione, totale_casi, terapia_intensiva, ricoverati_con_sintomi) %>%
          mutate(
            data = str_extract(data, "([^\\s]+)"),
            data = ymd(data)
          )
        log_info("read Incidenza success")
      },
      message = function(cnd) log_warn(cnd$message)
    )
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong with Incidenza, error: \n {e}"))
  }
)


log_info("elaborate incidenza")
tryCatch(
  {
    incidenza_per_settimana <- incidenza_prepped %>%
      group_by(denominazione_regione) %>%
      mutate(
        totale_casi_lag = lag(totale_casi, n = delta),
        incremento = totale_casi - totale_casi_lag
      ) %>%
      ungroup()
    log_info("elaboration incidenza success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong with elaborate incidenza, error: \n {e}"))
    
  }
)





# 4  Vaccini  ----
log_info("read & prepping vaccini")


tryCatch(
  {
    withCallingHandlers(
      {
        vaccini_prepped <- read_csv(pluck(urls, 3), show_col_types = FALSE) %>%
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
        log_info("read & prep Vaccini success")
      },
      message = function(cnd) log_warn(cnd$message)
    )
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong with read & prep, error: \n {e}"))
  }
)

log_info("elaborate vaccini")
tryCatch(
  {
    withCallingHandlers(
      {
        vaccini_per_settimana <- vaccini_prepped %>%
          group_by(data, denominazione_regione) %>%
          summarise(nuovi_vaccinati = sum(totale)) %>%
          group_by(denominazione_regione) %>%
          mutate(vaccinati = cumsum(nuovi_vaccinati))
        log_info("elaborate Vaccini success")
      },
      message = function(cnd) log_warn(cnd$message)
    )
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong with elaborate Vaccini, error: \n {e}"))
  }
)


# 5 output ----

log_info("join tbls")


tryCatch(
  {
    withCallingHandlers(
      {
        pre_output <- incidenza_per_settimana %>%
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
          mutate(across(where(is.numeric), round, digits = 2))
        log_info("tables joined with success")
      },
      message = function(cnd) log_warn(cnd$message)
    )
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while joining tables, error: \n {e}"))
  }
)



## TODO add_totals per week
# output <- pre_output %>%
#   bind_rows(
#     pre_output %>%
#       group_by(data) %>%
#       summarise(across(where(is.numeric), ~ sum(.x, na.rm = TRUE))) %>%
#       mutate("cyl" = "Total")
#   )


log_info("write .csv output")
tryCatch(
  {
    write_csv(
      x = pre_output,
      file = here("data", "indicatore_stress.csv"),
      append = TRUE
    )
    log_info("write .csv output success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while joining tables, error: \n {e}"))
  }
)


# 6 Visualization Data ----


## 6.1 tabella semplice
log_info("graph: write .csv tabella semplice")
tryCatch(
  {
    pre_output %>%
      filter(between(data, left = today() - 1, right = today() - 1)) %>%
      write_csv(
        file = here("data", "graph-data", "tabella_semplice.csv"),
        append = TRUE
      )
    log_info("write .csv tabella semplice success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while tabella semplice, error: \n {e}"))
  }
)


## 6.2 mappa
log_info("graph: write .csv mappa")
tryCatch(
  {
    pre_output %>%
      select(denominazione_regione, indicatore_stress) %>%
      write_csv(
        file = here("data", "graph-data", "mappa.csv"),
        append = TRUE
      )
    log_info("write .csv mappa success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while mappa, error: \n {e}"))
  }
)


## 6.3 scatterplot
log_info("graph: write .csv scatterplot")
tryCatch(
  {
    pre_output %>%
      select(
        denominazione_regione,
        indicatore_stress,
        incidenza
      ) %>%
      write_csv(
        file = here("data", "graph-data", "scatterplot.csv"),
        append = TRUE
      )
    log_info("write .csv scatterplot success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while scatterplot, error: \n {e}"))
  }
)


## 6.4 Arrow Plot
log_info("graph: write .csv arrowplot")
tryCatch(
  {
    indicatore_t <- pre_output %>%
      select(data, denominazione_regione, indicatore_stress_t = indicatore_stress) %>%
      tail(21)
    log_info("write .csv indicatore_t success")
    
    indicatore_t1 <- pre_output %>%
      select(indicatore_stress_t1 = indicatore_stress) %>%
      tail(42) %>%
      head(21)
    log_info("write .csv indicatore_t1 success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while arrowplot, error: \n {e}"))
  }
)


## 6.5 Time series (settimanale)
log_info("graph: write .csv time series (settimanale)")
tryCatch(
  {
    pre_output %>%
      select(data, denominazione_regione, indicatore_stress) %>%
      mutate(week = week(data)) %>%
      filter(between(data, left = ymd("2021-01-01"), right = today())) %>%
      group_by(week, denominazione_regione) %>%
      summarise(media_indicatore_stress = mean(indicatore_stress)) %>%
      drop_na() %>%
      pivot_wider(names_from = denominazione_regione, names_prefix = "regione ", values_from = media_indicatore_stress) %>%
      mutate(across(where(is.numeric), round, digits = 2)) %>%
      ungroup() %>%
      filter(row_number() < n()) %>%
      write_csv(
        file = here("data", "graph-data", "variazione_settimanale.csv"),
        append = TRUE
      )
    log_info("write .csv Time series (settimanale) success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while Time series (settimanale), error: \n {e}"))
  }
)



## 6.6 Time series (giornaliero)

log_info("graph: write .csv time series (giornaliero)")

last_days <- 10

tryCatch(
  {
    pre_output %>%
      select(data, denominazione_regione, indicatore_stress) %>%
      tail(21 * last_days) %>%
      group_by(data) %>%
      pivot_wider(names_from = denominazione_regione, names_prefix = "regione ", values_from = indicatore_stress) %>%
      write_csv(
        file = here("data", "graph-data", "variazione_giornaliera.csv"),
        append = TRUE
      )
    
    log_info("write .csv Time series (giornaliero) success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong while Time series (giornaliero), error: \n {e}"))
  }
)

# 7 append logs ----

log_appender(appender_file(file = "logs"))

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
        return(log_error("message [Timed out]"))
      }
      if (status == "520") {
        return(log_error("message [Unknown error: (520)]"))
      }
      msg <- status %>%
        http_status() %>%
        .$message

      return(log_info(msg))
    },
    error = function(e) {
      return(log_error("message [no status code...]"))
    }
  )
}


# 1.0 urls, static files and params  ----

log_appender(appender_file(file = "logs.json", append = TRUE))
log_layout(layout_json())

urls <- list(
  url_incidenza <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-regioni/dpc-covid19-ita-regioni.csv",
  url_dati_rif <- "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-statistici-riferimento/popolazione-istat-regione-range.csv",
  url_vaccini <- "https://raw.githubusercontent.com/italia/covid19-opendata-vaccini/master/dati/somministrazioni-vaccini-latest.csv"
)

## map check_url over urls
walk(urls, check_url_status)



## dati popolazione PL area non critica, PL terapia intensiva
## regione a statuto speciale P.A. Trento e P.A. Bolzano
## https://it.wikipedia.org/wiki/Regione_italiana_a_statuto_speciale#:~:text=Cinque%20regioni%20italiane%20sono%20chiamate,116%20della%20Costituzione).
## aggiornata a cr. 2019

tryCatch(
  {
    static_data <- read_excel(here("data", "data-raw", "static_data.xlsx")) %>% 
      add_row(denominazione_regione = "Italia",
              PL_area_non_critica = sum(.$PL_area_non_critica),
              PL_terapia_intensiva = sum(.$PL_terapia_intensiva),
              popolazione = sum(.$popolazione)
              )
    log_info("read static_data success")
  },
  error = function(e) {
    log_error(formatter_glue("something went wrong with static_data, error: {e}"))
  }
)



## params
delta <- 30
efficacia <- 0.95


# 
# # 2.0 dati_statistici_riferimento prepped   ----
# # (4 months ago)
# tryCatch(
#   {
#     dati_statistici_riferimento <- 
#     read_csv(pluck(urls, 2), show_col_types = FALSE) %>%
#       count(denominazione_regione,
#             wt = totale_generale,
#             name = "popolazione_totale",
#             sort = T
#       ) %>% 
#       add_row(denominazione_regione = "Italia", popolazione_totale = sum(.$popolazione_totale))
#     log_info("read dati_statistici_riferimento success")
#   },
#   error = function(e) {
#     log_error(formatter_glue("something went wrong with dati_statistici_riferimento, error: {e}"))
#     
#   }
# )

# 3 Incidenza ----
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
        
        log_info("prep Incidenza success")
      },
      message = function(cnd) log_warn("message [{cnd$message}]")
    )
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong with Incidenza, error: {e}]"))
  }
)


tryCatch(
  {
    incidenza_per_mese <- incidenza_prepped %>%
      split(incidenza_prepped$data) %>% 
      map_df(~ add_row(.x,
                       data = .x$data[1],
                       denominazione_regione = "Italia",
                       totale_casi = sum(.x$totale_casi),
                       terapia_intensiva = sum(.x$terapia_intensiva),
                       ricoverati_con_sintomi = sum(.x$ricoverati_con_sintomi)
      )) %>% 
      group_by(denominazione_regione) %>%
      mutate(
        totale_casi_lag = lag(totale_casi, n = delta),
        incremento = totale_casi - totale_casi_lag
      ) %>%
      ungroup()
    log_info("clean Incidenza success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong with elaborate incidenza, error: {e}]"))
    
  }
)




# 4  Vaccini  ----
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
          )) %>% 
          ungroup()
        
        log_info("prep Vaccini success")
      },
      message = function(cnd) log_warn("message [{cnd$message}]")
    )
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong with read & prep, error: {e}]"))
  }
)

tryCatch(
  {
    withCallingHandlers(
      {
        vaccini_per_mese <- vaccini_prepped %>%
          split(vaccini_prepped$data) %>% 
          map_df(~ add_row(.x,
                           data = .x$data[1],
                           denominazione_regione = "Italia",
                           prima_dose = sum(.x$prima_dose),
                           seconda_dose = sum(.x$seconda_dose),
                           pregressa_infezione = sum(.x$pregressa_infezione),
                           totale = sum(.x$totale)
          )) %>% 
          group_by(data, denominazione_regione) %>%
          summarise(nuovi_vaccinati = sum(totale)) %>%
          group_by(denominazione_regione) %>%
          mutate(vaccinati = cumsum(nuovi_vaccinati))
        log_info("clean Vaccini success")
      },
      message = function(cnd) log_warn("message [{cnd$message}]")
    )
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong with elaborate Vaccini, error: {e}]"))
  }
)


# 5 output ----
# frequenza di aggiornamento dei vaccini è in ritardo rispetto a quella dell'incidenza
tryCatch(
  {
    withCallingHandlers(
      {
        output <- incidenza_per_mese %>%
          left_join(static_data) %>%
          ## moved to right join
          right_join(vaccini_per_mese) %>%
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
            indicatore_stress = ((incidenza) / soglia_50_equivalente)/4
          ) %>%
          mutate(across(where(is.numeric), round, digits = 2))
        
        log_info("prep indicatore-stress success")
      },
      message = function(cnd) log_warn("message [{cnd$message}]")
    )
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while joining tables, error: \n {e}]"))
  }
)

tryCatch(
  {
    write_csv(
      x = output,
      file = here("data", "indicatore_stress.csv")
    )
    log_info("write output success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while writing indicatore_stress, error: \n {e}]"))
  }
)


# 6 Visualization Data ----

## 6.1 tabella semplice
tryCatch(
  {
    output %>%
      filter(data == today()-2) %>% 
      rename(
        "Indicatore Stress" = indicatore_stress,
        "Regione"           = denominazione_regione,
        "Totale Casi"       = totale_casi,
        "Casi TI"           = terapia_intensiva,
        "Ricoverati con Sintomi" = ricoverati_con_sintomi,
        "Totale Casi (lag)" = totale_casi_lag,
        "Incremento (unità)" = incremento,
        "PL area non critica" = PL_area_non_critica,
        "PL TI" = PL_terapia_intensiva,
        "Popolazione" = popolazione,
        "Nuovi Vaccinati" = nuovi_vaccinati,
        "Vaccinati" = vaccinati,
        "Saturazione TI" = saturazione_ti,
        "Saturazione area non critica" = saturazione_area_non_critica,
        "Indicatore di Stress" = indicatore_stress
      ) %>% 
      write_csv(
        file = here("data", "graph-data", "tabella_semplice_per_mese.csv")
      )
    log_info("write tabella_semplice success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while writing tabella semplice, error: \n {e}]"))
  }
)


## 6.2 mappa
tryCatch(
  {
    output %>%
      filter(data == today()-2) %>% 
      select(denominazione_regione, indicatore_stress) %>%
      write_csv(
        file = here("data", "graph-data", "mappa_per_mese.csv")
      )
    log_info("write mappa success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while writing mappa, error: \n {e}]"))
  }
)


## 6.3 scatterplot
tryCatch(
  {
    output %>%
      filter(data == today()-2) %>% 
      select(
        denominazione_regione,
        indicatore_stress,
        incidenza, 
        vaccinati,
        popolazione
      ) %>% 
      mutate(vaccinati_perc = vaccinati/popolazione,
             vaccinati_perc = round(vaccinati_perc, digits = 4)*100) %>% 
      rename("Vaccinati (%)" = vaccinati_perc,
             "Incidenza (100'000 abitanti)" = incidenza) %>% 
      write_csv(
        file = here("data", "graph-data", "scatterplot_per_mese.csv")
      )
    log_info("write scatterplot success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while wrinting scatterplot, error: \n {e}]"))
  }
)


## 6.4 Indicatorei di stress Arrow Plot base mensile
tryCatch(
  {
    indicatore_t <- output %>%
      filter(data == today()-4) %>% 
      select(data, denominazione_regione, indicatore_stress_t = indicatore_stress) 
    
    indicatore_t1 <- output %>%
      filter(data == today()-34) %>% 
      select(data, denominazione_regione, indicatore_stress_t1 = indicatore_stress) 
      
    
    right_join(indicatore_t, indicatore_t1, by = "denominazione_regione") %>%
      mutate(colour  = ifelse(indicatore_stress_t <= indicatore_stress_t1, yes = "decreasing", no = "increasing" )) %>%  View()
      write_csv(
        file = here("data","graph-data", "arrow_plot_per_mese.csv")
      )
    log_info("write arrow_plot success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while writing arrowplot, error: \n {e}]"))
  }
)


## 6.4.1  Arrow Plot
tryCatch(
  {
    indicatore_t <- output %>%
      filter(data == today()-2) %>% 
      select(data, denominazione_regione, indicatore_stress_t = indicatore_stress) 
    
    indicatore_t1 <- output %>%
      filter(data == today()-3) %>% 
      select(denominazione_regione, indicatore_stress_t1 = indicatore_stress) 
    
    
    right_join(indicatore_t, indicatore_t1, by = "denominazione_regione") %>% 
      write_csv(
        file = here("data","graph-data", "arrow_plot.csv")
      )
    log_info("write arrow_plot success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while writing arrowplot, error: \n {e}]"))
  }
)





## 6.5 Time series (settimanale)

tryCatch(
  {
    output %>%
      select(data, denominazione_regione, indicatore_stress) %>%
      mutate(month = month(data),
            year = year(data)) %>%
      ## dev choice to start from April, 1st 2021
      filter(between(data, left = ymd("2021-07-05"), right = today())) %>%
      group_by(month, year, denominazione_regione) %>%
      summarise(media_indicatore_stress = mean(indicatore_stress)) %>%
      drop_na() %>%
      pivot_wider(names_from = denominazione_regione, values_from = media_indicatore_stress) %>%
      mutate(
        across(where(is.numeric), round, digits = 2),
        month = as.Date(paste(year, month, 1, sep = "-"), format = "%Y-%U-%u")
             ) %>%
      ungroup() %>%
      filter(row_number() < n()) %>% 
      write_csv(
        file = here("data", "graph-data", "variazione_settimanale.csv")
      )
    log_info("write variazione_settimanale success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while writing variazione_settimanale, error: \n {e}]"))
  }
)



## 6.6 Time series (giornaliero)
last_days <- 60

tryCatch(
  {
    output %>%
      select(data, denominazione_regione, indicatore_stress) %>%
      filter(between(data, right = today()-2, left = today() - last_days)) %>%
      group_by(data) %>% 
      pivot_wider(names_from = denominazione_regione, values_from = indicatore_stress, names_sort = T) %>% 
      write_csv(
        file = here("data", "graph-data", "variazione_giornaliera.csv")
      )
    
    log_info("write variazione_giornaliera success")
  },
  error = function(e) {
    log_error(formatter_glue("message [something went wrong while writing variazione_giornaliera, error: \n {e}]"))
  }
)




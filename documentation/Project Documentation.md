--- 
title: "Project Docs"
author: "DataNetwork, Data Engineering team"
site: bookdown::bookdown_site
documentclass: book
bibliography: [book.bib, packages.bib]
biblio-style: apalike
link-citations: yes
---

# Welcome {.unnumbered}


<img src="images/apple-touch-icon.png" class="cover" width="120" height="120"/> Questa è la versione online della **Documentazione** dedicata al progetto _Indicatore Zona Gialla_ (**IZG**). La documentazione è tuttora in revisione, l'ultima data di rilascio è 2021-07-30. 


La documentazione si oritenta a presentare gli obiettivi a lungo termine del progetto condiviso, oltre al continuo aggiornamento
dell’indicatore 3.13 sono previsti l’ottimizzazione del flusso dei dati al fine di automatizzare la
creazione del report e di una dashboard online aggiornata in tempo reale. Nello specifico, la
presente proposta prevede la creazione e la predisposizione di una soluzione pilota per il
calcolo dell’Indice di stress del Sistema Sanitario, rispetto ad un perimetro circoscritto di
indicatori (3.1 e 3.13 Cfr. Instant Report Altems) ed articolata nei seguenti step:

- rielaborazione statistica ed analisi degli indicatori
- creazione, automazione e ottimizzazione del flusso dati
- sviluppo ed integrazione di una soluzione di front-end per data visualization (dashboard).




## License {.unnumbered}

This book is licensed to you under [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License](http://creativecommons.org/licenses/by-nc-nd/4.0/).

The code samples in this book are licensed under [Creative Commons CC0 1.0 Universal (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/), i.e. public domain.





<!--chapter:end:index.Rmd-->

# Data Network

## Chi siamo

**<span style="color:#5d3bff">DataNetwork</span>** è un'associazione _no-profit_ che connette Data Scientists, Data Analysts, Data Journalists... in tutta Italia. Il retaggio di ciascuno di nostri soci, che sia universitario, esperenziale, lavorativo o personale riflette il modello mentale tramite cui questi, in maniera differente, approcciano un medesimo problema. Chi fa parte della community di Data Network, in questo senso, crede che diversi pareri siano meglio di un solo parere e che più un problema è affrontato da diverse angolazioni e meglio è compreso.
Questi semplici concetti, racchiusi nelle parole di Alfabetizzazione dei dati (Data Literacy) and (Democariazie dei dati) Data Democracy, stanno alla base della piramide dei valori di Data Network e di un mondo che vuole avvantaggiarsi dei dati, non confondersi fra di essi ([infodemia](https://www.treccani.it/vocabolario/infodemia_%28Neologismi%29/)).


[Visita il sito](https://datanetwork.xyz/) per inviare la candidatura 




```html
<h2 class="cd-headline loading-bar">
                  
                    <span>DATA</span>
                                <span class="cd-words-wrapper is-loading">
                                                                <b class="is-hidden">SCIENTIST</b>
                                            <b class="is-hidden">ANALYST</b>
                                            <b class="is-hidden">ENGINEER</b>
                                            <b class="is-hidden">JOURNALIST</b>
                                            <b class="is-visible">ARCHITECT</b>
                                            <b class="is-hidden">OFFICER</b>
                                            <b class="is-hidden">ARTIST</b>
                                            <b class="is-hidden">EXPERT</b>
                                            <b class="is-hidden">LOVER</b>
                                    </span>
                             </h2>

```




Data Network is a no-profit  is either to connect different backgrounds Data Scientists in Milan and to spread Data Literacy.
Backgrounds (whether is educational, working experience or personal) mirror the way people approach a problem, the more they are the better the problem is understood.
Data Literacy (i.e. transform complex mathematical problems and graph into approachable and familiar guidelines) is crucial, especially in this tough times where the overwhelming amount of data (infodemia) may confuse both the reader and the analyst.
DN combines all of that by organizing data-themed events and offering technical and non technical corner talks held by a plenty of Junior and Senior scientists in front of anyone interested.
Moreover the association has partnered with many different stakeholders, ranging from start-ups, telco, IT services, management consulting firms and other major corporate connections. It has also pushed teams into Hackatons and conferences within Italy.

## Cosa facciamo

**<span style="color:#5d3bff">DN</span>** nella sua parte promozionale organizza eventi a tema "dati" nell'area di Milano e presto in remoto offrendo corner talks di esperti e figure più Junior provenienti da ogni settore. Data Network può essere anche il luogo di presentazione della propria start-up, adatto alla ricerca di collaboratori esterni e consigli da esperti già operanti nella area strategica d'affari.
Data Network vanta collaborazioni con una multitudine di Stakeholders provenienti da varie industrie: dalle telecomunicazioni, ai servizi di streaming, a forti connessioni con società di management consulting, per arrivare a giganti corporate. 
La comunità proattiva di data network è sempre pronta a nuove sfide e recentemente è stato composto un team per partecipare ad Hackatons e competizioni a tema codice e dati.


## **<span style="color:#5d3bff">Data Network</span>** match

Una funzione esclusiva a cui i soci hanno accesso è il Data Network Match. DN match è uno strumento di ricerca semplice e intuitivo tramite il quale studenti, professionisti e aziende potranno contattare e ricercare i profili più in linea con le proprie esigenze. Non è mai stato così semplice trovare professionalità di valore e data literate per un nuovo progetto. Alcuni altri scopi:

- le esperienze vengono condivise
- la ricerca di un collaboratore per progetti interni o esterni sia facile e veloce
- il contatto diretto con stakeholders delle realtà partners di DN 



## Un po' di storia recente


...

<!--chapter:end:01-datanetwork.Rmd-->

# Contesto {#contesto}


## Contesto del Progetto 

L’Alta Scuola di Economia e Management dei Sistemi Sanitari (**<span style="color:#ee943a">ALTEMS</span>**) della Facoltà di Economia in collaborazione con il Dipartimento di Scienze della Vita e Sanità Pubblica (Sezione di Igiene)
della Facoltà di Medicina e Chirurgia diffonde settimanalmente l’Instant Report COVID-19, un’iniziativa che offre un confronto sistematico delle modalità di risposta delle Regioni italiane al Sars-COV-2. Il Report si basa su un set di indicatori costruito per monitorare l’evoluzione della pandemia nella “Fase 2”, formalmente avviata il 4 maggio con la conclusione del lockdown nazionale. Al fianco dei nuovi indicatori, il Rapporto continua ad offrire l’aggiornamento di alcuni indicatori selezionati tra quelli che hanno caratterizzato il modello di risposta delle Regioni nella fase 1. L’analisi riguarda tutte le 21 Regioni e Province Autonome italiane.


## Gruppo di Lavoro

Il gruppo di lavoro è coordinato da **Americo Cicchetti**, Professore Ordinario di Organizzazione Aziendale presso la Facoltà di Economia dell’Università Cattolica del Sacro Cuore si avvale della advisorship scientifica del Prof. **Gianfranco Damiani** e della Dott.ssa **Maria Lucia Specchia** della Sezione di Igiene - Dipartimento di Scienze della Vita e Sanità Pubblica. A partire dal Report #4 la collaborazione si è estesa al Centro di Ricerca e Studi in Management Sanitario dell’Università Cattolica (Prof. **Eugenio Anessi Pessina**), al Centro di Ricerca e Studi sulla Leadership in Medicina dell’Università Cattolica (Prof. **Walter Ricciardi**) e al Gruppo di Organizzazione dell’Università Magna Græcia di Catanzaro (Prof. **Rocco Reina**). Il team multidisciplinare è composto da economisti e aziendalisti sanitari, medici di sanità pubblica, ingegneri informatici, psicologi e statistici.



## Finalità e Proposta

La finalità è comprendere le implicazioni delle diverse strategie adottate dalle Regioni per fronteggiare la diffusione del virus e le conseguenze del Covid-19 in contesti diversi per trarne indicazioni per il futuro prossimo e per acquisire insegnamenti derivanti da questa drammatica esperienza.


In linea con gli obiettivi sopra descritti, l’associazione **<span style="color:#5d3bff">Data Network</span>** propone il suo supporto nel curare e valorizzare il ruolo dei dati all’interno del progetto, convinta che l’ampia gamma di dati aperti (open data) a disposizione nel settore pubblico-sanitario e la conseguente possibilità di riutilizzo degli stessi possa consentire di sfruttarne il potenziale e contribuire allo sviluppo economico nonchè ad importanti obiettivi sociali quali la responsabilizzazione e la trasparenza. Forte di avere a disposizione un gruppo di soci con esperienze e competenze eterogenee, Data Network ritiene di poter offrire un contributo qualificato a supporto della prosecuzione delle iniziative di ALTEMS mettendo a disposizione professionalità con una consolidata esperienza sulle tematiche oggetto della proposta.




<!--chapter:end:02-contesto.Rmd-->

# Indicatore Zona Gialla

Il presente step ha l’obiettivo di analizzare il lavoro svolto attualmente per la produzione
della reportistica, prendendo in considerazione **sorgenti dati**, strumenti di manipolazione dati
utilizzati e caratteristiche di visualizzazione. 

## Roadstart

Dopo questa fase iniziale sarà possibile valutare nuovi strumenti e servizi per ottimizzare la lavorazione. Inoltre, verrà creato un indicatore di stress per adeguare le soglie di incidenza covid ai risultati delle campagne vaccinali regionali. L’indice finale riuscirà a combinare congiuntamente l’effetto dei vaccini e dell’aumento dei contagi tenendo conto della popolazione suscettibile. Il progetto consisterà nel produrre un codice per il calcolo dell’indicatore (rilasciato in open source) e un’estensiva documentazione per il riutilizzo. Il nuovo indicatore verrà affiancato al monitoraggio degli indicatori fondamentali per stabilire il passaggio tra i colori delle regioni: incidenza settimanale, tasso di saturazione dei posti letto covid e terapie intensive.

<!--chapter:end:03-indicatori.Rmd-->

# Flusso Dati

In questa fase l’obiettivo è creare una **pipeline strutturata**, **automatizzata** e **ottimizzata** per garantire continuità su tutte le fasi di caricamento, pulizia e manipolazione dei dati attraverso servizi in cloud di flow automation e di software statistici. 

Gli strumenti software che DN utilizza sono ispirati a criteri di Open Source e Open Data, in tal modo tutta la stack di tecnologie in essere è riproducibile e manutenibile a costo zero (o quasi).

Software:

- R statistical language
  - {Tidyerse} [@tidyverse]
  - bookdown [@bookdown2016]
  - Rmarkdown
  - 




## Example one

## Example two

<!--chapter:end:04-etlpipeline.Rmd-->

# Final Words

We have finished a nice book.

<!--chapter:end:05-apis.Rmd-->


# References {-}


<!--chapter:end:06-visualization.Rmd-->


# References {-}


<!--chapter:end:07-references.Rmd-->


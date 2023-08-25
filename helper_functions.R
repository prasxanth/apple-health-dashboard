pacman::p_load(tidyverse)

reformat_date <- function(date, new_format = "%B %d, %Y") {
  date %>% as.Date() %>% format(new_format)
}

interval_lookup <- function(interval) {
  case_when(
    interval == "6 hours" ~ "6H",
    interval == "1 day" ~ "1D",
    interval == "1 week" ~ "1W",
    interval == "1 month" ~ "1M",
    interval == "1 year" ~ "1Y"
  )
}
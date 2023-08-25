pacman::p_load(tidyverse, jsonlite)
library(tidyverse)

# Function to create summary file path
create_summary_file_path <-
  function(data_wrangler_file_path, summary_folder) {
    basename(data_wrangler_file_path) %>%
      tools::file_path_sans_ext() %>%
      file.path(summary_folder, .) %>%
      paste0("-summary.csv")
  }

create_parameters_lookup_table <- function(config_path) {
  read_json(config_path) %>%
    .$parameters %>%
    map_df(function(param) {
      tibble(
        file_path = param$data_wrangler$file_path,
        measures = list(param$type_summary$measures)
      )
    })
}

select_normalized_measure <- function(measures) {
  case_when(
    "sum" %in% measures ~ "normalized_sum",
    "mean" %in% measures ~ "normalized_mean",
    TRUE ~ paste0("normalized_", measures[[1]])
  )
}

process_summary_row <- function(file_path, measures) {
  read_csv(file_path, col_types = cols(start_date = col_datetime())) %>%
    select(start_date,
           type,
           interval,!!select_normalized_measure(measures)) %>%
    rename_with(~ "value", starts_with("normalized_"))
}

filter_summaries <-
  function(summary_data,
           interval = "6H",
           start_date = NULL,
           end_date = NULL,
           exclude_params = NULL) {
    filtered_data <- summary_data %>%
      filter(interval == !!interval) %>%
      select(start_date, type, value)
    
    if (!is.null(start_date) & is.null(end_date)) {
      filtered_data <- filtered_data %>%
        filter(start_date >= !!start_date)
    } else if (!is.null(start_date) & !is.null(end_date)) {
      filtered_data <- filtered_data %>%
        filter(between(start_date, !!start_date, !!end_date))
    } else {
      filtered_data
    }
    
    if (!is.null(exclude_params)) {
      exclude_pattern <- paste(exclude_params, collapse = "|")
      filtered_data <- filtered_data %>%
        filter(!grepl(exclude_pattern, type))
    }
    
    return(filtered_data)
  }

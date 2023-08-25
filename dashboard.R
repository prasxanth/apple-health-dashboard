pacman::p_load(ggplot2,
               shiny,
               bslib,
               bsicons,
               flexdashboard,
               tidyverse,
               ggplot2,
               ggdark,
               viridis)

# Load functions from external scripts
source("data_processing.R")
source("ui_functions.R")
source("helper_functions.R")

apple_health_data_folder <-
  jsonlite::read_json("config.json")$apple_health_data_folder

config_path <- file.path(apple_health_data_folder, "apple_health_data", "config.json")
config <- config_path %>% jsonlite::read_json()

data_folder <-
  config$folders$contents[[2]]$name %>%
  {
    file.path(apple_health_data_folder, .)
  }

export_date <-
  list.dirs(data_folder, recursive = FALSE) %>%
  basename %>%
  as.Date() %>%
  sort(decreasing = TRUE) %>%
  first() %>%
  as.character()

summary_folder <-
  config$folders$contents[[2]]$contents[[1]]$contents[[4]]$name %>%
  {
    file.path(data_folder, export_date, .)
  }

default_end_date <-
  export_date %>% as.Date() %>% floor_date(unit = "month")
default_start_date <-
  default_end_date %>% magrittr::subtract(months(3))
default_exclude_params <- c(
  "BodyFatPercentage",
  "BodyMass",
  "BodyMassIndex",
  "HeartRateVariabilitySDNN",
  "HeadphoneAudioExposure",
  "SixMinuteWalkTestDistance"
)


ui <- page_sidebar(
  title = "Apple Health Dashboard",
  theme = bs_theme(
    bootswatch = "darkly",
    base_font = font_google("Inter"),
    navbar_bg = "#25443B"
  ),
  sidebar = sidebar(
    title = "Controls",
    dateInput("start_date", "Start Date", value = default_start_date),
    dateInput("end_date", "End Date", value = default_end_date),
    selectInput(
      "interval",
      "Interval",
      choices = c("6 hours", "1 day", "1 week", "1 month", "1 year"),
      selected = "1 day"
    ),
    selectInput(
      "exclude_params",
      "Exclude Parameters",
      choices = default_exclude_params,
      multiple = TRUE
    ),
    actionButton("update_button", "Update Plot")
  ),
  layout_columns(
    fill = FALSE,
    value_box(
      title = "Data export date",
      value = textOutput("export_date_value"),
      showcase = bsicons::bs_icon("calendar"),
      theme_color = "dark",
    ),
    value_box(
      title = textOutput("bio_title"),
      value = textOutput("bio_value"),
      showcase = bsicons::bs_icon("person"),
      theme_color = "secondary",
      p(htmlOutput("bio_dob")),
      p(htmlOutput("bio_gender"))
    ),
    value_box(
      title = "Body Mass",
      value = textOutput("body_mass_value"),
      showcase = bsicons::bs_icon("clipboard2-heart-fill"),
      p(textOutput("body_mass_percent")),
    ),
    value_box(
      title = "Body Mass Index (BMI)",
      value = textOutput("body_mass_index_value"),
      showcase = bsicons::bs_icon("activity"),
      p(textOutput("body_mass_index_percent"))
    )
  ),
  card(
    card_header("Heatmap of Normalized Measures"),
    full_screen = TRUE,
    plotlyOutput("heatmap_plot")
  )
)

server <- function(input, output, session) {
  output$export_date_value <- renderText({
    reformat_date(export_date)
  })
  
  biodata_path <- file.path(summary_folder, "biodata.json")
  render_biodata(output,
                 biodata_path,
                 "bio_title",
                 "bio_value",
                 "bio_dob",
                 "bio_gender")
  
  data_reactive <- reactive({
    params_summary_df <- create_parameters_lookup_table(config_path) %>%
      mutate(file_path = map_chr(file_path,
                                 function(x)
                                   create_summary_file_path(x, summary_folder)))
    
    data_df <-
      pmap(params_summary_df, process_summary_row) %>% bind_rows()
    
    return(data_df)
  })
  
  observe({
    start_dates <- data_reactive() %>%
      distinct(start_date) %>%
      pull(start_date)
    
    updateDateInput(
      session,
      inputId = "start_date",
      label = "Start Date",
      value = default_start_date,
      min = min(start_dates),
      max = export_date
    )
    
    updateDateInput(
      session,
      inputId = "end_date",
      label = "End Date",
      value = default_end_date,
      min = min(start_dates),
      max = export_date
    )
    
    updateSelectInput(
      session,
      inputId = "exclude_params",
      label = "Exclude Parameters",
      choices = unique(data_reactive()$type),
      selected = default_exclude_params
    )
  })
  
  interval <- reactive({
    interval_lookup(input$interval)
  })
  
  start_date <- reactive({
    as.POSIXct(input$start_date)
  })
  
  end_date <- reactive({
    as.POSIXct(input$end_date)
  })
  
  exclude_params <- reactive({
    input$exclude_params
  })
  
  default_exclude_params <- c(
    "BodyFatPercentage",
    "BodyMass",
    "BodyMassIndex",
    "HeartRateVariabilitySDNN",
    "HeadphoneAudioExposure",
    "SixMinuteWalkTestDistance"
  )
  
  filtered_exclude_params <- reactive({
    if (is.null(exclude_params())) {
      default_exclude_params
    } else {
      exclude_params()
    }
  })
  
  
  plot_data_reactive <- eventReactive(c(input$update_button, 0), {
    update_info_value_box(
      output,
      "body_mass",
      value_units = "lb",
      param_file = file.path(summary_folder, "body-mass-summary.csv"),
      interval = interval(),
      start_date = start_date(),
      end_date = end_date()
    )
    
    update_info_value_box(
      output,
      "body_mass_index",
      param_file = file.path(summary_folder, "body-mass-index-summary.csv"),
      interval = interval(),
      start_date = start_date(),
      end_date = end_date()
    )
    
    plot_data <- filter_summaries(
      data_reactive(),
      interval = interval(),
      start_date = start_date(),
      end_date = end_date(),
      exclude_params = filtered_exclude_params()
    )
    
    plot_data
  })
  
  output$heatmap_plot <-
    renderPlotly(create_plotly_heatmap(plot_data_reactive()))
}

shinyApp(ui, server)

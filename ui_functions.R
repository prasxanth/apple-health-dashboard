pacman::p_load(tidyverse, ggplot2, plotly)

update_info_value_box <-
  function(output,
           prefix_name,
           value_units = NULL,
           param_file,
           interval,
           start_date,
           end_date) {
    parameter <-
      read_csv(param_file, col_types = cols(start_date = col_datetime())) %>%
      filter(interval == !!interval) %>%
      filter(between(start_date,!!start_date,!!end_date))
    
    param_median <- parameter %>% pull(median) %>% mean %>% round(2)
    param_percent <- parameter %>%
      pull(normalization) %>%
      first() %>%
      {
        round(param_median / . * 100, 2)
      }
    
    if (!is.null(value_units)) {
      value <- paste(param_median, value_units)
    } else {
      value <- param_median
    }
    
    output[[paste0(prefix_name, "_value")]] <- renderText({
      value
    })
    
    output[[paste0(prefix_name, "_percent")]] <- renderText({
      paste0(param_percent, "% of recommended")
    })
  }

render_biodata <-
  function(output,
           biodata_path,
           bio_title_output,
           bio_value_output,
           bio_dob_output,
           bio_gender_output) {
    biodata <- jsonlite::read_json(biodata_path)
    
    output[[bio_title_output]] <- renderText({
      biodata$name
    })
    
    output[[bio_value_output]] <- renderText({
      paste0(biodata$age$years,
             "y ",
             biodata$age$months,
             "m ",
             biodata$age$days,
             "d")
    })
    
    output[[bio_dob_output]] <- renderUI({
      HTML(paste(bs_icon("balloon"), " DOB:", reformat_date(biodata$dob)))
    })
    
    output[[bio_gender_output]] <- renderUI({
      HTML(paste(
        bs_icon("gender-ambiguous"),
        " Gender:",
        tools::toTitleCase(biodata$gender)
      ))
    })
  }

create_ggplot_heatmap <- function(data) {
  ggplot(data, aes(x = start_date, y = type, fill = value)) +
    geom_tile() +
    scale_y_discrete() +
    scale_x_datetime(labels = scales::date_format("%Y-%m-%d"),
                     expand = c(0, 0)) +
    labs(x = "Date and Time", y = "Parameter") +
    dark_theme_gray() +
    theme(
      text = element_text(family = "Roboto"),
      axis.text.x = element_text(size = 18, hjust = 1),
      axis.text.y = element_text(size = 18),
      axis.title = element_text(size = 24),
      axis.title.x = element_text(margin = margin(
        t = 20,
        r = 0,
        b = 0,
        l = 0
      )),
      legend.title = element_text(size = 20),
      legend.text = element_text(size = 16),
    ) +
    scale_fill_viridis("Normalized\nMeasure", option = "turbo")
}

create_plotly_heatmap <- function(data) {
  plot_ly(
    data = data,
    x = ~ start_date,
    y = ~ type,
    z = ~ value,
    type = "heatmap",
    colorscale = "Portland"
  ) %>%
    layout(
      xaxis = list(
        title = list(text = "Date and Time", standoff = 10),
        tickfont = list(
          family = "Helvetica",
          size = 18,
          color = "white"
        ),
        titlefont = list(
          family = "Helvetica",
          size = 24,
          color = "white"
        )
      ),
      yaxis = list(
        title = list(text = "Parameter", standoff = 20),
        tickfont = list(
          family = "Helvetica",
          size = 18,
          color = "white"
        ),
        titlefont = list(
          family = "Helvetica",
          size = 24,
          color = "white"
        ),
        title_standoff = 50
      ),
      legend = list(
        font = list(
          family = "Helvetica",
          size = 16,
          color = "white"
        ),
        titlefont = list(
          family = "Helvetica",
          size = 20,
          color = "white"
        )
      ),
      font = list(family = "Helvetica", color = "white"),
      paper_bgcolor = "black",
      plot_bgcolor = "black",
      margin = list(
        t = 50,
        r = 50,
        b = 50,
        l = 50
      )
    ) %>%
    colorbar(
      title = "Normalized\nMeasure",
      len = 0.3,
      tickfont = list(size = 16, color = "white")
    )
}

# ---------------------------------------------------------------------------
# Figure 2 | Every country worsening on all three outcomes above an
#            exploratory mental/neurological spending reference.
#
# Method, in order:
#   1. Read modelled 2019 combined mental and neurological spending per person
#      for all 204 published locations (Mitchell et al. 2025, Table S7).
#   2. Extract the outcome rates from their original source files: WHO
#      age-standardized death rates (stroke, suicide) and IHME/GBD dementia
#      incidence via OWID.
#   3. Classify each country-outcome by its 2023-minus-2019 endpoint change.
#   4. Keep every country above the spending reference that worsened on all
#      three outcomes. This is a complete set, not a sample.
#   5. Draw indexed trends (a-c) over absolute rates (d-f) and export.
#
# Run: Rscript code/make_figure2.R   (or source() it from the package folder)
# ---------------------------------------------------------------------------

CODE <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) dirname(normalizePath(sub("^--file=", "", a[1])))
  else c("code", "../code")[file.exists(file.path(c("code", "../code"), "shared.R"))][1]
})
source(file.path(CODE, "shared.R")); init(CODE)
suppressPackageStartupMessages(library(readxl))

## 1. Spending ---------------------------------------------------------------

# All 204 published locations, including territories and all income groups.
# The source's own low/middle-income eligibility flags are deliberately unused.
spending <- read_csv(input("spending_all_204.csv"), show_col_types = FALSE) |>
  select(iso3, country = location, source_income_group_2019 = income_group_2019,
         gbd_super_region,
         spending_2019_pc_2021_usd = spending_per_capita_2021_usd,
         spending_lower = spending_per_capita_2021_usd_lower,
         spending_upper = spending_per_capita_2021_usd_upper,
         source_table, source_pdf_pages, source_rows) |>
  mutate(above_reference = spending_2019_pc_2021_usd > FIGURE2_REFERENCE_USD,
         interval_entirely_above = spending_lower > FIGURE2_REFERENCE_USD,
         spending_interval_crosses_reference = spending_lower <= FIGURE2_REFERENCE_USD &
           spending_upper > FIGURE2_REFERENCE_USD)
stopifnot(nrow(spending) == 204, !anyDuplicated(spending$iso3),
          all(spending$spending_lower <= spending$spending_2019_pc_2021_usd),
          all(spending$spending_upper >= spending$spending_2019_pc_2021_usd))

## 2. Outcomes from their original source files ------------------------------

# Both-sex, provider-standardized WHO rates: cause 1140 is stroke, 1610 is
# suicide. Row 8 of each sheet holds ISO3 codes, row 9 the data quality tier.
mortality <- bind_rows(lapply(YEARS, function(year) {
  sheet <- paste("ASDR", year)
  x <- read_excel(input("who_death_rates_asr.xlsx"), sheet = sheet, range = "A1:GR230",
                  col_names = FALSE, col_types = "text", .name_repair = "minimal")
  codes <- as.character(unlist(x[8, ], use.names = FALSE))
  cols <- which(grepl("^[A-Z]{3}$", codes))
  stopifnot(length(cols) == 185)
  bind_rows(lapply(c(stroke_mortality_asr = 1140, suicide_mortality_asr = 1610), function(cause) {
    row <- which(x[[1]] == "Persons" & x[[2]] == as.character(cause))
    stopifnot(length(row) == 1)
    tibble(iso3 = codes[cols], year = year,
           value = as.numeric(unlist(x[row, cols], use.names = FALSE)),
           source_sheet = sheet, source_excel_row = row, source_cause = cause,
           source_quality_category = as.character(unlist(x[9, cols], use.names = FALSE)))
  }), .id = "metric")
}))
write_data(mortality, "figure2_source_mortality_extraction.csv")

raw <- fromJSON(input("dementia_incidence_asr.data.json"))
entities <- fromJSON(input("dementia_incidence_asr.metadata.json"))$dimensions$entities$values
dementia <- tibble(entity_id = raw$entities, year = raw$years, value = raw$values) |>
  left_join(entities |> transmute(entity_id = id, iso3 = code), by = "entity_id") |>
  filter(year %in% YEARS, iso3 %in% spending$iso3) |>
  transmute(iso3, year, metric = "dementia_incidence_asr", value)

measured <- bind_rows(mortality |> select(iso3, year, metric, value), dementia)
stopifnot(!anyDuplicated(measured[c("iso3", "year", "metric")]))
panel <- expand_grid(iso3 = spending$iso3, year = YEARS, metric = FIGURE2_METRICS) |>
  left_join(measured, by = c("iso3", "year", "metric")) |>
  left_join(spending, by = "iso3")
stopifnot(nrow(panel) == 204 * length(YEARS) * 3,
          all(panel$value[!is.na(panel$value)] >= 0))

## 3. Endpoint changes -------------------------------------------------------

# A positive absolute change counts as worsening, including a rise from zero.
# Percentage change and the 2019-indexed series stay undefined at a zero
# baseline, so such countries appear in counts but not in the plotted trends.
changes <- panel |> filter(year == START_YEAR) |> rename(start_rate = value) |> select(-year) |>
  left_join(panel |> filter(year == END_YEAR) |> select(iso3, metric, end_rate = value),
            by = c("iso3", "metric")) |>
  mutate(absolute_change = end_rate - start_rate,
         percent_change = if_else(start_rate > 0, 100 * (end_rate / start_rate - 1), NA_real_),
         direction = case_when(is.na(absolute_change) ~ "Unavailable",
                               absolute_change > 1e-10 ~ "Worsening",
                               absolute_change < -1e-10 ~ "Improving", TRUE ~ "Unchanged"),
         increase_from_zero = !is.na(start_rate) & start_rate == 0 & end_rate > 0)
annual <- panel |> arrange(iso3, metric, year) |> group_by(iso3, metric) |>
  summarise(annual_values = sum(!is.na(value)),
            annual_increases = sum(diff(value) > 0, na.rm = TRUE), .groups = "drop")
changes <- changes |> left_join(annual, by = c("iso3", "metric"))
panel <- panel |>
  left_join(changes |> select(iso3, metric, start_rate, direction, percent_change, annual_values),
            by = c("iso3", "metric")) |>
  mutate(rate_relative_to_2019 = if_else(start_rate > 0, 100 * value / start_rate, NA_real_))

## 4. The countries shown ----------------------------------------------------

review <- changes |>
  select(iso3, metric, start_rate, end_rate, absolute_change, percent_change, direction) |>
  pivot_wider(names_from = metric,
              values_from = c(start_rate, end_rate, absolute_change, percent_change, direction)) |>
  left_join(changes |> group_by(iso3) |>
              summarise(available_outcomes = sum(direction != "Unavailable"),
                        worsening_outcomes = sum(direction == "Worsening"), .groups = "drop"),
            by = "iso3") |>
  left_join(spending, by = "iso3") |>
  mutate(any_worsening = above_reference & worsening_outcomes > 0,
         all_three_worsening = above_reference & available_outcomes == 3 & worsening_outcomes == 3)
joint <- review |> filter(all_three_worsening) |> arrange(country)
stopifnot(nrow(joint) >= 1, nrow(joint) <= MAX_COUNTRIES)

summary <- changes |> filter(above_reference) |> group_by(metric) |>
  summarise(above_reference = n(), available = sum(direction != "Unavailable"),
            worsening = sum(direction == "Worsening"), improving = sum(direction == "Improving"),
            unchanged = sum(direction == "Unchanged"), missing = sum(direction == "Unavailable"),
            worsening_from_zero = sum(increase_from_zero, na.rm = TRUE),
            worsening_at_least_5pct = sum(percent_change >= 5, na.rm = TRUE), .groups = "drop")

plot_data <- panel |> filter(iso3 %in% joint$iso3)
write_data(spending, "figure2_spending_audit.csv")
write_data(panel, "figure2_outcome_panel.csv")
write_data(changes, "figure2_country_changes.csv")
write_data(review, "figure2_country_review.csv")
write_data(joint, "figure2_all_three_worsening.csv")
write_data(summary, "figure2_outcome_summary.csv")
write_data(plot_data, "figure2_plot_data.csv")

# Sensitivity: alternative spending cutoffs, the spending lower bound, and a
# stricter requirement of at least a 5% outcome rise.
sensitivity <- bind_rows(lapply(FIGURE2_SENSITIVITY_CUTS, function(cut) {
  changes |> filter(spending_2019_pc_2021_usd > cut) |> group_by(metric) |>
    summarise(threshold = cut, above = n(), available = sum(direction != "Unavailable"),
              worsening = sum(direction == "Worsening"),
              worsening_lower_spend_bound_above = sum(direction == "Worsening" & spending_lower > cut),
              worsening_at_least_5pct = sum(percent_change >= 5, na.rm = TRUE), .groups = "drop")
}))
write_data(sensitivity, "figure2_threshold_sensitivity.csv")

## 5. Panels -----------------------------------------------------------------

colours <- setNames(PALETTE[seq_len(nrow(joint))], joint$iso3)
shapes  <- setNames(SHAPES[seq_len(nrow(joint))], joint$iso3)
labels  <- setNames(paste0(joint$country, " ($",
                           formatC(joint$spending_2019_pc_2021_usd, digits = 1, format = "f"),
                           "/person)"), joint$iso3)

panel_plot <- function(i, absolute) {
  m <- FIGURE2_METRICS[i]
  trend_panel(
    data = plot_data |> filter(metric == m),
    y_var = if (absolute) "value" else "rate_relative_to_2019",
    group_var = "iso3", colours = colours, shapes = shapes, labels = labels,
    title = LABELS[[m]], tag = letters[i + if (absolute) 3L else 0L],
    y_label = if (absolute) RATE_LABELS[[m]] else paste0("Rate relative to ", START_YEAR, "\n(", START_YEAR, " = 100)"),
    reference_line = !absolute, from_zero = absolute)
}
panels <- c(lapply(seq_along(FIGURE2_METRICS), panel_plot, absolute = FALSE),
            lapply(seq_along(FIGURE2_METRICS), panel_plot, absolute = TRUE))

figure <- assemble(panels, height_mm = FIGURE2_HEIGHT_MM, legend_height_mm = 24)
export_figure(figure, "figure2_all_three_worsening", FIGURE2_HEIGHT_MM)
saveRDS(list(panels = panels, figure = figure), file.path(DATA, "figure2_editable_plots.rds"))

## 6. Validation -------------------------------------------------------------

write_validation(list(
  status = "passed",
  source_locations = nrow(spending),
  reference_usd = FIGURE2_REFERENCE_USD,
  above_reference = sum(spending$above_reference),
  at_exactly_reference = sum(spending$spending_2019_pc_2021_usd == FIGURE2_REFERENCE_USD),
  below_reference = sum(!spending$above_reference),
  any_worsening = sum(review$any_worsening),
  all_three_worsening = nrow(joint),
  one_or_more_outcomes_missing_above = sum(review$above_reference & review$available_outcomes < 3),
  all_three_worsening_lower_spend_bound_above = sum(joint$spending_lower > FIGURE2_REFERENCE_USD),
  outcome_summary = summary
), "figure2_validation.json")
record_session()

print(summary)
print(joint |> select(country, source_income_group_2019, spending_2019_pc_2021_usd))
cat("Any worsening:", sum(review$any_worsening), "| All three:", nrow(joint), "\n")
cat("Figure 2 written to", FIG, "\n")

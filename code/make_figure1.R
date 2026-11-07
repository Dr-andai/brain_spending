# ---------------------------------------------------------------------------
# Figure 1 | Illustrative countries spending above 10% of GDP on health.
#
# Method, in order:
#   1. Take the staged roster of countries above 10% of GDP in 2023.
#   2. Keep only countries with all five annual values for all three outcomes.
#   3. Index every outcome to 2019 = 100.
#   4. Pick one country per World Bank region, nearest that region's median
#      spending/GDP. Selection never looks at outcome direction.
#   5. Draw indexed trends (a-c) over absolute rates (d-f) and export.
#
# Run: Rscript code/make_figure1.R   (or source() it from the package folder)
# ---------------------------------------------------------------------------

CODE <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) dirname(normalizePath(sub("^--file=", "", a[1])))
  else c("code", "../code")[file.exists(file.path(c("code", "../code"), "shared.R"))][1]
})
source(file.path(CODE, "shared.R")); init(CODE)

## 1. Spending roster --------------------------------------------------------

# Fixed to total current health expenditure >10% of GDP in 2023 (WHO GHED via
# World Bank SH.XPD.CHEX.GD.ZS). A different threshold needs a new roster.
roster <- read_csv(input("countries_above_10pct.csv"), show_col_types = FALSE) |>
  select(iso3, country, region, total_health_pct_gdp_2023) |>
  mutate(region = trimws(region))
stopifnot(!anyDuplicated(roster$iso3),
          all(roster$total_health_pct_gdp_2023 > FIGURE1_GDP_THRESHOLD))

outcome_source <- read_csv(input("outcome_panel_with_income.csv"), show_col_types = FALSE)
income_lookup <- outcome_source |> distinct(iso3, income_group)
stopifnot(!anyDuplicated(income_lookup$iso3))
roster <- roster |> left_join(income_lookup, by = "iso3")
outcomes <- outcome_source |> select(iso3, metric, year, value)
stopifnot(!anyDuplicated(outcomes[c("iso3", "metric", "year")]))

## 2. Coverage and indexing --------------------------------------------------

# An explicit expected grid exposes missing countries and years instead of
# silently dropping them.
expected <- expand_grid(iso3 = roster$iso3, metric = METRICS, year = YEARS) |>
  left_join(outcomes, by = c("iso3", "metric", "year"))
coverage <- expected |>
  group_by(iso3) |>
  summarise(expected_values = n(), available_values = sum(is.finite(value)),
            complete_three_outcomes = all(is.finite(value)), .groups = "drop") |>
  left_join(roster, by = "iso3")
eligible <- coverage |> filter(complete_three_outcomes)

rates <- expected |>
  semi_join(eligible, by = "iso3") |>
  left_join(roster, by = "iso3") |>
  group_by(iso3, metric) |>
  mutate(baseline_rate = value[year == START_YEAR],
         outcome_index = 100 * value / baseline_rate) |>
  ungroup()
stopifnot(all(rates$baseline_rate > 0), all(is.finite(rates$outcome_index)),
          all(abs(rates$outcome_index[rates$year == START_YEAR] - 100) < 1e-10))

## 3. Sample selection -------------------------------------------------------

selection_audit <- eligible |>
  group_by(region) |>
  mutate(regional_median_spending = median(total_health_pct_gdp_2023),
         distance_from_median = abs(total_health_pct_gdp_2023 - regional_median_spending),
         tie_distance = round(distance_from_median, 10)) |>
  arrange(tie_distance, iso3, .by_group = TRUE) |>
  mutate(selection_rank = row_number()) |>
  ungroup()

if (is.null(FIGURE1_SAMPLE_ISO3)) {
  selected <- selection_audit |> filter(selection_rank == 1)
  selection_rule <- paste("One country per region nearest the regional median 2023 total",
                          "health spending/GDP; ties by ISO3.")
  if (!all(FIGURE1_REQUIRED_INCOME_GROUPS %in% selected$income_group)) {
    stop("Default selection no longer covers all four income groups. Set FIGURE1_SAMPLE_ISO3 in config.R.")
  }
} else {
  if (anyDuplicated(FIGURE1_SAMPLE_ISO3) || !all(FIGURE1_SAMPLE_ISO3 %in% eligible$iso3)) {
    stop("FIGURE1_SAMPLE_ISO3 must be unique ISO3 codes with complete data; see data/figure1_coverage_audit.csv.")
  }
  if (length(FIGURE1_SAMPLE_ISO3) > MAX_COUNTRIES) {
    stop("Keep FIGURE1_SAMPLE_ISO3 to ", MAX_COUNTRIES, " countries or fewer for a readable comparison.")
  }
  selected <- selection_audit |> filter(iso3 %in% FIGURE1_SAMPLE_ISO3)
  selection_rule <- "User-configured ISO3 sample; see code/config.R."
}
selected <- selected |> arrange(match(region, REGION_ORDER), country)
selection_audit <- selection_audit |> mutate(selected = iso3 %in% selected$iso3)
sample_rates <- rates |> semi_join(selected, by = "iso3")

write_data(coverage, "figure1_coverage_audit.csv")
write_data(rates, "figure1_country_rates_and_indices.csv")
write_data(selection_audit, "figure1_selection_audit.csv")
write_data(selected, "figure1_sample_countries.csv")
write_data(sample_rates, "figure1_sample_plot_data.csv")

## 4. Panels -----------------------------------------------------------------

# With one country per region the country colours follow their region's colour.
# A user-supplied sample with repeated regions falls back to the flat palette.
if (!anyDuplicated(selected$region)) {
  colours <- setNames(REGION_COLOURS[selected$region], selected$iso3)
  shapes  <- setNames(REGION_SHAPES[selected$region], selected$iso3)
} else {
  colours <- setNames(PALETTE[seq_len(nrow(selected))], selected$iso3)
  shapes  <- setNames(SHAPES[seq_len(nrow(selected))], selected$iso3)
}
income_short <- c("Low income" = "LIC", "Lower middle income" = "LMIC",
                  "Upper middle income" = "UMIC", "High income" = "HIC")
labels <- setNames(
  paste0(selected$country, " (", income_short[selected$income_group], "; ",
         formatC(selected$total_health_pct_gdp_2023, digits = 2, format = "f"), "% GDP)"),
  selected$iso3)

# Figure 1 keeps slightly wider axis-title margins and longer ticks than the
# other three figures, as published.
style <- list(axis.title.x = element_text(margin = margin(t = 4)),
              axis.title.y = element_text(margin = margin(r = 4)),
              axis.ticks.length = unit(1.1, "mm"),
              legend.key.height = unit(3.5, "mm"),
              legend.box.margin = margin(0, 0, 0, 0),
              plot.margin = margin(5, 5, 4, 4))

panel <- function(i, absolute) {
  m <- METRICS[i]
  do.call(trend_panel, c(list(
    data = sample_rates |> filter(metric == m),
    y_var = if (absolute) "value" else "outcome_index",
    group_var = "iso3", colours = colours, shapes = shapes, labels = labels,
    title = LABELS[[m]], tag = letters[i + if (absolute) 3L else 0L],
    y_label = if (absolute) RATE_LABELS[[m]] else paste0("Outcome index (", START_YEAR, " = 100)"),
    reference_line = !absolute, from_zero = absolute), style))
}
panels <- c(lapply(seq_along(METRICS), panel, absolute = FALSE),
            lapply(seq_along(METRICS), panel, absolute = TRUE))

figure <- assemble(panels, height_mm = FIGURE1_HEIGHT_MM, legend_height_mm = 18)
export_figure(figure, "figure1_sample_country_comparison", FIGURE1_HEIGHT_MM)
saveRDS(list(panels = panels, figure = figure), file.path(DATA, "figure1_editable_plots.rds"))

## 5. Validation -------------------------------------------------------------

# Reconcile the plotted 2023 indices against the independent endpoint changes
# carried in the staged roster.
prior <- read_csv(input("countries_above_10pct.csv"), show_col_types = FALSE)
discrepancies <- vapply(METRICS, function(m) {
  check <- rates |> filter(metric == m, year == END_YEAR) |>
    left_join(prior |> select(iso3, expected = all_of(paste0(m, "_change_pct_", START_YEAR, "_", END_YEAR))),
              by = "iso3")
  max(abs(check$outcome_index - 100 - check$expected))
}, numeric(1))
stopifnot(all(is.finite(discrepancies)), all(discrepancies < 1e-8))

write_validation(list(
  status = "passed",
  countries_above_threshold = nrow(roster),
  countries_with_all_three_outcomes = nrow(eligible),
  country_year_outcome_observations = nrow(rates),
  sample_size = nrow(selected),
  sample_countries = selected$country,
  sample_income_groups = sort(unique(selected$income_group)),
  selection_rule = selection_rule,
  max_endpoint_discrepancy = as.list(discrepancies)
), "figure1_validation.json")
record_session()

print(selected |> select(iso3, country, region, income_group, total_health_pct_gdp_2023))
cat("Figure 1 written to", FIG, "\n")

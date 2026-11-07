# ---------------------------------------------------------------------------
# Figure 3 | Brain health trajectories above and at/below $1,000 of total
#            health spending per person.
#
# Method, in order:
#   1. Read 2019-2023 total current health expenditure per person (WHO GHED via
#      World Bank SH.XPD.CHEX.PC.CD) and drop World Bank aggregates by joining
#      the country metadata, not by guessing from the ISO3 code.
#   2. Build a full country x outcome x year grid so missing data stays visible.
#   3. Split countries at $1,000 of 2023 spending, index each outcome to
#      2019 = 100, and summarise by spending group. No country is chosen by
#      outcome direction.
#   4. Panels a-c: median indices with membership held constant across years.
#      Panels d-f: share of countries whose 2023 rate is below their 2019 rate.
#   5. Repeat the whole calculation classified on 2019 spending as a
#      sensitivity, exported as data/sensitivity_baseline_*.
#
# Run: Rscript code/make_figure3.R   (or source() it from the package folder)
# ---------------------------------------------------------------------------

CODE <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) dirname(normalizePath(sub("^--file=", "", a[1])))
  else c("code", "../code")[file.exists(file.path(c("code", "../code"), "shared.R"))][1]
})
source(file.path(CODE, "shared.R")); init(CODE)

## 1. Spending and the country universe --------------------------------------

raw <- fromJSON(input("wb_current_health_per_capita.json"))
stopifnot(raw[[1]]$pages == 1)
wb <- fromJSON(input("wb_countries.json"))[[2]]
countries <- tibble(iso3 = wb$id, wb_country = wb$name, wb_region = wb$region$value) |>
  filter(wb_region != "Aggregates")
spend <- raw[[2]] |>
  transmute(iso3 = countryiso3code, year = as.integer(date),
            health_spending_pc_current_usd = value) |>
  inner_join(countries, by = "iso3")
stopifnot(!anyDuplicated(spend[c("iso3", "year")]))
write_data(spend, "health_spending_2019_2023.csv")

rates <- read_csv(input("outcome_rates.csv"), show_col_types = FALSE) |>
  filter(metric %in% METRICS, year %in% YEARS)
stopifnot(!anyDuplicated(rates[c("iso3", "metric", "year")]))

# An outer join keeps both the World Bank universe and the archived outcome
# locations, so neither source silently truncates the other.
roster <- full_join(countries, rates |> distinct(iso3, country, region), by = "iso3") |>
  mutate(country = coalesce(country, wb_country), region = coalesce(region, wb_region)) |>
  select(iso3, country, region)

## 2. One reusable build, run twice ------------------------------------------

# Classifying on a different year is the sensitivity analysis, so the whole
# calculation is a function of the classification year.
build <- function(classification_year) {
  spending <- spend |> filter(year == classification_year) |>
    select(iso3, health_spending_pc_current_usd)
  panel <- expand_grid(iso3 = roster$iso3, metric = METRICS, year = YEARS) |>
    left_join(rates |> select(iso3, metric, year, value), by = c("iso3", "metric", "year")) |>
    left_join(roster, by = "iso3") |> left_join(spending, by = "iso3") |>
    mutate(spending_year = classification_year, spending_group = case_when(
      is.na(health_spending_pc_current_usd) ~ NA_character_,
      health_spending_pc_current_usd > FIGURE3_THRESHOLD_USD ~ FIGURE3_GROUPS[2],
      TRUE ~ FIGURE3_GROUPS[1]))

  endpoints <- panel |> group_by(iso3, metric) |>
    summarise(start_rate = value[year == START_YEAR], end_rate = value[year == END_YEAR],
              observations = sum(is.finite(value)), .groups = "drop") |>
    mutate(absolute_change = end_rate - start_rate,
           percent_change = if_else(start_rate > 0, 100 * (end_rate / start_rate - 1), NA_real_),
           direction = case_when(is.na(absolute_change) ~ "Unavailable",
                                 absolute_change < -1e-10 ~ "Declining",
                                 absolute_change > 1e-10 ~ "Increasing", TRUE ~ "Unchanged"),
           # A zero 2019 rate leaves the index undefined, so such a country is
           # counted at the endpoints but excluded from the plotted trend.
           trend_eligible = observations == length(YEARS) & !is.na(start_rate) & start_rate > 0)
  panel <- panel |> left_join(endpoints, by = c("iso3", "metric")) |>
    mutate(index = if_else(start_rate > 0, 100 * value / start_rate, NA_real_))

  changes <- panel |> filter(year == START_YEAR) |> select(-year, -value, -index)
  summary <- changes |> filter(!is.na(spending_group)) |>
    group_by(spending_year, spending_group, metric) |>
    summarise(with_spending = n(), available = sum(direction != "Unavailable"),
              declining = sum(direction == "Declining"), increasing = sum(direction == "Increasing"),
              unchanged = sum(direction == "Unchanged"), missing = sum(direction == "Unavailable"),
              median_percent_change = median(percent_change, na.rm = TRUE),
              declined_at_least_5pct = sum(percent_change <= -5, na.rm = TRUE),
              trend_n = sum(trend_eligible), .groups = "drop") |>
    mutate(declining_share = 100 * declining / available)
  trend <- panel |> filter(!is.na(spending_group), trend_eligible) |>
    group_by(spending_group, metric, year) |>
    summarise(median_index = median(index), n = n_distinct(iso3), .groups = "drop")

  list(panel = panel, changes = changes, summary = summary, trend = trend)
}

main <- build(FIGURE3_SPENDING_YEAR)
baseline <- build(START_YEAR)

write_data(main$panel, "figure3_country_rates_and_indices.csv")
write_data(main$changes, "figure3_country_coverage_and_changes.csv")
write_data(main$summary, "figure3_summary.csv")
write_data(main$trend, "figure3_median_trends.csv")
write_data(baseline$summary, "sensitivity_baseline_spending_summary.csv")
write_data(baseline$changes, "sensitivity_baseline_country_changes.csv")
write_data(baseline$trend, "sensitivity_baseline_median_trends.csv")

# Membership must not drift between years, and the 2023 median index must
# equal 100 plus the median percentage change.
stopifnot(all((main$trend |> group_by(metric, spending_group) |>
  summarise(distinct_n = n_distinct(n), .groups = "drop"))$distinct_n == 1))
end_medians <- main$trend |> filter(year == END_YEAR) |>
  left_join(main$summary, by = c("metric", "spending_group"))
stopifnot(all(abs(end_medians$median_index - 100 - end_medians$median_percent_change) < 1e-8))

## 3. Panels -----------------------------------------------------------------

group_labels <- setNames(FIGURE3_GROUPS, FIGURE3_GROUPS)
dollars <- format(FIGURE3_THRESHOLD_USD, big.mark = ",", scientific = FALSE)

trend_panels <- lapply(seq_along(METRICS), function(i) {
  trend_panel(
    data = main$trend |> filter(metric == METRICS[i]),
    y_var = "median_index", group_var = "spending_group",
    colours = FIGURE3_COLOURS, shapes = FIGURE3_SHAPES, labels = group_labels,
    title = LABELS[[METRICS[i]]], tag = letters[i],
    y_label = paste0("Median rate relative to ", START_YEAR, "\n(", START_YEAR, " = 100)"),
    linewidth = .35, point_size = 1.3, expand_upper = .12,
    legend.key.width = unit(7, "mm"))
})

# Counts of declining countries, as a share of those with both endpoints.
count_panels <- lapply(seq_along(METRICS), function(i) {
  d <- main$summary |> filter(metric == METRICS[i]) |>
    mutate(group = factor(spending_group, levels = FIGURE3_GROUPS))
  ggplot(d, aes(group, declining_share, fill = spending_group)) +
    geom_col(width = .56) +
    geom_text(aes(label = paste0(declining, "/", available)), vjust = -.6,
              family = FONT, size = 6 / .pt) +
    scale_fill_manual(values = FIGURE3_COLOURS, breaks = FIGURE3_GROUPS) +
    scale_x_discrete(labels = setNames(paste0(c("≤ $", "> $"), dollars), FIGURE3_GROUPS)) +
    scale_y_continuous(limits = c(0, 110), breaks = c(0, 25, 50, 75, 100),
                       expand = expansion(mult = c(0, 0))) +
    labs(x = "Health spending per person", y = "Countries with declining rates (%)",
         title = LABELS[[METRICS[i]]], tag = letters[i + 3]) +
    theme_journal() + theme(legend.position = "none")
})

# The trend row is taller than the count row, as published.
figure <- assemble(c(trend_panels, count_panels), height_mm = FIGURE3_HEIGHT_MM,
                   legend_height_mm = 11, row_heights = c(1.2, 1), footer_height_mm = 0)
export_figure(figure, "figure3_health_spending_above_1000", FIGURE3_HEIGHT_MM)
saveRDS(list(panels = c(trend_panels, count_panels), figure = figure),
        file.path(DATA, "figure3_editable_plots.rds"))

## 4. Validation -------------------------------------------------------------

write_validation(list(
  status = "passed",
  threshold = FIGURE3_THRESHOLD_USD,
  spending_year = FIGURE3_SPENDING_YEAR,
  wb_data_last_updated = raw[[1]]$lastupdated,
  stable_trend_membership = TRUE,
  endpoint_medians_reconcile = TRUE,
  summary = main$summary
), "figure3_validation.json")
record_session()

print(main$summary, width = Inf)
cat("Figure 3 written to", FIG, "\n")

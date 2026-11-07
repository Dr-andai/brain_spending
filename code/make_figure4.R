# ---------------------------------------------------------------------------
# Figure 4 | Sample-country trajectories underlying Figure 3.
#
# Requires Figure 3: this script reads its exported cohort rather than
# recomputing it, so the two figures cannot drift apart.
#
# Method, in order:
#   1. Read Figure 3's country rates and coverage audit, and re-check that the
#      archived spending groups still match the configured threshold.
#   2. Keep countries with complete, positive-baseline data on all three
#      outcomes and a known spending group.
#   3. Pick one country per World Bank region, nearest that region's median
#      2023 spending per person. Selection never looks at outcome direction.
#   4. Draw indexed trends (a-c) over absolute rates (d-f). Line style marks
#      the spending group; the legend gives each country's 2023 spending.
#
# Run: Rscript code/make_figure4.R   (after make_figure3.R)
# ---------------------------------------------------------------------------

CODE <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) dirname(normalizePath(sub("^--file=", "", a[1])))
  else c("code", "../code")[file.exists(file.path(c("code", "../code"), "shared.R"))][1]
})
source(file.path(CODE, "shared.R")); init(CODE)

## 1. Figure 3's cohort ------------------------------------------------------

rates <- read_csv(file.path(DATA, "figure3_country_rates_and_indices.csv"), show_col_types = FALSE)
audit <- read_csv(file.path(DATA, "figure3_country_coverage_and_changes.csv"), show_col_types = FALSE)
stopifnot(setequal(unique(rates$year), YEARS),
          all(audit$spending_year == FIGURE3_SPENDING_YEAR))

# If the threshold or classification year changed, Figure 3 must be rebuilt
# first; this check fails loudly rather than mixing two configurations.
known <- audit |> filter(!is.na(spending_group))
stopifnot(all((known$health_spending_pc_current_usd > FIGURE3_THRESHOLD_USD) ==
                grepl("^Above", known$spending_group)))

## 2. Eligibility ------------------------------------------------------------

eligibility <- audit |> group_by(iso3) |>
  summarise(complete_three_outcomes = n() == 3 & all(trend_eligible),
            spending_available = all(!is.na(spending_group)), .groups = "drop")
roster <- audit |>
  distinct(iso3, country, region, spending_year, health_spending_pc_current_usd, spending_group) |>
  left_join(eligibility, by = "iso3")
wb <- fromJSON(input("wb_countries.json"))[[2]]
roster <- roster |>
  left_join(tibble(iso3 = wb$id, income_group = wb$incomeLevel$value), by = "iso3")
eligible <- roster |> filter(complete_three_outcomes, spending_available)

## 3. Sample selection -------------------------------------------------------

ranked <- eligible |> group_by(region) |>
  mutate(regional_median_spending = median(health_spending_pc_current_usd),
         region_eligible_n = n(),
         distance_from_regional_median =
           round(abs(health_spending_pc_current_usd - regional_median_spending), 10)) |>
  arrange(distance_from_regional_median, iso3, .by_group = TRUE) |>
  mutate(selection_rank = row_number()) |> ungroup()

if (is.null(FIGURE4_SAMPLE_ISO3)) {
  sample <- ranked |> filter(selection_rank == 1)
  selection_rule <- paste("Nearest regional median spending; ties by ISO3;",
                          "complete three-outcome cohort")
  stopifnot(!anyDuplicated(sample$region), setequal(sample$region, eligible$region))
} else {
  stopifnot(!anyDuplicated(FIGURE4_SAMPLE_ISO3), all(FIGURE4_SAMPLE_ISO3 %in% eligible$iso3))
  sample <- ranked |> filter(iso3 %in% FIGURE4_SAMPLE_ISO3)
  selection_rule <- "User-specified ISO3 sample; see code/config.R"
}
sample <- sample |> arrange(country)
stopifnot(nrow(sample) >= 2, nrow(sample) <= MAX_COUNTRIES,
          n_distinct(sample$spending_group) == 2)
ranked <- ranked |> mutate(selected = iso3 %in% sample$iso3)

plot_data <- rates |> filter(iso3 %in% sample$iso3)
stopifnot(nrow(plot_data) == nrow(sample) * length(YEARS) * length(METRICS),
          all(is.finite(plot_data$index)), all(is.finite(plot_data$value)))

write_data(roster, "figure4_coverage_audit.csv")
write_data(ranked, "figure4_selection_audit.csv")
write_data(sample, "figure4_sample_countries.csv")
write_data(plot_data, "figure4_sample_plot_data.csv")

## 4. Panels -----------------------------------------------------------------

colours <- setNames(PALETTE[SWAPPED][seq_len(nrow(sample))], sample$iso3)
shapes  <- setNames(SHAPES[SWAPPED][seq_len(nrow(sample))], sample$iso3)
# Line style carries the spending group, so the grouping survives greyscale.
linetypes <- setNames(
  ifelse(sample$health_spending_pc_current_usd > FIGURE3_THRESHOLD_USD, "solid", "22"),
  sample$iso3)
labels <- setNames(
  paste0(sample$country, " ($",
         formatC(sample$health_spending_pc_current_usd, format = "f", digits = 0, big.mark = ","),
         "/person)"), sample$iso3)

panel_plot <- function(i, absolute) {
  m <- METRICS[i]
  trend_panel(
    data = plot_data |> filter(metric == m),
    y_var = if (absolute) "value" else "index",
    group_var = "iso3", colours = colours, shapes = shapes, labels = labels,
    linetypes = linetypes,
    title = LABELS[[m]], tag = letters[i + if (absolute) 3L else 0L],
    y_label = if (absolute) RATE_LABELS[[m]] else paste0("Rate relative to ", START_YEAR, "\n(", START_YEAR, " = 100)"),
    reference_line = !absolute, from_zero = absolute, linewidth = .3,
    legend.key.width = unit(8, "mm"))
}
panels <- c(lapply(seq_along(METRICS), panel_plot, absolute = FALSE),
            lapply(seq_along(METRICS), panel_plot, absolute = TRUE))

dollars <- format(FIGURE3_THRESHOLD_USD, big.mark = ",")
figure <- assemble(
  panels, height_mm = FIGURE4_HEIGHT_MM, legend_height_mm = 22,
  footer = paste0(FIGURE3_SPENDING_YEAR, " total health spending: solid > $", dollars,
                  "; dashed ≤ $", dollars, " per person"),
  footer_height_mm = 5)
export_figure(figure, "figure4_sample_countries_by_spending", FIGURE4_HEIGHT_MM)
saveRDS(list(panels = panels, figure = figure), file.path(DATA, "figure4_editable_plots.rds"))

## 5. Validation -------------------------------------------------------------

write_validation(list(
  status = "passed",
  countries = nrow(sample),
  complete_country_year_outcomes = nrow(plot_data),
  above_threshold = sum(sample$health_spending_pc_current_usd > FIGURE3_THRESHOLD_USD),
  at_or_below_threshold = sum(sample$health_spending_pc_current_usd <= FIGURE3_THRESHOLD_USD),
  regions = unique(sample$region),
  income_groups = unique(sample$income_group),
  selection = selection_rule
), "figure4_validation.json")
record_session()

print(sample |> select(country, region, income_group, health_spending_pc_current_usd, spending_group),
      width = Inf)
cat("Figure 4 written to", FIG, "\n")

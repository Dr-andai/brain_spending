# final_expo

Four figures on brain health outcomes and health spending, with the data and R
scripts that produce them. Nothing is downloaded at build time.

Outcomes are suicide mortality, stroke mortality and dementia incidence,
2019–2023, age-standardized per 100,000. Every figure indexes each country's
annual rate to its own 2019 value (`100 × rate(year) / rate(2019)`) and shows
unweighted country-level medians or individual country lines. No country is
selected by whether its outcomes improved.

| Figure | Spending measure | Countries shown | Script |
|---|---|---|---|
| 1 | >10% of GDP, 2023 (World Bank/WHO GHED) | 6 illustrative, one per region | `code/make_figure1.R` |
| 2 | >$2.30/person mental & neurological, 2019 (Mitchell et al. Table S7) | all 7 worsening on all three outcomes | `code/make_figure2.R` |
| 3 | >$1,000/person total, 2023 (World Bank/WHO GHED) | all 191 with spending data, in two groups | `code/make_figure3.R` |
| 4 | same as Figure 3 | 7 illustrative, one per region | `code/make_figure4.R` |

## Layout

```
code/      config.R (all settings), shared.R (theme, panels, export), one script per figure
inputs/    the nine data files the scripts read
figures/   the four figures, vector PDF + 600 dpi PNG, 180 mm wide
data/      regenerated tables and audits — empty until you run the scripts
sources.csv  every input with its size, SHA-256 and origin
```

## Rebuilding

```sh
Rscript code/build_all.R      # all four figures
Rscript code/make_figure3.R   # or any single figure
```

Figure 4 reads Figure 3's exports from `data/`, so run Figure 3 first. The
other three are independent. `build_all.R` runs each script in its own R
process.

Packages: ggplot2, dplyr, tidyr, readr, readxl, jsonlite, ragg, gtable, scales.
PDFs use Quartz on macOS and Cairo elsewhere; Arial must be installed or
replaced in `code/config.R`. Edit `code/config.R` for thresholds, years, sample
countries, colours and dimensions.

## Data and sources

Six upstream sources. `sources.csv` gives the SHA-256, byte size and origin of
each of the nine files in `inputs/`; this section says where those files came
from originally.

### Outcomes

**Suicide and stroke mortality — WHO Global Health Estimates.**
`inputs/who_death_rates_asr.xlsx` is the WHO *Global Health Estimates 2023
Summary Tables: age-standardized death rates by cause* (WHO Department of Data
and Analytics; the workbook's own banner reads "GLOBAL HEALTH ESTIMATES 2023
SUMMARY TABLES, Sepetember 2026" — the typo is the source's). Figures read the
`ASDR` sheets for 2019–2023, sex row "Persons", and two cause codes: **1610
*Self-harm*** for suicide and **1140 *Stroke*** for stroke. Rates are
age-standardized to the **WHO World Standard Population**, whose weights are
printed in the workbook's `Notes` sheet.
<https://www.who.int/data/global-health-estimates>

**Dementia incidence — IHME Global Burden of Disease 2023, via Our World in
Data.** `inputs/dementia_incidence_asr.data.json` and its `.metadata.json` are
OWID grapher **variable 1181423**, age-standardized new cases of Alzheimer's
disease and other dementias per 100,000. GBD 2023 was published 2025-10-20; the
OWID dataset version is 2026-02-07, accessed 2026-02-07. Standardized to IHME's
own global reference age structure, **not** the WHO standard — so dementia
*levels* are not comparable with the two mortality series, only within-country
change over time.
<https://vizhub.healthdata.org/gbd-results/>

### Spending

**Mitchell et al. (2025), Supplementary Table S7 — Figure 2.**
`inputs/spending_all_204.csv` is a transcription of **Supplementary Table S7**
of Mitchell et al., *Lancet Public Health*, 2025,
doi:[10.1016/S2468-2667(25)00089-1](https://doi.org/10.1016/S2468-2667(25)00089-1),
taken from **pages 18–31** of the appendix PDF. Each row keeps its
`source_table`, `source_pdf_pages` and `source_rows` so any value can be traced
back to the page it was read from. It reports **modelled 2019 direct
expenditure on the combined mental *and neurological* condition group, in
constant 2021 US$ per person, all payers** — with published lower and upper
bounds, carried in the file as `spending_per_capita_2021_usd_lower/_upper`. It
is not observed government spending, not all-condition health spending, and not
an allocation to dementia, stroke or suicide. All 204 published locations are
retained; the table's own `eligible_income` and `inclusion_status` flags are
deliberately **not** used as filters. 16 ISO3 codes were assigned by hand where
the table's location names did not match a code directly (see `mapping_source`).
This is the source referred to elsewhere in the project simply as "Table 7".

**Total current health expenditure — WHO Global Health Expenditure Database
(GHED), via the World Bank.** Two different indicators from two different API
vintages of the same database:

| File | Indicator | API pull | `lastupdated` | Used by |
|---|---|---|---|---|
| `inputs/wb_current_health_per_capita.json` | `SH.XPD.CHEX.PC.CD`, current US$ per capita | `api.worldbank.org/v2/country/all/indicator/SH.XPD.CHEX.PC.CD?date=2019:2023` | 2026-10-08 | Figures 3–4 |
| (upstream of `inputs/countries_above_10pct.csv`) | `SH.XPD.CHEX.GD.ZS`, % of GDP | same endpoint, 2023 | 2026-07-13 | Figure 1 |

The underlying GHED release is dated 12 December 2025. Figure 1 and Figures 3–4
therefore do **not** share a spending vintage.
<http://apps.who.int/nha/database> ·
<https://data.worldbank.org/indicator/SH.XPD.CHEX.PC.CD>

**Regions and income groups.** `inputs/wb_countries.json` is
`api.worldbank.org/v2/country?format=json&per_page=400`, retrieved 15 October
2026. World Bank aggregates are excluded by joining this metadata, not by
guessing from ISO3 codes.

### Staged files

Two inputs are staged extracts rather than raw downloads, and the code that
produced them is not in this repository:

- `inputs/countries_above_10pct.csv` — the 28 locations above 10% of GDP in
  2023 from `SH.XPD.CHEX.GD.ZS`, with 2019–2023 endpoint changes already
  computed. `make_figure1.R` reconciles its own plotted 2023 indices against
  these independently computed changes.
- `inputs/outcome_panel_with_income.csv` — the outcome panel joined to World
  Bank income groups, archived from the Figure 1 source project.
- `inputs/outcome_rates.csv` is a column subset of Figure 2's own outcome panel
  and is reconstructible by re-running `make_figure2.R`.

### Suggested citation of sources

- Global Burden of Disease Collaborative Network. *Global Burden of Disease
  Study 2023 (GBD 2023).* Seattle: Institute for Health Metrics and Evaluation,
  2025 (via Our World in Data, variable 1181423, accessed 2026-02-07).
- World Health Organization. *Global Health Estimates 2023 Summary Tables:
  age-standardized death rates by cause.* Geneva: WHO, 2026.
- World Health Organization. *Global Health Expenditure Database*, release of
  12 December 2025, via World Bank World Development Indicators
  `SH.XPD.CHEX.PC.CD` and `SH.XPD.CHEX.GD.ZS`.
- Mitchell et al. *Lancet Public Health*, 2025, Supplementary Table S7.
  doi:10.1016/S2468-2667(25)00089-1

Nothing is imputed, interpolated or carried forward. Each script builds a full
country × outcome × year grid first, so missing values stay visible, and the
`data/figure*_coverage_audit.csv` tables keep every excluded row.

**Redistribution:** the OWID/GBD dementia variable is marked
`nonRedistributable` under IHME's Free-of-Charge Non-commercial User Agreement
(<https://www.healthdata.org/Data-tools-practices/data-practices/ihme-free-charge-non-commercial-user-agreement>).
Check that before publishing this repository with
`inputs/dementia_incidence_asr.data.json` in it.

## What the spending measures are, and are not

The three spending measures are **not comparable with one another** in scope,
reference year, units or price basis, and no figure should be described as using
"the" spending variable.

| | Figure 1 | Figures 3 and 4 | Figure 2 |
|---|---|---|---|
| Concept | total current health expenditure | total current health expenditure | modelled mental **and neurological** direct expenditure |
| Year | 2023 | 2023 | 2019 |
| Unit | % of GDP | US$ per person | US$ per person |
| Price basis | ratio, no deflator | current (nominal) US$ | constant 2021 US$ |
| Threshold | > 10% | > $1,000 | > $2.30 |

All three are strict inequalities on a single year's spending. None of them
measures expenditure on dementia, stroke or suicide specifically. A share of GDP
is not a per-person amount: Afghanistan is above 10% of GDP in Figure 1 and in
the at/below-$1,000 group in Figures 3 and 4.

## Known limitations

Every comparison here is descriptive. Nothing in this repository identifies a
causal effect of spending on outcomes.

- The 2019–2023 window contains the COVID-19 pandemic, and the spending groups
  differ systematically in income, health-system structure and measurement
  quality.
- The outcome extracts carry **no uncertainty intervals**, so no figure shows
  error bars and no significance test is performed or implied.
- WHO assigns each country a mortality data-quality tier of 1–4. The tier is not
  used as a filter or weight. It is very unevenly distributed between Figure 3's
  groups — 2% of the above-$1,000 group is tier 4 against 58% of the at/below
  group — and Figure 3's median comparisons change direction when restricted to
  tiers 1–2.
- Figure 2's $2.30 reference retains 203 of the 204 source locations, so that
  cohort is effectively selected on outcome direction alone.
- "Worsening" and "declining" use the sign of the endpoint change with no
  materiality floor, so changes well below 1% count.
- The regional-median selection rule in Figures 1 and 4 ties whenever a region
  holds exactly two eligible countries, and resolves alphabetically by ISO3.
- Two inputs are staged extracts whose producing code is not in this
  repository, so that step is documented but not re-executable here (see
  **Staged files** above).

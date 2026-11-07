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
| 1 | >10% of GDP, 2023 | 6 illustrative, one per region | `code/make_figure1.R` |
| 2 | >$2.30/person mental & neurological, 2019 | all 7 worsening on all three outcomes | `code/make_figure2.R` |
| 3 | >$1,000/person total, 2023 | all 191 with spending data, in two groups | `code/make_figure3.R` |
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

`sources.csv` carries the SHA-256 and origin of each input. In brief:

| Source | Used for | Years |
|---|---|---|
| WHO Global Health Estimates, age-standardized death rates | suicide and stroke mortality | 2019–2023 |
| IHME Global Burden of Disease 2023, via Our World in Data (series 1181423) | dementia incidence | 2019–2023 |
| World Bank `SH.XPD.CHEX.PC.CD` (WHO GHED) | total health spending per person, Figures 3–4 | 2019–2023 |
| World Bank `SH.XPD.CHEX.GD.ZS` (WHO GHED) | health spending as % of GDP, Figure 1 | 2023 |
| World Bank country metadata | regions and income groups | archived 2026-10-08 |
| Mitchell et al. (2025), *Lancet Public Health*, Supplementary Table S7, doi:10.1016/S2468-2667(25)00089-1 | mental and neurological spending, Figure 2 | 2019 |

Nothing is imputed, interpolated or carried forward. Each script builds a full
country × outcome × year grid first, so missing values stay visible, and the
`data/figure*_coverage_audit.csv` tables keep every excluded row.

**Redistribution:** the OWID/GBD dementia variable is marked
`nonRedistributable` under IHME's Free-of-Charge Non-commercial User Agreement.
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
- `inputs/countries_above_10pct.csv` and `inputs/outcome_panel_with_income.csv`
  are staged files; the code that produced them is not in this repository, so
  that step is documented but not re-executable here. `make_figure1.R`
  reconciles its plotted 2023 indices against the roster's independently
  computed endpoint changes.

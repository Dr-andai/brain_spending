# ---------------------------------------------------------------------------
# config.R - every user-facing setting for the four figures, in one place.
#
# Each figure has its own section below. Settings shared by all four come
# first. Nothing in this file reads data or draws anything: edit here, then
# re-run the relevant make_figureN.R (see README.md for the run order).
# ---------------------------------------------------------------------------

## 1. Shared analysis window -------------------------------------------------

START_YEAR <- 2019L   # index baseline: every outcome is expressed as 2019 = 100
END_YEAR   <- 2023L   # endpoint used for all change/direction calculations
YEARS      <- seq.int(START_YEAR, END_YEAR)

# Canonical outcome order for Figures 1, 3 and 4.
METRICS <- c("suicide_mortality_asr", "stroke_mortality_asr", "dementia_incidence_asr")

# Figure 2 keeps the outcome order of its original publication.
FIGURE2_METRICS <- c("dementia_incidence_asr", "stroke_mortality_asr", "suicide_mortality_asr")

LABELS <- c(
  suicide_mortality_asr = "Suicide mortality",
  stroke_mortality_asr  = "Stroke mortality",
  dementia_incidence_asr = "Dementia incidence"
)
RATE_LABELS <- c(
  suicide_mortality_asr = "Deaths per 100,000",
  stroke_mortality_asr  = "Deaths per 100,000",
  dementia_incidence_asr = "New cases per 100,000"
)

## 2. Shared appearance ------------------------------------------------------

FONT      <- "Arial"   # must be installed locally, or replace throughout
WIDTH_MM  <- 180       # single journal column pair; all four figures match
DPI       <- 600       # PNG and TIFF raster resolution
MAX_COUNTRIES <- 8     # readable limit for one-line-per-country figures

# Okabe-Ito, colour-blind safe. Point shapes are redundant with colour so the
# figures survive greyscale printing.
PALETTE <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#000000", "#E69F00", "#56B4E9", "#777777")
SHAPES  <- c(16, 17, 15, 18, 1, 2, 0, 5)

# Figures 3 and 4 were published with the first two entries swapped, so that
# orange/triangle reads as the lower-spending group. Same palette, one
# documented permutation.
SWAPPED <- c(2, 1, 3:8)

## 3. Figure 1 - illustrative countries above 10% of GDP ---------------------

FIGURE1_HEIGHT_MM <- 148
FIGURE1_SPENDING_YEAR <- 2023L
FIGURE1_GDP_THRESHOLD <- 10   # strictly greater than 10% of GDP, 2023

# World Bank regions, in the order countries are laid out in the legend.
REGION_ORDER <- c(
  "East Asia & Pacific", "Europe & Central Asia", "Latin America & Caribbean",
  "Middle East, North Africa, Afghanistan & Pakistan", "North America",
  "Sub-Saharan Africa"
)
REGION_COLOURS <- setNames(PALETTE[seq_along(REGION_ORDER)], REGION_ORDER)
REGION_SHAPES  <- setNames(SHAPES[seq_along(REGION_ORDER)], REGION_ORDER)

# NULL: one country per region, nearest that region's median 2023 spending/GDP.
# Replace with ISO3 codes to choose your own, e.g. c("CAN", "USA", "JPN").
FIGURE1_SAMPLE_ISO3 <- NULL
FIGURE1_REQUIRED_INCOME_GROUPS <- c("Low income", "Lower middle income",
                                    "Upper middle income", "High income")

## 4. Figure 2 - all countries worsening on all three outcomes ---------------

FIGURE2_HEIGHT_MM <- 152
# Modelled 2019 combined mental and neurological spending, constant 2021 US$.
# Strictly greater than this reference. Exploratory, not a verified adequacy
# threshold. Worsening means a positive 2023-minus-2019 rate change.
FIGURE2_REFERENCE_USD <- 2.30
FIGURE2_SENSITIVITY_CUTS <- c(2.30, 3, 5, 10)

## 5. Figure 3 - outcomes above and at/below $1,000 per person ---------------

FIGURE3_HEIGHT_MM <- 143
FIGURE3_SPENDING_YEAR <- 2023L   # year whose spending defines the two groups
FIGURE3_THRESHOLD_USD <- 1000    # strictly greater than this, current US$
FIGURE3_GROUPS <- c(
  paste0("At or below $", format(FIGURE3_THRESHOLD_USD, big.mark = ",", scientific = FALSE)),
  paste0("Above $",       format(FIGURE3_THRESHOLD_USD, big.mark = ",", scientific = FALSE))
)
FIGURE3_COLOURS <- setNames(PALETTE[SWAPPED][1:2], FIGURE3_GROUPS)
FIGURE3_SHAPES  <- setNames(SHAPES[SWAPPED][1:2],  FIGURE3_GROUPS)

## 6. Figure 4 - sample countries drawn from Figure 3 ------------------------

FIGURE4_HEIGHT_MM <- 152
# NULL: one country per region, nearest that region's median 2023 spending per
# person. Replace with 2-8 ISO3 codes from data/figure4_coverage_audit.csv to
# show your own sample; it must span both spending groups.
FIGURE4_SAMPLE_ISO3 <- NULL

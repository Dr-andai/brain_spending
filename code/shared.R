# ---------------------------------------------------------------------------
# shared.R - helpers used by all four figure scripts. No analysis lives here.
#
# Loaded by each make_figureN.R through init(), which also resolves the project
# root and sources config.R. Nothing here needs editing for normal use.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(jsonlite)
  library(ggplot2); library(grid)
})

# Define the standard folder names, create the output folders and load
# config.R. `code_dir` is resolved by the three-line header of each script.
init <- function(code_dir) {
  root <- normalizePath(file.path(code_dir, ".."))
  assign("ROOT", root, envir = globalenv())
  assign("IN",   file.path(root, "inputs"),  envir = globalenv())
  assign("DATA", file.path(root, "data"),    envir = globalenv())
  assign("FIG",  file.path(root, "figures"), envir = globalenv())
  for (d in c(file.path(root, "data"), file.path(root, "figures"))) {
    dir.create(d, showWarnings = FALSE)
  }
  source(file.path(root, "code/config.R"))
  invisible(root)
}

input  <- function(name) file.path(IN, name)
write_data <- function(x, name) write_csv(x, file.path(DATA, name), na = "")
write_validation <- function(x, name) {
  write_json(x, file.path(DATA, name), pretty = TRUE, auto_unbox = TRUE)
}
record_session <- function() {
  writeLines(capture.output(sessionInfo()), file.path(ROOT, "session_info.txt"))
}

## Appearance ----------------------------------------------------------------

# Minimal journal theme at final print size. ggplot linewidths are in mm.
# Pass theme() arguments through ... to override anything per figure.
theme_journal <- function(...) {
  settings <- list(
    plot.title = element_text(size = 7, margin = margin(b = 6)),
    plot.tag = element_text(size = 8, face = "bold"), plot.tag.position = "topleft",
    axis.text = element_text(size = 6, colour = "black"),
    axis.title = element_text(size = 7),
    axis.line = element_line(linewidth = .18), axis.ticks = element_line(linewidth = .18),
    axis.ticks.length = unit(1, "mm"),
    legend.position = "bottom", legend.title = element_blank(),
    legend.text = element_text(size = 6.5),
    legend.key.width = unit(6, "mm"), legend.key.height = unit(3.3, "mm"),
    legend.margin = margin(0, 0, 0, 0), plot.margin = margin(5, 4, 4, 4)
  )
  overrides <- list(...)
  settings[names(overrides)] <- overrides
  theme_classic(base_size = 7, base_family = FONT) + do.call(theme, settings)
}

# One panel of annual values for one outcome, drawn as a line and points per
# group (a region, a country or a spending group).
#   y_var     "index"-style column, or an absolute rate when from_zero = TRUE
#   labels    named vector: names are the group values, values the legend text
#   linetypes optional named vector; adds a linetype aesthetic (Figure 4)
trend_panel <- function(data, y_var, group_var, colours, shapes, labels,
                        title, tag, y_label, reference_line = TRUE,
                        linetypes = NULL, linewidth = .28, point_size = 1.15,
                        from_zero = FALSE, expand_upper = .10, legend_ncol = 2, ...) {
  mapping <- if (is.null(linetypes)) {
    aes(x = year, y = .data[[y_var]], group = .data[[group_var]],
        colour = .data[[group_var]], shape = .data[[group_var]])
  } else {
    aes(x = year, y = .data[[y_var]], group = .data[[group_var]],
        colour = .data[[group_var]], shape = .data[[group_var]], linetype = .data[[group_var]])
  }
  p <- ggplot(data, mapping)
  # The dashed reference marks the index baseline; absolute-rate panels omit it.
  if (reference_line) {
    p <- p + geom_hline(yintercept = 100, linetype = "22", linewidth = .18, colour = "grey55")
  }
  p <- p + geom_line(linewidth = linewidth) + geom_point(size = point_size, stroke = .30) +
    scale_colour_manual(values = colours, breaks = names(labels), labels = labels, drop = FALSE) +
    scale_shape_manual(values = shapes, breaks = names(labels), labels = labels, drop = FALSE)
  if (!is.null(linetypes)) {
    p <- p + scale_linetype_manual(values = linetypes, breaks = names(labels), labels = labels, drop = FALSE)
  }
  p +
    scale_x_continuous(breaks = YEARS, expand = expansion(mult = c(.05, .05))) +
    (if (from_zero) {
      scale_y_continuous(limits = c(0, NA), n.breaks = 4, expand = expansion(mult = c(0, expand_upper)))
    } else {
      # Always show the baseline tick alongside pretty breaks.
      scale_y_continuous(breaks = function(l) sort(unique(c(scales::breaks_pretty(n = 4)(l), 100))),
                         expand = expansion(mult = c(.08, expand_upper)))
    }) +
    labs(x = NULL, y = y_label, title = title, tag = tag,
         colour = NULL, shape = NULL, linetype = NULL) +
    guides(colour = guide_legend(ncol = legend_ncol, byrow = TRUE),
           shape = guide_legend(ncol = legend_ncol, byrow = TRUE),
           linetype = guide_legend(ncol = legend_ncol, byrow = TRUE)) +
    theme_journal(...)
}

## Assembly and export ------------------------------------------------------

# Combine panels into a 3-column grid with one shared legend below, and
# optional footer text. Panel widths are aligned so axes line up across rows.
# Text is measured on an in-memory ragg device because R's default device does
# not know system TrueType fonts such as Arial.
assemble <- function(panels, height_mm, legend_height_mm,
                     row_heights = rep(1, ceiling(length(panels) / 3)),
                     footer = NULL, footer_height_mm = 1) {
  ragg::agg_capture(width = WIDTH_MM, height = height_mm, units = "mm", res = 150)
  on.exit(invisible(dev.off()), add = TRUE)

  guide <- ggplotGrob(panels[[1]])
  slot <- which(guide$layout$name == "guide-box-bottom")
  stopifnot(length(slot) == 1)
  legend <- guide$grobs[[slot]]

  grobs <- lapply(panels, function(p) ggplotGrob(p + theme(legend.position = "none")))
  widths <- Reduce(unit.pmax, lapply(grobs, function(g) g$widths))
  grobs <- lapply(grobs, function(g) { g$widths <- widths; g })

  body <- gtable::gtable(widths = unit(rep(1, 3), "null"), heights = unit(row_heights, "null"))
  for (i in seq_along(grobs)) {
    body <- gtable::gtable_add_grob(body, grobs[[i]], t = (i - 1) %/% 3 + 1, l = (i - 1) %% 3 + 1)
  }
  full <- gtable::gtable(widths = unit(1, "null"),
                         heights = unit.c(unit(1, "null"), unit(legend_height_mm, "mm"),
                                          unit(footer_height_mm, "mm")))
  full <- gtable::gtable_add_grob(full, body, t = 1, l = 1)
  full <- gtable::gtable_add_grob(full, legend, t = 2, l = 1)
  if (!is.null(footer)) {
    full <- gtable::gtable_add_grob(
      full, textGrob(footer, gp = gpar(fontfamily = FONT, fontsize = 6)), t = 3, l = 1)
  }
  full
}

# Editable vector PDF (Quartz on macOS, Cairo elsewhere) plus 600 dpi PNG and
# LZW-compressed TIFF, all at the final print size.
export_figure <- function(grob, stem, height_mm) {
  draw <- function() { grid.newpage(); grid.draw(grob); invisible(dev.off()) }
  pdf_file <- file.path(FIG, paste0(stem, ".pdf"))
  if (Sys.info()[["sysname"]] == "Darwin") {
    quartz(type = "pdf", file = pdf_file, width = WIDTH_MM / 25.4, height = height_mm / 25.4, family = FONT)
  } else {
    cairo_pdf(pdf_file, width = WIDTH_MM / 25.4, height = height_mm / 25.4, family = FONT)
  }
  draw()
  ragg::agg_png(file.path(FIG, paste0(stem, ".png")),
                width = WIDTH_MM, height = height_mm, units = "mm", res = DPI)
  draw()
  ragg::agg_tiff(file.path(FIG, paste0(stem, ".tiff")),
                 width = WIDTH_MM, height = height_mm, units = "mm", res = DPI, compression = "lzw")
  draw()
  invisible(file.path(FIG, paste0(stem, c(".pdf", ".png", ".tiff"))))
}

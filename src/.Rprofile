# Auto-load the project-local package library (.Rlib) so both RStudio and command
# line Rscript reliably find our packages (data.table, ggplot2, zoo, minpack.lm,
# rmarkdown, knitr, bookdown, tinytex).
#
# Why this exists: the normal Windows user library lives under AppData, which on
# this machine is redirected/virtualised and was unreliable (packages sometimes
# "disappeared"). A plain folder on the D: drive is not virtualised, so it is
# stable. This file runs automatically when R starts in the src/ folder.
local({
  lib <- file.path(getwd(), ".Rlib")
  if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))
})

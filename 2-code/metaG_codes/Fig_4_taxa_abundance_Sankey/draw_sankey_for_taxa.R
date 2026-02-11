### draw_sankey_for_taxa.R by Young C. Song
### Written on the 10th of Feb, 2026
### Provide a tab-separated gtdb-taxonomic hierarchy (see example)
### and let this sucka do the rest (draw Sankey of taxa distribution.)

library(sf)
library(ggplot2)
library(readr)
library(rnaturalearth)
library(rnaturalearthdata)
library(dplyr)
library(rstudioapi)
library(tidyverse)
library(networkD3)

library(webshot2)   # or webshot
library(htmlwidgets)

### The next three lines sets the path to where the code is currently located
this_path <- getActiveDocumentContext()$path
setwd(dirname(this_path))
getwd()

taxa <- read.delim("../taxa_abundance/61049_2_TOP_gtdbtk.tsv", stringsAsFactors = FALSE, header=TRUE, check.names=FALSE)

# Make sure the columns are in the expected order
rank_cols <- c("Domain", "Phylum", "Class", "Order", "Family", "Genus")
taxa <- taxa[, rank_cols]

#--------------------------------------------------
# 2. Build adjacent rank pairs (Domain→Phylum, …)
#--------------------------------------------------

pairs_list <- lapply(seq_len(length(rank_cols) - 1), function(i) {
  from_col <- rank_cols[i]
  to_col   <- rank_cols[i + 1]
  
  taxa %>%
    select(all_of(from_col), all_of(to_col)) %>%
    rename(from = all_of(from_col),
           to   = all_of(to_col)) %>%
    mutate(level_from = from_col,
           level_to   = to_col)
})

edges_raw <- bind_rows(pairs_list)

#--------------------------------------------------
# 3. Handle missing/None genus separately per family
#    (and similarly for any rank, if needed)
#--------------------------------------------------

edges_raw <- edges_raw %>%
  mutate(
    # unclassified parent (e.g. unknown Phylum)
    from = ifelse(
      is.na(from) | from == "",
      paste0(level_from, ":Unclassified"),
      from
    ),
    # parent-specific unclassified child (e.g. Genus unknown within a specific Family)
    to = case_when(
      is.na(to) | to == "" | to == "None" ~
        paste0(level_to, ":Unclassified_from_", from),
      TRUE ~ to
    )
  )

#--------------------------------------------------
# 4. Count links and compute percentages
#--------------------------------------------------

edges_counts <- edges_raw %>%
  group_by(level_from, level_to, from, to) %>%
  summarise(value = n(), .groups = "drop")

total_MAGs <- nrow(taxa)

edges_counts <- edges_counts %>%
  mutate(pct_of_all = value / total_MAGs * 100) %>%
  group_by(level_from, from) %>%
  mutate(pct_within_from = value / sum(value) * 100) %>%
  ungroup()

#--------------------------------------------------
# 5. Fix ordering of edges and nodes
#--------------------------------------------------

# Sort edges in a deterministic way
edges_counts <- edges_counts %>%
  arrange(level_from, from, level_to, to)
p

# Save to HTML
saveWidget(p, "../taxa_abundance/sankey.html", selfcontained = TRUE)

webshot("../taxa_abundance/sankey.html",
        file   = "../taxa_abundance/sankey_2.pdf",
        zoom   = 2,
        vwidth = 1200,
        vheight = 800)


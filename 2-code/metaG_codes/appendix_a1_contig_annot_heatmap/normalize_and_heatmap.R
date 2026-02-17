#### Created 2.3.24 Izabel Stohel 

#### Modified by Young C. Song on 02/12/24

#### Normalize ko and taxa data 
#### read in metadata 

#load libraries----
library(tidyverse)
library(NOISeq)
library(dplyr)
library(reshape2)

library(rstudioapi)

### The next three lines sets the path to where the code is currently located
this_path <- getActiveDocumentContext()$path
setwd(dirname(this_path))
getwd()

#load data----

#load/transform metadata 

ko_path_tbl <- read.delim("../annotation_heatmap/MONet_methods_NEON_KO_micro_degr.tsv", stringsAsFactors = FALSE, header=TRUE, check.names=FALSE)

### We are going to remove some rows (or KOs) that either have zeroes across the samples or
### are just present in very low level

# First, calculate the averages of each row across the samples
#ko_path_tbl$average <- rowMeans(ko_path_tbl[, 7:(ncol(ko_path_tbl))])
ko_path_tbl$average <- rowMeans(ko_path_tbl[, 3:(ncol(ko_path_tbl))])

ko_path_tbl_sort_avg <- ko_path_tbl[order(ko_path_tbl$average, decreasing = TRUE), ]

# This finds the threshold index, where the sum of the averages
# on the left side of it would represent 99.5% of the total sum of the averages
# Codes for drawing the threshold is currently commented out.
total_avg_sum <- sum(ko_path_tbl_sort_avg$average)
cumul_avg_sum <- cumsum(ko_path_tbl_sort_avg$average)

threshold_row <- which(cumul_avg_sum >= 0.95 * total_avg_sum)[1]
threshold_row
threshold_value <- ko_path_tbl_sort_avg$average[threshold_row]
threshold_value

# Draw a bar chart of averages and draw a red line to indicate the point
# where left side of it represents 90% of the cumulative sum of averages.
ggplot(ko_path_tbl_sort_avg, aes(x = reorder(KO, -average), y = average)) +
  geom_col() +  # Create bar chart
  geom_vline(
    xintercept = which(ko_path_tbl_sort_avg$average == ko_path_tbl_sort_avg$average[threshold_row]),  # Add a red vertical line
    linetype = "dashed", color = "red", linewidth = 0.3
  ) +
  labs(
    title = "Histogram of Averages with Threshold Highlighted",
    x = "CAZy",
    y = "Average raw count"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1)
  )

ko_path_tbl_row_filtered <- ko_path_tbl_sort_avg[ko_path_tbl_sort_avg$average >= threshold_value,]
write.table(ko_path_tbl_row_filtered, "../annotation_heatmap/MONet_methods_NEON_KO_micro_degr_collapsed.tsv", sep = "\t", row.names = FALSE, quote = FALSE)


### Optional: filter columns based on average threshold
### NOTE To Mike: I did not use this option (lines 66 to 75). I skipped right to line 79.

#numeric_cols <- ko_path_tbl_row_filtered[, sapply(ko_path_tbl_row_filtered, is.numeric), drop = FALSE]
#column_means <- sapply(numeric_cols, mean)

#ko_path_tbl_row_col_filtered <- numeric_cols[, column_means >=0.5, drop = FALSE]
#row_col_filtered_raw <- ko_path_tbl_row_col_filtered[,1:(ncol(ko_path_tbl_row_col_filtered)-1)]

#KO = ko_path_tbl_row_filtered$CAZy
#raw_matrix <- cbind(KO, row_col_filtered_raw)

#write.table(raw_matrix, "./1000_Soils_fungal_dbCAN_row_col_filtered.tsv", sep = "\t", row.names = FALSE, quote = FALSE)

### Perform the TMM normalization using the filtered table

KO = ko_path_tbl_row_filtered$KO
raw_values = ko_path_tbl_row_filtered[, 2:(ncol(ko_path_tbl_row_filtered)-1)] # skipping the column with Texas sample for now

raw_matrix <- cbind(KO, raw_values)

#tmm_norm = tmm(raw_matrix[,2:ncol(raw_matrix)], long=1000, lc=0, k=0)
tmm_norm = tmm(raw_matrix[,sapply(raw_matrix,is.numeric)], long=1000, lc=0, k=0)

tmm_matrix <- cbind(KO, tmm_norm)

write.table(tmm_matrix, file="../annotation_heatmap/MONet_methods_NEON_KO_micro_degr_tmm.tsv", sep="\t")

### Optional: If you have three-column table that maps KOs to gene names and pathway info, you can link that
### to the tmm matrix.
### NOTE TO Mike: This option was used.

ko_gene_path <- read.delim("../annotation_heatmap/MONet_methods_NEON_KO_micro_degr_filtered_gene_list.tsv", stringsAsFactors = FALSE, header=TRUE, check.names=FALSE)

tmm_ko_gene_path <- merge(tmm_matrix, ko_gene_path, by="KO", all=TRUE)

# Re-order the rows, first by Pathway and then by Gene_name
tmm_ko_gene_path_sort_row <- tmm_ko_gene_path[order(tmm_ko_gene_path$Pathway, tmm_ko_gene_path$Gene_name), ]

# This re-orders the columns to have the Pathway and Gene_name become second and third columns in respective order
tmm_ko_gene_path_sort_row_col <- tmm_ko_gene_path_sort_row[, c("KO", "Pathway", "Gene_name", setdiff(names(tmm_ko_gene_path_sort_row), c("KO", "Pathway", "Gene_name")))]

write.table(tmm_ko_gene_path_sort_row_col, file = "../annotation_heatmap/MONet_methods_NEON_KO_micro_degr_tmm_path_gene.tsv", sep = "\t", row.names = FALSE, col.names = TRUE)

### Draw a heat map of the normalized values. 

# First, we are going to create a table, with Gene_name as first col (row name)
heatmap_table_wide <- tmm_ko_gene_path_sort_row_col[,4:ncol(tmm_ko_gene_path_sort_row_col)]
Gene_name <- tmm_ko_gene_path_sort_row_col$Gene_name
heatmap_table_wide <- cbind(Gene_name,heatmap_table_wide)

# Convert the wide table to a long format.
heatmap_table_long <- melt(heatmap_table_wide, id.vars = "Gene_name", variable.name = "Sample", value.name = "TMM")
heatmap_table_long$TMM <- as.numeric(as.character(heatmap_table_long$TMM))

heatmap_table_long$Gene_name <- factor(heatmap_table_long$Gene_name, levels = rev(unique(heatmap_table_wide$Gene_name)))

### Run the next two lines to determine the breaks for lines 126 and 127
max(heatmap_table_long$TMM)
min(heatmap_table_long$TMM)

heatmap_table_long_binned <- heatmap_table_long %>%
  mutate(TMM_bin = cut(
    TMM,
    breaks = c(-Inf, 100, 500, 1000, 1500, 2000, Inf),  # adjust these cut points to your data
    labels = c("≤100", "100–500","500-1000","1000–1500","1500-2000",">2000"),
    right = TRUE
  ))

ggplot(heatmap_table_long_binned, aes(x = Sample, y = Gene_name, fill = TMM_bin)) +
  geom_tile() + # Creates the heatmap tiles
  #scale_fill_gradient(low = "white", high = "black") + # Specify color gradient for intensity
  scale_fill_brewer(palette = "Greys", na.value="white") +
  theme_minimal() + # Use a clean minimal theme
  scale_x_discrete(position = "top") + # Place x-axis labels at the top
  theme(axis.text.x = element_text(angle = 45, hjust = 0)) + # Rotate x-axis labels for readability
  labs(title = "Gene Expression Heatmap",
       x = "Samples", 
       y = "Genes", 
       fill = "Normalized Counts") # Add axis labels and legend title


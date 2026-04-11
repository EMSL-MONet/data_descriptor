

metadata = read.csv("1-data/metadata/metadata_MONet_FY23_FY24_FY25_FY26.csv")





#
# data files ----

import_data = function(FILEPATH, PATTERN){
  
  filePaths <- list.files(path = FILEPATH, pattern = PATTERN, full.names = TRUE)
  dat <- do.call(bind_rows, lapply(filePaths, function(path) {
    df <- read_csv(path)
    df}))
}

## BD

bd = import_data(FILEPATH = "1-data/bgc_data", PATTERN = "Bulk_density") %>% 
  left_join(metadata)

bd %>% 
  ggplot(aes(x = soil_type, y = Bulk_density_g_per_cm3, color = Core_Section))+
  geom_violin(color = "black")+
  geom_jitter(width = 0.1, size = 0.5)



## pH

pH = import_data(FILEPATH = "1-data/bgc_data", PATTERN = "pH") %>% 
  left_join(metadata)

pH %>% 
  ggplot(aes(x = soil_type, y = pH))+
  geom_violin(color = "black")+
  geom_jitter(width = 0.1, size = 0.5)+
  labs(x = "")

## BGC

bgc = import_data(FILEPATH = "1-data/bgc_data", PATTERN = "biogeochemistry") %>% 
  left_join(metadata)


gg_ph = 
  bgc %>% 
  ggplot(aes(x = soil_type, y = pH))+
 # geom_violin(color = "black")+
  geom_jitter(width = 0.1, size = 0.5)+
  labs(x = "",
       y = "pH 
       ")


gg_weom = 
  bgc %>% 
  ggplot(aes(x = soil_type, y = WEOM_TOC_mg_per_kg))+
  #geom_violin(color = "black")+
  geom_jitter(width = 0.1, size = 0.5)+
  labs(x = "",
       y = "Water Extractable 
       Organic Carbon (mg/kg)
       ")
  
cowplot::plot_grid(gg_ph, gg_weom, nrow = 2, align = "hv", labels = c("A", "B"))

#
# sample counts ----

metadata_columns = 
  metadata %>% 
  distinct(call, Proposal_ID, Sampling_Set, ecoregion, soil_type, cur_land_use)

metadata_columns %>% 
  group_by(call, soil_type) %>% 
  dplyr::summarise(n = n()) %>% 
  ggplot(aes(x = soil_type, y = n, fill = call))+
  geom_bar(stat = "identity")+
  scale_fill_manual(values = soil_palette("redox2", 4))+
  labs(x = "
       Soil Order",
       y = "count")

theme_set(theme_bw())

import_metadata = function(FILEPATH, PATTERN){
  
  filePaths <- list.files(path = FILEPATH, pattern = PATTERN, full.names = TRUE)
  dat <- do.call(bind_rows, lapply(filePaths, function(path) {
    df <- read_csv(path) %>% mutate_all(as.character)
    df}))
}




lat_lon = import_metadata(FILEPATH = "1-data/metadata", PATTERN = "")



library(sf) # for map
library(ggspatial) # for north arrow


## Set CRS
common_crs <- 4326

## Set map size and point size
point_size <- 2
map_width = 9
map_height = 6

## Set regional and WLE/CB (inset) bounding boxes
us_bbox <- c(xmin = -180, xmax = -60, ymin = 0, ymax = 90)

## Make US states map cropped to GL/CB region
us <- 
  read_sf("cb_2018_us_state_5m/cb_2018_us_state_5m.shp") %>% 
  st_transform(., crs = common_crs) %>% 
  st_crop(., y = us_bbox)



## create a df with site coordinates and labels
sites = lat_lon %>% 
  separate(lat_lon, sep = ",", into = c("lat", "lon"), remove = F) %>% 
  dplyr::select(lat, lon, call) %>% 
  mutate(lat = parse_number(lat),
         lon = parse_number(lon))

## Make the base map
# base_plot <- 
  ggplot() + 
  geom_sf(data = us) + 
  #   geom_sf_text(data = st_labels, aes(label = STUSPS))+
  geom_point(
    data = sites, aes(lon, lat, color = call),
    size = 2)+
#  annotation_north_arrow(location = "tr", which_north = "true", 
#                         pad_x = unit(0.0, "in"), pad_y = unit(0.2, "in"),
#                         style = north_arrow_fancy_orienteering)+
#  xlim(-180, -60)+
#  ylim(0, 50)+
  theme(legend.background = element_rect(fill = alpha("white", 0.0)), 
        legend.key = element_rect(fill = "transparent"), 
        legend.position = c(0.85, 0.1)) + 
  labs(x = "", y = "")+
  NULL
  
  
  
  
 
  
  

# -------------------------------------------------------------------------

  
  neonDomains <- read_sf("NEONDomains_2024", layer="NEON_Domains")
  plot(st_geometry(neonDomains))
  
  
  neonMercator <- st_transform(neonDomains,
                               crs="+proj=merc")
  
  plot(st_geometry(neonMercator))
  
  
baseplot =   
  ggplot() + 
    geom_sf(data = neonDomains, color = "black", aes(fill = domainName), show.legend = F, alpha = 0.5) + 
    theme(legend.background = element_rect(fill = alpha("white", 0.0)), 
          legend.key = element_rect(fill = "transparent"), 
          legend.position = c(0.85, 0.1),
          axis.text = element_blank()) + 
  geom_point(data = sites, 
             aes(lon, lat),
             size = 2, color = "black")+
  cowplot::theme_map() + 
  labs(x = "", y = "")+
  scale_fill_manual(values = pnw_palette("Bay", 20))+
  #scale_fill_manual(values = whistledown_palette("featherington", 20))+
  scale_fill_manual(values = microViz::distinct_palette(n = 20, pal = "kelly"))+
  NULL   

  
usa = 
  baseplot + 
    coord_sf(xlim = c(-130, -65), ylim = c(19, 50), expand = F)+
    NULL  
  


ak = 
  baseplot +
  coord_sf(xlim = c(-180, -120), ylim = c(50, 75), expand = F)+
  NULL  

hi = 
  baseplot + 
  coord_sf(xlim = c(-162, -152), ylim = c(18, 23), expand = F)+
  NULL  



usa + 
  annotation_custom(
    ggplotGrob(ak), 
    xmin = -130, xmax = -110, ymin = 10, ymax = 40)+
  annotation_custom(
    ggplotGrob(hi), 
    xmin = -115, xmax = -100, ymin = 12, ymax = 32)+
  theme_kp()
  
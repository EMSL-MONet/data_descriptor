
metadata = read.csv("1-data/metadata/old/combined_validated 2.csv")

googledrive::drive_download("https://docs.google.com/spreadsheets/d/1EUDwUb5jcAq6IRaDNLf9oPmM5qQGbZHL/edit?gid=722708517#gid=722708517")

fy23_list = readxl::read_xlsx("MONet Project Tracker", sheet = "FY23 Soil Function") %>% dplyr::select(Project_ID)
fy24_list = readxl::read_xlsx("MONet Project Tracker",  sheet = "FY24 Soil Function") %>% dplyr::select(Project_ID)
fy25_list = readxl::read_xlsx("MONet Project Tracker",  sheet = "FY25 Soil Function") %>% dplyr::select(Project_ID)
fy26_list = readxl::read_xlsx("MONet Project Tracker",  sheet = "SOILS-AI") %>% dplyr::select(Project_ID)



call_list = 
  fy23_list %>% mutate(call = "FY23") %>% 
  bind_rows(fy24_list %>% mutate(call = "FY24")) %>% 
  bind_rows(fy25_list %>% mutate(call = "FY25")) %>% 
  bind_rows(fy26_list %>% mutate(call = "FY26")) %>% 
  distinct() %>% 
  mutate(Project_ID = as.character(Project_ID))

metadata_with_year = 
  metadata %>% 
  separate(sample_name, sep = "_", into = c("Proposal_ID", "Sampling_Set", "Core"), remove = F) %>% 
  left_join(call_list, by = c("Proposal_ID" = "Project_ID")) %>% 
  dplyr::select(call, everything()) %>% 
  filter(Core == "A")

metadata_with_year_without_61049_61558 = 
  metadata_with_year %>% 
  filter(!Proposal_ID %in% c("61049", "61558"))

metadata_with_year_only_61049_61558 = 
  metadata_with_year %>% 
  filter(Proposal_ID %in% c("61049", "61558")) %>% 
  mutate(Sampling_Set = as.numeric(Sampling_Set)) %>% 
  mutate(call = case_when(
    # hard code the different 61049 cores
    Proposal_ID == "61049" & (Sampling_Set >= 1 & Sampling_Set <= 12) ~ "FY23",
    Proposal_ID == "61049" & (Sampling_Set >= 13 & Sampling_Set <= 29) ~ "FY23",
    Proposal_ID == "61049" & (Sampling_Set >= 30 & Sampling_Set <= 45) ~ "FY25",
    Proposal_ID == "61049" & (Sampling_Set >= 46 ) ~ "FY26",
    
    # hard code the different 61558 cores
    Proposal_ID == "61558" & (Sampling_Set >= 1 & Sampling_Set <= 2) ~ "FY24",
    Proposal_ID == "61558" & (Sampling_Set >= 3) ~ "FY25"
    )) %>% 
  mutate(Sampling_Set = as.character(Sampling_Set))
  

metadata_final = 
  metadata_with_year_without_61049_61558 %>% 
  bind_rows(metadata_with_year_only_61049_61558) %>% 
  dplyr::select(call, Proposal_ID, Sampling_Set, lat_lon, geo_loc_name, soil_type, fao_class, cur_vegetation, ecoregion, cur_land_use) %>% 
  distinct()

metadata_final %>% write.csv("1-data/metadata/metadata_MONet_FY23_FY24_FY25_FY26.csv", row.names = F, na = "")


## fticr processing


import_files = function(FILEPATH){
  
  # identify the .zip files and unzip them as csv files
  # the csv files will be saved in the parent directory (these are temporary files, will be deleted at the end)
  zip_filePaths <- list.files(path = FILEPATH, pattern = ".zip", full.names = TRUE, recursive = TRUE)
  zip_filePaths %>% lapply(unzip)
  
  # now, identify all the fticrWEOM csv files that we just extracted 
  csv_filePaths <- list.files(pattern = "fticrWEOM", full.names = TRUE)
  
  # read and combine the fticrWEOM csv files
  icr_dat <- do.call(bind_rows, lapply(csv_filePaths, function(path) {
    
    data = read.csv(path) %>% 
      mutate(source = basename(path)) # add file name
    
  }))
  
  # finally, delete the temporary files from the parent directory
  file.remove(csv_filePaths)
  
  # this is our final output
  icr_dat
}
icr_report = import_files("1-data/fticr")

#
# II. Initial cleaning ----
### Create molecular metadata file (`mol`)

mol = 
  icr_report %>% 
  dplyr::select(`Molecular.Formula`, C,H,O,N,P,S) %>% 
  rename(molecular_formula = `Molecular.Formula`) %>% 
  distinct()

## Now, we want to process the `mol` file and calculate various indices

## (a) indices
## - AImod (aromatic index), calculated based on [Koch and Dittmar (2016)](https://doi.org/10.1002/rcm.7433)
## - NOSC (nominal oxidation state of carbon), calculated based on [Riedel et al. 2012](https://doi.org/10.1021/es203901u)
## - GFE (Gibbs Free Energy of carbon oxidation), calculated from NOSC, as per [LaRowe & Van Cappellen 2011](https://doi.org/10.1016/j.gca.2011.01.020)
## - H/C, or the ratio of hydrogen to carbon in the molecule
## - O/C, or the ratio of oxygen to carbon in the molecule

mol = 
  mol %>% 
  mutate(across(c("N","S","P"), ~replace_na(.,0)), # convert all blank cells to 0 to help with calculations
         AImod = round((1 + C - (0.5*O) - S - (0.5 * (N+P+H)))/(C - (0.5*O) - S - N - P), 4),
         # some AImod values may be NA, or Inf, or -Inf. Change those to 0
         AImod = ifelse(is.na(AImod), 0, AImod),
         AImod = ifelse(AImod == "Inf", 0, AImod),
         AImod = ifelse(AImod == "-Inf", 0, AImod),
         NOSC = round(4 - ((4*C + H - 3*N - 2*O + 5*P - 2*S)/C),4),
         GFE = 60.3 - (28.5 * NOSC),
         HC = round(H/C, 2),
         OC = round(O/C, 2)
  )

## (b) Elemental class
## We can also group the molecules based on the elemental composition, i.e. "CHO", "CHONS", "CHONP", "CHONPS" classes

mol = 
  mol %>% 
  mutate(
    # we need to drop any isotopic info (13C, 34S, etc.)
    El = str_remove_all(molecular_formula, "13C|34S|17O|18O|15N"),
    # remove any numbers from the formula to get just the elements
    El = str_remove_all(El, "[0-9]"),
    El = str_remove_all(El, " "))

## (c) molecular class
## Next, we assign classes (aromatic, aliphatic, etc.). These are Van Krevelen classes, typically assigned based on the H/C, O/C, and AImod indices. 
## We calculate three sets of classes; users can use any of these, or assign their own classes as appropriate.
## 
## 1. `Class1` from [Kim et al. 2003](https://doi.org/10.1021/ac034415p) uses H/C and O/C to classify molecules into "lipid", "unsaturated hydrocarbon", "protein", "lignin", "carbohydrate", amino sugar", "tannin", and "condensed hydrocarbon"
## 2. `Class2` from [Seidel et al. 2014](https://doi.org/10.1016/j.gca.2014.05.038) uses H/C, O/C, and AImod to classify molecules into "aromatic", "condensed aromatic", "highly unsaturated compounds including polyphenols/lignins", and "aliphatic"
## 3. `Class3` from [Seidel et al. 2017](https://doi.org/10.3389/feart.2017.00031) includes classes "aromatic", "condensed aromatic", "highly unsaturated compounds including polyphenols/lignins", "carbohydrate", "lipid", "aliphatic", and "aliphatic containing N".
## 

mol = 
  mol %>% 
  mutate(
    Class1 = case_when(HC >= 1.5 & HC <= 2.5 & OC >= 0 & OC <= 0.3 ~ "Lipid",
                       HC >= 0.8 & HC <= 1.5 & OC >= 0.05 & OC <= 0.15 ~ "Unsat Hydrocarbon",
                       HC >= 1.5 & HC <= 2 & OC >= 0.3 & OC <= 0.55 ~ "Protein",
                       HC >= 0.8 & HC <= 1.5 & OC >= 0.28 & OC <= 0.65 ~ "Lignin",
                       HC >= 1.5 & HC <= 2.15 & OC >= 0.7 & OC <= 1 ~ "Carbohydrate",
                       HC >= 1.5 & HC <= 1.8 & OC >= 0.55 & OC <= 0.7 ~ "Amino Sugar",
                       HC >= 0.8 & HC <= 1.5 & OC >= 0.65 & OC <= 1.05 ~ "Tannin",
                       HC >= 0.3 & HC <= 0.8 & OC >= 0.12 & OC <= 0.7 ~ "Cond Hydrocarbon",
                       TRUE ~ "Other"),
    Class2 = case_when(AImod > 0.66 ~ "condensed aromatic",
                       AImod <= 0.66 & AImod > 0.50 ~ "aromatic",
                       AImod <= 0.50 & HC < 1.5 ~ "unsaturated/lignin",
                       HC >= 1.5 ~ "aliphatic",
                       TRUE ~ "other"),
    Class3 = case_when(AImod > 0.66 ~ "condensed aromatic",
                       AImod <= 0.66 & AImod > 0.50 ~ "aromatic",
                       AImod <= 0.50 & HC < 1.5 ~ "unsaturated/lignin",
                       HC >= 2.0 & OC >= 0.9 ~ "carbohydrate",
                       HC >= 2.0 & OC < 0.9 ~ "lipid",
                       HC < 2.0 & HC >= 1.5 & N == 0 ~ "aliphatic",
                       HC < 2.0 & HC >= 1.5 & N > 0 ~ "aliphatic+N",
                       TRUE ~ "other")
  )
         

## this file now contains most of the info needed to interpret the data across different samples.

### Create `dat`

## This dataframe contains info about the samples being analyzed, i.e., which peaks were identified in which sample.  
## We will clean this up and eventually merge with the `mol` dataframe.

dat = 
  icr_report %>% 
  dplyr::select(source, Molecular.Formula, Calculated.m.z, contains("Peak.Area")) %>% 
  janitor::clean_names() %>% 
  separate(source, sep = "_", into = c("icr", "Proposal_ID", "Sampling_Set", "Core_Section", "Rep")) %>% 
  mutate(Rep = parse_number(Rep),
         sample_name = paste0(Proposal_ID, "_", Sampling_Set, "_", Core_Section)) %>% 
  dplyr::select(-icr)


#### 3 acquisitions

## Each sample/rep was analyzed 3 times on the machine (i.e., 3 acquisitions, or instrument replicates).  
## For robust analysis, some users may choose to only include peaks identified across multiple acquisitions (e.g., peaks seen in 2 of 3 acqusitions, or peaks seen in all acquisitions). The choice is dependent on the user and the questions being asked.  
## For this example, we only include peaks identified in 2 of the 3 acquisitions. 

## acquisition reps
# an easy way to do this is to convert all the peak areas to binary 0/1 and then add them up. 
# if the sum is 2 or more, that means the peak was seen in 2 or more acquisitions

dat_acq = 
  dat %>% 
  mutate(peak_area_1 = case_when(peak_area_1 > 0 ~ 1),
         peak_area_2 = case_when(peak_area_2 > 0 ~ 1),
         peak_area_3 = case_when(peak_area_3 > 0 ~ 1),
         acquisition_count = peak_area_1 + peak_area_2 + peak_area_3,
         acquisition_KEEP = acquisition_count == 3) %>% 
  filter(acquisition_KEEP) %>% 
  dplyr::select(-c(contains("peak_area"), contains("acquisition")))


#### 3 replicates

## Each sample was extracted 3 times. We apply the same 2/3 replication filter as above. This is also user-dependent.
## Now, we only select molecules that were identified in 2/3 of the total reps

# identify the number of replicates for each sample
# for this MONet workflow, each sample has 3 replicates, so it is straightforward.
# But this code can be used even if there was uneven replication across different samples.

# now, calculate the occurrence of each peak 
dat_reps = 
  dat_acq %>% 
  group_by(Proposal_ID, Sampling_Set, Core_Section, molecular_formula) %>% 
  dplyr::mutate(peak_reps = n()) %>%
  ungroup() %>% 
  mutate(KEEP = peak_reps == 3) %>% 
  filter(KEEP) %>% 
  dplyr::select(-KEEP)

dat_final = 
  dat_reps %>% 
  dplyr::select(-c(Rep, peak_reps)) %>% 
  distinct()

## This is the list of all the peaks "present" (identified) in our samples.
## Now, combine this file with the `mol` file we generated above.

icr_processed = 
  dat_final %>% 
  left_join(mol) %>% 
  mutate(Core_Section = factor(Core_Section, levels = c("TOP", "BTM")))


#
# Van Krevelens -----------------------------------------------------------

# mod
classification <- tribble(
  ~Class, ~OC_low, ~OC_high, ~HC_low, ~HC_high,
  'Lipid', 0, 0.3, 1.5, 2.5,
  'Unsat. HC', 0.05, 0.15, 0.8, 1.5,
  'Cond. HC', 0.12, 0.7, 0.3, 0.8,
  'Protein', 0.3, 0.55, 1.5, 2,
  'Amino sugar', 0.55, 0.7, 1.5, 1.8,
  'Carbohydrate', 0.7, 1, 1.5, 2.15,
  'Lignin', 0.28, 0.65, 0.8, 1.5,
  'Tannin', 0.65, 1.05, 0.8, 1.5, 
) %>% 
  mutate(label_x = (OC_low + OC_high) / 2,
         label_y = (HC_low + HC_high) / 2)


## Compound class rectangles (for plotting of Van Krevelen diagrams) ----

class_rect <-  geom_rect(data = classification,
                         aes(xmin = OC_low,
                             xmax = OC_high,
                             ymin = HC_low,
                             ymax = HC_high),
                         color = 'black',
                         fill = NA,
                         linewidth = 1,
                         inherit.aes = FALSE, 
                         linetype = 'dashed')

rect_label <- geom_label(data = classification,
                         aes(x = label_x,
                             y = label_y,
                             label = Class),
                         inherit.aes = FALSE,
                         size = 4)



icr_processed %>% 
  ggplot(aes(x = OC, y = HC, color = Class1))+
  geom_point()+
  class_rect+
  rect_label+
  scale_color_manual(values = whistledown_palette("queen", 9))+
  facet_wrap(~Core_Section)



## unique
unique = 
  icr_processed %>% 
  group_by(Proposal_ID, Class1, molecular_formula) %>% 
  dplyr::mutate(n = n())

gg_vankrev_unique = 
unique %>% 
  filter(n == 2) %>% 
  ggplot(aes(x = OC, y = HC))+
  geom_point(size = 1, color = "grey90", alpha = 0.4)+
  geom_point(data = unique %>% filter(n == 1), size = 1, aes(color = Class1))+
  
  class_rect+
  rect_label+
  scale_color_manual(values = whistledown_palette("queen", 9))+
  facet_wrap(~Core_Section)+
  NULL






# -------------------------------------------------------------------------

rel_abundance = 
  icr_processed %>% 
  group_by(Proposal_ID, Sampling_Set, Core_Section, sample_name, Class1) %>% 
  dplyr::summarise(count = n()) %>% 
  group_by(Proposal_ID, Sampling_Set, Core_Section, sample_name) %>% 
  dplyr::mutate(total = sum(count),
                relabund = 100 * count/total,
                relabund = round(relabund, 2)
  ) %>% 
  mutate(Core_Section = factor(Core_Section, levels = c("TOP", "BTM"))) %>% 
  ungroup()

rel_abundance %>% 
  dplyr::select(sample_name, Class1, relabund) %>% 
  pivot_wider(names_from = "Class1", values_from = "relabund") %>% 
  knitr::kable()

gg_relabund = 
rel_abundance %>% 
  ggplot(aes(x = Core_Section, y = relabund, fill = Class1)) +
  geom_bar(stat = "identity")+
 # facet_wrap(~Proposal_ID)+
  scale_fill_manual(values = whistledown_palette("queen", 9))


cowplot::plot_grid(gg_vankrev_unique + theme(legend.position = "none"), gg_relabund + theme(legend.position = "right"), 
                   rel_widths = c(2, 1), align = "hv", axis = "bt",
                   labels = c("A", "B"))
  

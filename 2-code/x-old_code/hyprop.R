options(scipen = 9999)
hyprop_params = read.csv("1-data/L1_Hyprop_Processed_Mastersheet.csv")


x = runif(2000, min = 10^-4, max = 10^6)

x1 = runif(500, min = 10^-4, max = 10)
x2 = runif(5000, min = 10, max = 10^3)
x3 = runif(5000, min = 10^3, max = 10^5)
x4 = runif(5000, min = 10^5, max = 10^8)
x_all = c(x1, x2, x3, x4)

hyprop_wrc = 
  cross_join(hyprop_params, x_all, copy = T) %>% 
  filter(Proposal_ID == "61389") %>% 
  filter(Sampling_Set %in% c(3, 21, 24)) %>% 
  rename(h = y) %>% 
  mutate(m = 1 - (1/n),
         theta = theta_r + (theta_s - theta_r) / (1 + (alpha * h)**n)**m)


hyprop_wrc %>% 
  filter(Proposal_ID == "61389") %>% 
  filter(Sampling_Set %in% c(3, 21, 24)) %>% 
  ggplot(aes(x = h, y = theta, color = as.character(Sampling_Set)))+
  geom_point()+
  scale_x_log10(limits = c(0.1, 10^7))+
  facet_wrap(~Proposal_ID)


    ##  
    ##  theta_r = 0.05
    ##  theta_s = 0.40
    ##  alpha = 0.015  # 1/cm
    ##  n = 2.5
    ##  m = 1 - 1/n
    ##  
    ##  # Suction range (logarithmic space from 1 to 1,000,000 cm)
    ##  h = np.logspace(0, 6, 100)
    ##  
    ##  # Van Genuchten Equation
    ##  theta = theta_r + (theta_s - theta_r) / (1 + (alpha * x)**n)**m
    ##  plot(x, theta)
    ##  
    ##  df = 
    ##    as.data.frame(x_all) %>% 
    ##    drop_na() %>% 
    ##    mutate(theta = theta_r + (theta_s - theta_r) / (1 + (alpha * x_all)**n)**m)
    ##  
    ##  df %>% ggplot(aes(x=x_all, y = theta))+
    ##    geom_point()+
    ##   # geom_line()+
    ##    scale_x_log10()
    ##  
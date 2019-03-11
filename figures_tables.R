### Risk of being killed by police in the U.S. by age, race/ethnicity, and sex
### Frank Edwards, Hedwig Lee, Michael Esposito
rm(list=ls()); gc()
library(tidyverse)
library(xtable)
library(lubridate)

theme_set(theme_minimal())

### read and format data
nvss_dat<-read_csv("./data/mort_cause.csv")
pop<-read_csv("./data/pop_nat.csv")
fe<-read_csv("./data/fe_pop_imputed_08_18.csv")
tot_mort<-read_csv("./data/total_mort.csv")### filter for matching years 

pop<-pop%>%
  mutate(race = 
           case_when(
             race=="amind" ~ "American Indian/AK Native",
             race=="black" ~ "African American",
             race=="asian" ~ "Asian/Pacific Islander",
             race=="latino" ~ "Latinx",
             race=="white" ~ "White"
           ))

nvss_dat<-nvss_dat%>%
  mutate(age = 
           ifelse(
             age == "Missing", "85+", age
           ))%>% # 6431 deaths over period are missing age. Assigning to 85+
  left_join(pop)

tot_mort<-tot_mort%>%
  left_join(pop)

##########################################
### Make life tables
##########################################
### note that lifetable scripts want a data.frame
### called dat with .imp, race, sex, age, deaths, and pop
######### For use of force deaths
dat<-fe%>%
  rename(deaths = officer_force)
source("fe_lifetable.R")

force_tables<-fe_tables

### for + vehicle
dat<-fe%>%
  mutate(deaths = officer_force + vehicle)
source("fe_lifetable.R")

force_vehicle_tables<-fe_tables

### for + other
dat<-fe%>%
  mutate(deaths = officer_force + vehicle + other)

source("fe_lifetable.R")

force_vehicle_other_tables<-fe_tables

### for + suicide
dat<-dat%>%
  mutate(deaths = officer_force + vehicle + other + suicide)

source("fe_lifetable.R")

fe_all_tables<-fe_tables

### make lifetime cumulative risk by race, year, sex
### for each fe data frame

fe_cumul_force<-force_tables%>%
  filter(age=="85+")%>%
  group_by(race, sex)%>%
  summarise(cmin=quantile(c, 0.05)*1e5, 
            cmax=quantile(c, 0.95)*1e5, 
            c=mean(c)*1e5)%>%
  ungroup()

fe_cumul_force_vehicle<-force_vehicle_tables%>%
  filter(age=="85+")%>%
  group_by(race, sex)%>%
  summarise(cmin=quantile(c, 0.05)*1e5, 
            cmax=quantile(c, 0.95)*1e5, 
            c=mean(c)*1e5)%>%
  ungroup()

fe_cumul_force_vehicle_other<-force_vehicle_other_tables%>%
  filter(age=="85+")%>%
  group_by(race, sex)%>%
  summarise(cmin=quantile(c, 0.05)*1e5, 
            cmax=quantile(c, 0.95)*1e5, 
            c=mean(c)*1e5)%>%
  ungroup()

fe_cumul_all<-fe_all_tables%>%
  filter(age=="85+")%>%
  group_by(race, sex)%>%
  summarise(cmin=quantile(c, 0.05)*1e5, 
            cmax=quantile(c, 0.95)*1e5, 
            c=mean(c)*1e5)%>%
  ungroup()

### make pooled age-specific risk across imputations
age_range<-force_tables%>%
  group_by(race, sex, age)%>%
  summarise(qmin=quantile(q, 0.05), 
            qmax=quantile(q, 0.95), 
            q = mean(q),
            cmin = quantile(q, 0.05), 
            cmax = quantile(c, 0.95), 
            c = mean(c))

####################################################################################
### total mortality age/race/sex specific
####################################################################################
### MAIN ANALYSES USE FORCE DEATHS
### SET UP WITH TRAFFIC / SUICIDE IN APPX
fe_tables<-force_tables

#cause_mort<-read.csv("./data/mort_cause.csv", stringsAsFactors = FALSE)


####################################################################################
### plots
####################################################################################
### transform age var for better plotting, convert to numeric with last number

### MAKE AGE SPECIFIC PERIOD RISK TABLES

age_period_pct<-fe%>%
  group_by(age, sex, race, year, .imp)%>%
  summarise(officer_force = sum(officer_force))%>%
  left_join(tot_mort)%>%
  filter(!(is.na(pop)))%>% # remove 2018 FE data, NVSS 2018 not yet released
  group_by(age, sex, race, .imp)%>%
  summarise(ratio = sum(officer_force) / sum(deaths))%>%
  ungroup()%>%
  group_by(age, sex, race)%>%
  summarise(ratio_mean = mean(ratio), 
            ratio_lwr = quantile(ratio, 0.05),
            ratio_upr = quantile(ratio, 0.95))%>%
  arrange(desc(ratio_mean))%>%
  ungroup()

age_period<-fe%>%
  left_join(pop)%>%
  group_by(age, sex, race,.imp)%>%
  summarise(rate = sum(officer_force) / sum(pop))%>%
  ungroup()%>%
  group_by(age, sex, race)%>%
  summarise(q =mean(rate),
            q_lwr = quantile(rate, 0.05),
            q_upr = quantile(rate, 0.95))%>%
  ungroup()%>%
  arrange(desc(q))

age_period_pct<-age_period_pct%>%
  mutate(age = as.character(age)) %>%
  mutate(age = 
           case_when(
             age == "0" ~ "0",
             age =="85+" ~ "85",
             nchar(age)==3 ~ substr(age, 3, 3),
             nchar(age)==5 ~ substr(age, 4, 5)
           )
  )%>%
  mutate(age = as.numeric(age))%>%
  arrange(race, sex, age)

age_period<-age_period%>%
  mutate(age = as.character(age)) %>%
  mutate(age = 
           case_when(
             age == "0" ~ "0",
             age =="85+" ~ "85",
             nchar(age)==3 ~ substr(age, 3, 3),
             nchar(age)==5 ~ substr(age, 4, 5)
           )
  )%>%
  mutate(age = as.numeric(age))%>%
  arrange(race, sex, age)


###########################
## AGE SPECIFIC RISK PLOTS
###########################

age_period %>%
  ggplot(
    aes(
      x = age,
      y = q * 1e5, 
      ymin = q_lwr * 1e5, 
      ymax = q_upr * 1e5,
      color = race, 
      fill = race,
      group = race
    )
  ) +
  #geom_ribbon(aes(fill=race), color = 'grey100', alpha = 0.15, size = 1.25) +
  geom_line() +
  facet_wrap(~sex) +
  xlab("Age") +
  ylab("Risk of being killed by police (per 100,000)") + 
  theme_minimal() + 
  theme(legend.title = element_blank(),
        legend.position = "bottom") +
  geom_errorbar(width = 0, alpha = 0.5) +
  geom_point(size = 0.4)+
  guides(col = guide_legend(override.aes = list(shape = 15, size = 5)))+
  ggsave("vis/age_spec_prob.pdf", width = 6, height = 3.5)


ggplot(age_period_pct,
       aes(x=age, 
           y=ratio_mean * 100, 
           ymin = ratio_lwr * 100,
           ymax = ratio_upr * 100,
           color=race, 
           group = race))+
  geom_line() +
  facet_wrap(~sex)+
  xlab("Age")+
  ylab("Police killings as percent of all deaths") +  
  theme_minimal() + 
  theme(legend.title = element_blank(),
        legend.position = "bottom") +
  geom_errorbar(width = 0, alpha = 0.5) +
  geom_point(size = 0.4)+
  guides(col = guide_legend(override.aes = list(shape = 15, size = 5)))+
  ggsave("vis/age_pct.pdf", width = 6, height = 3.5)

#### pooled years, cumulative prob (expected deaths per 100k through 85yrs)

ggplot(data = fe_cumul_force,
       mapping =  aes(fill = sex,
           x = reorder(race, c),
           y = ifelse(sex=="Male",
                      -c, 
                      c),
           ymax = ifelse(sex=="Male",
                      -cmax, 
                      cmax),
           ymin = ifelse(sex=="Male",
                         -cmin, 
                         cmin))) + 
  geom_bar(stat = "identity") + 
  geom_linerange(size = 1,  alpha = 0.5) + 
  scale_y_continuous(limits = max(fe_cumul_force$cmax) * c(-1,1), 
                     labels = abs) +
  labs(fill = "Sex") + 
  ylab("People killed by police per 100,000 births") +
  xlab("") + 
  coord_flip() + 
  theme_minimal()+
  ggsave("./vis/pooled_lifetime.pdf", width = 6, height = 3.5)

white<-fe_cumul_force%>%
  filter(race=="White")
ineq<-fe_cumul_force%>%
  filter(race!="White")

ineq<-ineq%>%
  mutate(dmin = cmin / white$cmin,
         dmax = cmax / white$cmax,
         d = c  /white$c)

ggplot(ineq,
       aes(fill = sex,
           x = reorder(race,d),
           y = ifelse(sex == "Male",
                      -d, d), 
           ymax = ifelse(sex == "Male",
                         -dmax, dmax), 
           ymin = ifelse(sex == "Male",
                         -dmin, dmin))) +
  geom_bar(stat = "identity") + 
  geom_linerange(size = 1, alpha = 0.5) + 
  scale_y_continuous(limits = max(ineq$dmax) *c(-1,1),
                     labels = abs) + 
  labs(fill = "Sex") + 
  ylab("Mortality rate ratio (relative to white)") + 
  xlab("") + 
  coord_flip()+
  theme_minimal() + 
  ggsave("./vis/lifetime_ineq.pdf", width = 6, height = 3.5)

write_csv(ineq, "./vis/lifetime_ineq.csv")  
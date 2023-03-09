library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(readr)
library(lubridate)

# detach("package:rsofun", unload = TRUE)
library(rsofun)

## Parameters ------------------------
pars <- list(
  
  # P-model
  kphio                 = 0.08,
  soilm_par_a           = 0.0,
  soilm_par_b           = 0.73300,
  tau_acclim_tempstress = 7.35259044,
  par_shape_tempstress  = 0.09863961,
  
  # Plant
  f_nretain             = 0.500000,
  fpc_tree_max          = 0.950000,
  growtheff             = 0.600000,
  r_root                = 2*0.913000,
  r_sapw                = 2*0.044000,
  exurate               = 0.003000,
  
  k_decay_leaf          = 1.90000,
  k_decay_root          = 1.90000,
  k_decay_labl          = 1.90000,
  k_decay_sapw          = 1.90000,
  
  r_cton_root           = 37.0000,
  r_cton_wood           = 100.000,
  r_cton_seed           = 15.0000,
  nv_vcmax25            = 5000.0,
  ncw_min               = 0.056,
  r_n_cw_v              = 0.2,
  r_ctostructn_leaf     = 80.0000,
  kbeer                 = 0.400000,
  
  # Phenology (should be PFT-specific)
  gddbase               = 5.0,
  ramp                  = 0.0,
  phentype              = 2.0,
  
  # Soil physics (should be derived from params_soil, fsand, fclay, forg, fgravel)
  perc_k1               = 5.0,        
  thdiff_wp             = 0.2,          
  thdiff_whc15          = 0.8,
  thdiff_fc             = 0.4,          
  forg                  = 0.01,
  wbwp                  = 0.029,  
  por                   = 0.421,    
  fsand                 = 0.82,      
  fclay                 = 0.06,      
  fsilt                 = 0.12,  
  
  # Water and energy balance
  kA                    = 107,     
  kalb_sw               = 0.17,    
  kalb_vis              = 0.03,    
  kb                    = 0.20,    
  kc                    = 0.25,    
  kCw                   = 1.05,    
  kd                    = 0.50,    
  ke                    = 0.0167,  
  keps                  = 23.44,   
  kWm                   = 220.0,   
  kw                    = 0.26,    
  komega                = 283.0,
  maxmeltrate           = 3.0,
  
  # Soil BGC
  klitt_af10            = 1.2,
  klitt_as10            = 0.35,
  klitt_bg10            = 0.35,
  kexu10                = 50.0,
  ksoil_fs10            = 0.021,
  ksoil_sl10            = 7.0e-04,
  ntoc_crit1            = 0.45,
  ntoc_crit2            = 0.76,
  cton_microb           = 10.0,
  cton_soil             = 9.77,
  fastfrac              = 0.985,
  
  # N uptake
  # eff_nup               = 0.600000,  # original value
  eff_nup               = 0.005000,
  minimumcostfix        = 1.000000,
  fixoptimum            = 25.15000,
  a_param_fix           = -3.62000,
  b_param_fix           = 0.270000,
  
  # Inorganic N transformations
  maxnitr               = 0.1,
  non                   = 0.01,
  n2on                  = 0.0005,
  kn                    = 83.0,
  kdoc                  = 17.0,
  docmax                = 1.0,
  dnitr2n2o             = 0.01,
  
  # Additional parameters - previously forgotten
  beta                  = 146.000000,
  rd_to_vcmax           = 0.01400000,
  tau_acclim            = 10,
  
  # for development
  tmppar                = 9999,
  
  # simple N uptake module parameters
  nuptake_kc            = 250,
  nuptake_kv            = 5,
  nuptake_vmax          = 0.2
  
)


## Forcing ------------------------
## add new required columns to forcing 
tmp <- rsofun::p_model_drivers |> 
  mutate(forcing = purrr::map(forcing, ~mutate(., 
                                               fharv = 0.0,
                                               dno3 = 0.1,
                                               dnh4 = 0.1
  )))

### Harvesting and seed input ----------
use_cseed <- 0 # 100
cn_seed <- 20
use_nseed <- use_cseed / cn_seed

tmp$forcing[[1]] <- tmp$forcing[[1]] |>
  mutate(fharv = ifelse(month(date) == 7 & mday(date) == 15, 0.0, 0.0),
         cseed = ifelse(month(date) == 3 & mday(date) == 15, use_cseed, 0.0),
         nseed = ifelse(month(date) == 3 & mday(date) == 15, use_nseed, 0.0)) 

## check visually
tmp$forcing[[1]] |>
  ggplot(aes(date, fharv)) +
  geom_line()

## no spinup, 1 year transient run
tmp$params_siml[[1]]$spinupyears <- 2000
tmp$params_siml[[1]]$recycle <- 5


## Synthetic forcing: Constant climate in all days -----------------------
df_growingseason_mean <- tmp$forcing[[1]] |>
  filter(temp > 5) |>
  summarise(across(where(is.double), .fns = mean))
df_mean <- tmp$forcing[[1]] |>
  summarise(across(where(is.double), .fns = mean))

tmp$forcing[[1]] <- tmp$forcing[[1]] |>
  mutate(temp = df_growingseason_mean$temp,
         prec = df_mean$prec,
         vpd = df_growingseason_mean$vpd,
         ppfd = df_mean$ppfd,
         patm = df_growingseason_mean$patm,
         ccov_int = df_growingseason_mean$ccov_int,
         ccov = df_growingseason_mean$ccov,
         snow = df_mean$snow,
         rain = df_mean$rain,
         fapar = df_mean$fapar,
         co2 = df_growingseason_mean$co2,
         tmin = df_growingseason_mean$tmin,
         tmax = df_growingseason_mean$tmax,
  )

##  repeat last year's forcing N times -----------------------
n_ext <- 100
df_tmp <- tmp$forcing[[1]]
for (idx in seq(n_ext)){
  df_tmp <- bind_rows(
    df_tmp,
    df_tmp |>
      tail(365) |>
      mutate(date = date + years(1))
  )
}
tmp$params_siml[[1]]$nyeartrend <- tmp$params_siml[[1]]$nyeartrend + n_ext
tmp$forcing[[1]] <- df_tmp


## increase Ndep from 2010 -----------------------
elevate_ndep <- function(day){
  yy <- 1 - 1 / (1 + exp(0.03*(day-14610)))
  return(yy)
}

ggplot() +
  geom_function(fun = elevate_ndep) +
  xlim(12000, 16000) +
  geom_vline(xintercept = 0, linetype = "dotted")

tmp$forcing[[1]] <- tmp$forcing[[1]] |>
  mutate(date2 = as.numeric(date)) |>
  mutate(dno3 = dno3 + 1.0 * elevate_ndep(date2),
         dnh4 = dnh4 + 1.0 * elevate_ndep(date2)) |>
  select(-date2)

tmp$forcing[[1]] |>
  head(3000) |>
  ggplot(aes(date, dno3 + dnh4)) +
  geom_line()


## Model run ------------------------
output <- runread_pmodel_f(
  tmp,
  par = pars
) 

output <- output$data[[1]]

## Visualisations  ------------------------
### Time series ---------------------------
gg1 <- output |> 
  as_tibble() |> 
  # ggplot(aes(date, (1-exp(-pars$kbeer * lai)) )) +
  ggplot(aes(date, lai)) +
  geom_line()
gg2 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, cleaf)) + 
  geom_line()
gg3 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, cleaf/nleaf)) + 
  geom_line()
gg4 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, croot/cleaf)) + 
  geom_line()

gg1 / gg2 / gg3 / gg4

gg5 <- output |>  
  as_tibble() |> 
  ggplot(aes(date, x1)) + 
  geom_line()
gg6 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, x2)) + 
  geom_line()
gg7 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, x3)) + 
  geom_line()
gg8 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, x4)) + 
  geom_line()

gg5 / gg6 / gg7 / gg8

gg9 <- output |>  
  as_tibble() |> 
  ggplot(aes(date, pnh4 + pno3)) + 
  geom_line()
gg10 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, en2o)) + 
  geom_line()
gg11 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, nup)) + 
  geom_line()
gg12 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, netmin)) + 
  geom_line()

gg9 / gg10 / gg11 / gg12

gg13 <- output |>  
  as_tibble() |> 
  ggplot(aes(date, cleaf/nleaf)) + 
  geom_line()
gg14 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, croot/nroot)) + 
  geom_line()
gg15 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, npp/nup)) + 
  geom_line()
gg16 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, nloss/nup)) + 
  geom_line()

gg13 / gg14 / gg15 / gg16


### Response ratios ---------------------------
df_out <- output |> 
  mutate(leaf_cn = cleaf/nleaf, 
         root_shoot = croot/cleaf, 
         n_inorg = pno3 + pnh4,
         anpp = npp_leaf + npp_wood, 
         bnpp = npp_root + cex) |> 
  select(date, asat, gpp, vcmax, jmax, gs = gs_accl, narea, leaf_cn, lai, cleaf, 
         croot, root_shoot, nup, n_inorg, anpp, bnpp)

df_amb <- df_out |> 
  filter(year(date) < 2010) |> 
  summarise(across(where(is.numeric), mean))

df_ele <- df_out |> 
  filter(year(date) %in% 2010:2015) |> 
  summarise(across(where(is.numeric), mean))

df_ele2 <- df_out |> 
  filter(year(date) %in% 2100:2110) |> 
  summarise(across(where(is.numeric), mean))

df_exp <- bind_rows(df_amb, df_ele)
df_rr  <- log(df_exp[2,]/df_exp[1,]) |> 
  pivot_longer(cols = everything(), names_to = "variable", values_to = "response") |> 
  mutate(variable = factor(variable, 
                           levels = rev(c("asat", "gpp", "vcmax", "jmax", "gs", "narea", 
                                          "leaf_cn", "lai", "cleaf", "anpp",
                                          "croot", "bnpp", "root_shoot", "nup", 
                                          "n_inorg"))))

df_exp2 <- bind_rows(df_amb, df_ele2)
df_rr2  <- log(df_exp2[2,]/df_exp2[1,]) |> 
  pivot_longer(cols = everything(), names_to = "variable", values_to = "response") |> 
  mutate(variable = factor(variable, 
                           levels = rev(c("asat", "gpp", "vcmax", "jmax", "gs", "narea", 
                                          "leaf_cn", "lai", "cleaf", "anpp",
                                          "croot", "bnpp", "root_shoot", "nup", 
                                          "n_inorg"))))

ggrr <- ggplot() +
  geom_point(aes(variable, response), data = df_rr2, size = 2, color = "grey50") +
  geom_point(aes(variable, response), data = df_rr, size = 2) +
  geom_hline( yintercept = 0.0, size = 0.5, linetype = "dotted" ) +
  labs(x = "Variable", y = "Log Response Ratio") +
  coord_flip() +
  labs(title = "cnmodel prediction", subtitle = "Response to N-fertilization")

ggsave(paste0(here::here(), "/fig/response_nfert_cnmodel.pdf"))


## Write output to file --------------------
readr::write_csv(as_tibble(output), file = paste0(here::here(), "/data/output_cnmodel_nfert.csv"))

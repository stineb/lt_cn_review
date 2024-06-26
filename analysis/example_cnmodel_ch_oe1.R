library(dplyr)
library(tidyr)
library(rsofun)
library(ggplot2)
library(patchwork)
library(readr)
library(lubridate)
library(ingestr)

## Parameters ------------------------
pars <- list(

  # P-model
  kphio                 = 0.06,       # setup ORG in Stocker et al. 2020 GMD
  kphio_par_a           = -0.001,        # set to zero to disable temperature-dependence of kphio
  kphio_par_b           = 20.0,
  soilm_thetastar       = 0.6 * 240,  # to recover old setup with soil moisture stress
  soilm_betao           = 0.0,
  beta_unitcostratio    = 146.0,
  rd_to_vcmax           = 0.014,      # value from Atkin et al. 2015 for C3 herbaceous
  tau_acclim            = 30.0,
  kc_jmax               = 0.41,

  # Plant
  f_nretain             = 0.500000,
  fpc_tree_max          = 0.950000,
  growtheff             = 0.600000,
  r_root                = 2*0.913000,
  r_sapw                = 2*0.044000,
  exurate               = 0.003000,

  k_decay_leaf          = 3,
  k_decay_root          = 3,
  k_decay_labl          = 3,
  k_decay_sapw          = 0.01,

  r_cton_root           = 37.0000,
  r_cton_wood           = 350,
  r_cton_seed           = 15.0000,
  nv_vcmax25            = 0.02 * 13681.77, # see ln_cn_review/vignettes/analysis_leafn_vcmax_field.Rmd, l.695; previously: 5000.0,
  ncw_min               = 0.056, #0.08 * 1.116222, # see ln_cn_review/vignettes/analysis_leafn_vcmax_field.Rmd, l.691; previously used: 0.056,
  r_n_cw_v              = 1.23223, #0, # assumed that LMA is independent of Vcmax25; previously: 0.1,
  r_ctostructn_leaf     = 40, #1.3 * 45.84125, # see ln_cn_review/vignettes/analysis_leafn_vcmax_field.Rmd, l.699; previously used: 80.0000,
  kbeer                 = 0.500000,

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
  frac_leaf             = 0.5,           # after wood allocation
  frac_wood             = 0.0,           # highest priority in allocation
  frac_avl_labl         = 0.1,

  # for development
  tmppar                = 9999,

  # simple N uptake module parameters
  nuptake_kc            = 250,
  nuptake_kv            = 5,
  nuptake_vmax          = 0.2,

  # wood allocation fraction
  falloc_wood           = 0.0

)


# # hand-tuned to work reasonably
# pars <- list(
#   
#   # P-model
#   kphio                 = 0.08,       # setup ORG in Stocker et al. 2020 GMD
#   kphio_par_a           = -0.001,        # set to zero to disable temperature-dependence of kphio
#   kphio_par_b           = 20.0,
#   soilm_thetastar       = 0.6 * 240,  # to recover old setup with soil moisture stress
#   soilm_betao           = 0.0,
#   beta_unitcostratio    = 146.0,
#   rd_to_vcmax           = 0.014,      # value from Atkin et al. 2015 for C3 herbaceous
#   tau_acclim            = 30.0,
#   kc_jmax               = 0.41,
#   
#   # Plant
#   f_nretain             = 0.500000,
#   fpc_tree_max          = 0.950000,
#   growtheff             = 0.600000,
#   r_root                = 2*0.913000,
#   r_sapw                = 2*0.044000,
#   exurate               = 0.003000,
#   
#   k_decay_leaf          = 1,
#   k_decay_root          = 1,
#   k_decay_labl          = 0.5,
#   k_decay_sapw          = 0.01,
#   
#   r_cton_root           = 37.0000,
#   r_cton_wood           = 350,
#   r_cton_seed           = 15.0000,
#   nv_vcmax25            = 0.02 * 13681.77, # see ln_cn_review/vignettes/analysis_leafn_vcmax_field.Rmd, l.695; previously: 5000.0,
#   ncw_min               = 0.056, #0.08 * 1.116222, # see ln_cn_review/vignettes/analysis_leafn_vcmax_field.Rmd, l.691; previously used: 0.056,
#   r_n_cw_v              = 1.23223, #0, # assumed that LMA is independent of Vcmax25; previously: 0.1,
#   r_ctostructn_leaf     = 40, #1.3 * 45.84125, # see ln_cn_review/vignettes/analysis_leafn_vcmax_field.Rmd, l.699; previously used: 80.0000,
#   kbeer                 = 0.500000,
#   
#   # Phenology (should be PFT-specific)
#   gddbase               = 5.0,
#   ramp                  = 0.0,
#   phentype              = 2.0,
#   
#   # Soil physics (should be derived from params_soil, fsand, fclay, forg, fgravel)
#   perc_k1               = 5.0,
#   thdiff_wp             = 0.2,
#   thdiff_whc15          = 0.8,
#   thdiff_fc             = 0.4,
#   forg                  = 0.01,
#   wbwp                  = 0.029,
#   por                   = 0.421,
#   fsand                 = 0.82,
#   fclay                 = 0.06,
#   fsilt                 = 0.12,
#   
#   # Water and energy balance
#   kA                    = 107,
#   kalb_sw               = 0.17,
#   kalb_vis              = 0.03,
#   kb                    = 0.20,
#   kc                    = 0.25,
#   kCw                   = 1.05,
#   kd                    = 0.50,
#   ke                    = 0.0167,
#   keps                  = 23.44,
#   kWm                   = 220.0,
#   kw                    = 0.26,
#   komega                = 283.0,
#   maxmeltrate           = 3.0,
#   
#   # Soil BGC
#   klitt_af10            = 1.2,
#   klitt_as10            = 0.35,
#   klitt_bg10            = 0.35,
#   kexu10                = 50.0,
#   ksoil_fs10            = 0.021,
#   ksoil_sl10            = 7.0e-04,
#   ntoc_crit1            = 0.45,
#   ntoc_crit2            = 0.76,
#   cton_microb           = 10.0,
#   cton_soil             = 9.77,
#   fastfrac              = 0.985,
#   
#   # N uptake
#   # eff_nup               = 0.600000,  # original value
#   eff_nup               = 0.005000,
#   minimumcostfix        = 1.000000,
#   fixoptimum            = 25.15000,
#   a_param_fix           = -3.62000,
#   b_param_fix           = 0.270000,
#   
#   # Inorganic N transformations
#   maxnitr               = 0.1,
#   non                   = 0.01,
#   n2on                  = 0.0005,
#   kn                    = 83.0,
#   kdoc                  = 17.0,
#   docmax                = 1.0,
#   dnitr2n2o             = 0.01,
#   
#   # Additional parameters - previously forgotten
#   frac_leaf             = 0.5,           # after wood allocation
#   frac_wood             = 0.5,           # highest priority in allocation
#   frac_avl_labl         = 0.1,
#   
#   # for development
#   tmppar                = 9999,
#   
#   # simple N uptake module parameters
#   nuptake_kc            = 250,
#   nuptake_kv            = 1,
#   nuptake_vmax          = 1.0
# )

## CH-Oe1 forcing -------------------
filnam <- here::here("data/df_drivers_ch_oe1.rds")
overwrite <- FALSE

if (!file.exists(filnam) || overwrite){
  
  df_drivers_ch_oe1 <- read_rds("~/data/FluxDataKit/rsofun_driver_data_clean.rds") |> 
    filter(sitename == "CH-Oe1")
  
  df_ndep <- ingest(
    df_drivers_ch_oe1 |>
      unnest(site_info) |>
      select(sitename, lon, lat) |>
      mutate(year_start = min(lubridate::year(df_drivers_ch_oe1$forcing[[1]]$date)),
             year_end = max(lubridate::year(df_drivers_ch_oe1$forcing[[1]]$date))),
    source    = "ndep",
    timescale = "y",
    dir       = "~/data/ndep_lamarque/",
    verbose   = FALSE
  )
  
  df_ndep_mean <- df_ndep |>
    unnest(data) |>
    summarise(noy = mean(noy), nhx = mean(nhx))

  ## add new required columns to forcing
  use_cseed <- 5
  cn_seed <- 20
  use_nseed <- use_cseed / cn_seed
  
  df_drivers_ch_oe1 <- df_drivers_ch_oe1 |>
    mutate(forcing = purrr::map(forcing, ~mutate(.,
                                                 fharv = 0.0,
                                                 dno3 = df_ndep_mean$noy,
                                                 dnh4 = df_ndep_mean$nhx)),
           forcing = purrr::map(forcing, ~mutate(.,
                                                 fharv = ifelse(month(date) == 7 & mday(date) == 15, 0.0, 0.0),
                                                 cseed = ifelse(month(date) == 2 & mday(date) == 15, use_cseed, 0.0),
                                                 nseed = ifelse(month(date) == 2 & mday(date) == 15, use_nseed, 0.0))))
  
  df_drivers_ch_oe1$params_siml[[1]]$spinupyears <- 2002
  df_drivers_ch_oe1$params_siml[[1]]$recycle <- 5
  
  write_rds(df_drivers_ch_oe1, file = filnam)
  
} else {
  
  df_drivers_ch_oe1 <- readRDS(filnam)
  
}

df_drivers <- df_drivers_ch_oe1

## Define whether to use interactive C-N cycling
df_drivers$params_siml[[1]]$c_only <- FALSE

### Synthetic forcing: Mean seasonal cycle -----------------------
df_drivers$forcing[[1]] <- df_drivers$forcing[[1]] |>
  filter(!(lubridate::month(date) == 2 & lubridate::mday(date) == 29))
df_meanann <- df_drivers$forcing[[1]] |>
  mutate(doy = lubridate::yday(date)) |>
  group_by(doy) |>
  summarise(across(where(is.double), .fns = mean)) |>
  filter(!(doy == 366))
nyears <- df_drivers$forcing[[1]] |>
  mutate(year = lubridate::year(date)) |>
  pull(year) |>
  unique() |>
  length()
df_drivers$forcing[[1]] <- purrr::map_dfr(
  as.list(seq(nyears)),
  ~{df_meanann}) |>
  mutate(date = df_drivers$forcing[[1]]$date)

# ### Synthetic forcing: Constant climate in all days -----------------------
# df_growingseason_mean <- df_drivers$forcing[[1]] |>
#   filter(temp > 5) |>
#   summarise(across(where(is.double), .fns = mean))
# df_mean <- df_drivers$forcing[[1]] |>
#   summarise(across(where(is.double), .fns = mean))
# 
# df_drivers$forcing[[1]] <- df_drivers$forcing[[1]] |>
#   mutate(temp = df_growingseason_mean$temp,
#          prec = df_mean$prec,
#          vpd = df_growingseason_mean$vpd,
#          ppfd = df_mean$ppfd,
#          patm = df_growingseason_mean$patm,
#          ccov_int = df_growingseason_mean$ccov_int,
#          ccov = df_growingseason_mean$ccov,
#          snow = df_mean$snow,
#          rain = df_mean$rain,
#          fapar = df_mean$fapar,
#          co2 = df_growingseason_mean$co2,
#          tmin = df_growingseason_mean$tmin,
#          tmax = df_growingseason_mean$tmax,
#   )

# ###  repeat last year's forcing N times -----------------------
# n_ext <- 100
# df_df_drivers <- df_drivers$forcing[[1]]
# for (idx in seq(n_ext)){
#   df_df_drivers <- bind_rows(
#     df_df_drivers,
#     df_df_drivers |>
#       tail(365) |>
#       mutate(date = date + years(1))
#   )
# }
# df_drivers$params_siml[[1]]$nyeartrend <- df_drivers$params_siml[[1]]$nyeartrend + n_ext
# df_drivers$forcing[[1]] <- df_df_drivers

# ### increase CO2 from 2010 -----------------------
# elevate_co2 <- function(day){
#   yy <- 2 - 1 / (1 + exp(0.03*(day-14610)))
#   return(yy)
# }
# 
# ggplot() +
#   geom_function(fun = elevate_co2) +
#   xlim(12000, 16000) +
#   geom_vline(xintercept = 0, linetype = "dotted")
# 
# df_drivers$forcing[[1]] <- df_drivers$forcing[[1]] |>
#   mutate(date2 = as.numeric(date)) |>
#   mutate(co2 = co2 * elevate_co2(date2)) |>
#   select(-date2)
# 
# df_drivers$forcing[[1]] |>
#   head(3000) |>
#   ggplot(aes(date, co2)) +
#   geom_line()

## Model run ------------------------
output <- runread_cnmodel_f(
  df_drivers,
  par = pars
  )

output <- output$data[[1]]

## Visualisations  ------------------------
### Time series ---------------------------
gg1 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, 1-exp(-0.5 * lai))) + 
  geom_line()
gg1 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, lai)) + 
  geom_line()
gg2 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, cleaf)) + 
  geom_line()
gg3 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, clabl)) + 
  geom_line()
gg4 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, cleaf/(cleaf + croot))) + 
  geom_line()

gg1 / gg2 / gg3 / gg4

gg5 <- output |>  
  as_tibble() |> 
  ggplot(aes(date, cleaf)) + 
  geom_line()
gg6 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, croot)) + 
  geom_line() +
  ylim(0,300)
gg7 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, cwood)) + 
  geom_line()
gg8 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, clabl)) + 
  geom_line()

gg5 / gg6 / gg7 / gg8

# debugging vegetation crash
gg9 <- output |>  
  as_tibble() |> 
  ggplot(aes(date, pnh4 + pno3)) + 
  geom_line()
gg10 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, npp)) + 
  geom_line()
  ylim(0,1)
gg11 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, nup)) + 
  geom_line()
gg12 <- output |> 
  as_tibble() |> 
  ggplot(aes(date, netmin)) + 
  geom_line()

gg9 / gg10 / gg11 / gg12

output |> 
  as_tibble() |> 
  ggplot(aes(date, x1)) + 
  geom_line()

## CUE
output |> 
  as_tibble() |> 
  mutate(year = lubridate::year(date)) |> 
  group_by(year) |> 
  summarise(across(where(is.numeric), sum)) |> 
  ggplot(aes(year, npp/gpp)) + 
  geom_line()


calc_f_seed <- function(an_unitlai_diff_damped){
  yy <- 1 / (1 + exp(1000*(an_unitlai_diff_damped)))
  return(yy)
}

ggplot() +
  geom_function(fun = calc_f_seed) +
  xlim(-0.02,0.02) +
  # geom_vline(xintercept = 1, linetype = "dotted") +
  geom_vline(xintercept = 0, linetype = "dotted")

ftemp_kphio <- function(temp, a){(1 + a*(temp - 20)^2)}

ggplot() + 
  geom_function(fun = ftemp_kphio, args = list(a = -0.001)) +
  xlim(0, 30)

# df <- tibble(
#   x = 1:15,
#   y = c(2.75753609E-06, 1.42544932E-05, 2.04479511E-05, 1.85851095E-05, 2.37835593E-05, 2.47478038E-05, 9.18351452E-06, 2.34256640E-05, 1.13146407E-05, 2.28059034E-05, 6.91168907E-06, 2.24883406E-05, 2.22943618E-05, 2.46384789E-05, 2.53433227E-05)
# )
# lm(y ~ x, data = df)

# N2O
ggplot() + 
  geom_line(data = output, aes(date, en2o))

## read (experimental) files
aout <- read_fwf(file = "out/out_rsofun.a.csoil.txt", col_types = "in") |>
  setNames(c("year", "csoil")) |>
  left_join(
    read_fwf(file = "out/out_rsofun.a.nsoil.txt", col_types = "in") |>
      setNames(c("year", "nsoil")),
    by = "year"
  )

aout |>
  # slice(1000:2008) |> 
  ggplot(aes(year, csoil)) +
  geom_line()

aout |>
  ggplot(aes(year, nsoil)) +
  geom_line()


# ## Test plots
# output |> 
#   as_tibble() |> 
#   ggplot(aes(date, gpp)) + 
#   geom_line()
# 
output |>
  as_tibble() |>
  ggplot() +
  geom_line(aes(date, npp))
  # geom_line(aes(date, gpp-drd), color = 'red')

output |>
  as_tibble() |>
  ggplot(aes(date, cex)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, cleaf)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, croot)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, clabl)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, nlabl)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, nleaf)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, pnh4 + pno3)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, drd/gpp)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, cleaf/nleaf)) +
  geom_line()

r_cton_leaf <- mean(output$cleaf / output$nleaf, na.rm = TRUE)
output |>
  as_tibble() |>
  ggplot(aes(cleaf, nleaf)) +
  geom_point() +
  geom_abline(slope = 1/r_cton_leaf, intercept = 0, color = "red", linetype = "dotted")

output |>
  as_tibble() |>
  ggplot(aes(cleaf, cleaf/nleaf)) +
  geom_point()

output |>
  as_tibble() |>
  ggplot(aes(cleaf/nleaf, ..density..)) +
  geom_histogram()

output |>
  as_tibble() |>
  ggplot(aes(date, lai)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, fapar)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, csoil)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, en2o)) +
  geom_line()

output |>
  as_tibble() |>
  ggplot(aes(date, croot)) +
  geom_line()
# 
# gg1 <- output |> 
#   as_tibble() |> 
#   slice(1:500) |> 
#   ggplot(aes(date, drd)) + 
#   geom_line()
# 
# gg2 <- output |> 
#   as_tibble() |> 
#   slice(1:500) |> 
#   ggplot(aes(date, drd/gpp)) + 
#   geom_line()
# 
output |>
  as_tibble() |>
  mutate(cue = npp/gpp) |>
  slice(1:500) |>
  ggplot(aes(date, cue)) +
  geom_line()
# 
# gg1/
#   gg2/
#   gg3
# 
# output |> 
#   as_tibble() |> 
#   mutate(year = lubridate::year(date)) |> 
#   group_by(year) |> 
#   summarise(npp = sum(npp, na.rm = TRUE), gpp = sum(gpp, na.rm = TRUE)) |> 
#   mutate(cue = npp/gpp) |> 
#   ggplot(aes(year, cue)) + 
#   geom_line()
# 
# print(gg)
# 
# print(paste("Maximum leaf C: ", max(output$cleaf)))
# 



# 
# cue_stress <- function(cue){
#   yy <- 1 / (1 + exp(10*(cue+0.25)))
#   return(yy)  
# }
# 
# ggplot() +
#   geom_function(fun = cue_stress) +
#   xlim(-5,1) +
#   geom_vline(xintercept = 1, linetype = "dotted") +
#   geom_vline(xintercept = 0, linetype = "dotted")
# 
# df_drivers <- read_fwf(
#     "~/rsofun/test.txt",
#     fwf_widths(c(19,18,18), c("cue", "cue_damped", "f_deactivate")),
#     skip = 1,
#     col_types = "nn") |> 
#   tail(6000)
# 
# gg1 <- df_drivers |>
#   mutate(id = 1:n()) |> 
#   ggplot() +
#   geom_line(aes(id, cue)) +
#   geom_line(aes(id, cue_damped), color = "red") +
#   ylim(-1,1)
# gg2 <- df_drivers |>
#   mutate(id = 1:n()) |> 
#   ggplot() +
#   geom_line(aes(id, f_deactivate))
# gg1/
#   gg2
# 
# 
# # source("analysis/get_fill_seeds.R")
# # 
# # df_fill_seeds <- get_fill_seeds(
# #   output$gpp,
# #   output$drd,
# #   output$lai,
# #   lubridate::yday(output$date)
# #   )
# # 
# # df <- bind_cols(
# #   output,
# #   df_fill_seeds
# # )
# # 
# # gg1 <- df |> 
# #   slice(1:365) |> 
# #   ggplot(aes(date, gpp)) +
# #   geom_line()
# # 
# # gg2 <- df |> 
# #   slice(1:365) |> 
# #   ggplot() +
# #   geom_line(aes(date, (gpp-drd)/lai)) +
# #   geom_line(aes(date, an_max), color = "red") +
# #   geom_line(aes(date, an_unitlai_damped), color = "royalblue")
# # 
# # gg1/gg2

### Response ratios ---------------------------
df_out <- output |> 
  mutate(leaf_cn = cleaf/nleaf, root_shoot = croot/cleaf, n_inorg = pno3 + pnh4) |> 
  select(date, gpp, vcmax, jmax, gs = gs_accl, leaf_cn, lai, cleaf, 
         croot, root_shoot, nup, n_inorg)
  
df_amb <- df_out |> 
  filter(year(date) < 2010) |> 
  summarise(across(where(is.numeric), mean))

df_ele <- df_out |> 
  filter(year(date) %in% 2010:2012) |> 
  summarise(across(where(is.numeric), mean))

df_ele2 <- df_out |> 
  filter(year(date) %in% 2100:2107) |> 
  summarise(across(where(is.numeric), mean))

df_exp <- bind_rows(df_amb, df_ele)
df_rr  <- log(df_exp[2,]/df_exp[1,]) |> 
  pivot_longer(cols = everything(), names_to = "variable", values_to = "response") |> 
  mutate(variable = factor(variable, 
                          levels = rev(c("gpp", "vcmax", "jmax", "gs", "leaf_cn", "lai", "cleaf", 
                                       "croot", "root_shoot", "nup", "n_inorg"))))

df_exp2 <- bind_rows(df_amb, df_ele2)
df_rr2  <- log(df_exp2[2,]/df_exp2[1,]) |> 
  pivot_longer(cols = everything(), names_to = "variable", values_to = "response") |> 
  mutate(variable = factor(variable, 
                           levels = rev(c("gpp", "vcmax", "jmax", "gs", "leaf_cn", "lai", "cleaf", 
                                          "croot", "root_shoot", "nup", "n_inorg"))))

ggplot() +
  geom_point(aes(variable, response), data = df_rr2, size = 2, color = "grey50") +
  geom_point(aes(variable, response), data = df_rr, size = 2) +
  geom_hline( yintercept = 0.0, linewidth = 0.5, linetype = "dotted" ) +
  labs(x = "Variable", y = "Log Response Ratio") +
  coord_flip() +
  labs(title = "cnmodel prediction", subtitle = "Response to eCO2")

saveRDS(output, file = "tmp/output_cnmodel_ch_oe1.rds")

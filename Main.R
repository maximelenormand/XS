# Load packages
library(sp)
library(rgeos)
library(rgdal)
library(RPostgreSQL)
library(DescTools)
library(transport)
library(reshape2)
library(tidyverse)

# Option
options(scipen=10000)

# Working directory
wd="xs"
setwd(wd)

# Load functions
source("XS.R")

# Info postgis database
host="localhost"
port="5432"
db="XS"
user="maxime"
mdp=""

# Info country
country="country"
epsg="3035"

# Info simu
city="city"
xcenter=3718827
ycenter=2930702
shape="square"   # only square and circle available for now (TO IMPROVE) 
radius=30000     # radius should be a multiple of scale (TO FIX)
scale=2000

# Run
result=XS(country, city, xcenter, ycenter, shape, radius, scale, host, port, db, user, mdp)






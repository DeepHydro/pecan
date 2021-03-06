# 3. Create TRY sites in BETY.
source("common.R")
load("try.2.RData")

# a. Cast latitudes, longitudes, and data names
latlon <- c("Latitude", "Longitude")
keep.cols <- c("DataName", "StdValue", "ObservationID")
try.latlon.all <- try.dat[DataName %in% latlon, keep.cols, with=F][!is.na(StdValue)]
try.latlon.cast <- dcast(try.latlon.all, ObservationID ~ DataName,
                         value.var = "StdValue",
                         fun.aggregate = mean, na.rm=TRUE)

# b. Assign each unique lat-lon pair a unique location.id -- := .GRP, by=list(Latitude,Longitude)
try.latlon.cast[, latlon.id := .GRP, by=list(Latitude, Longitude)]
latlon.unique <- try.latlon.cast[, .N, by=c(latlon, "latlon.id")][,c(latlon, "latlon.id"),with=F]

# c. Determie sites using cluster analysis, and create unique site.id
radius <- 0.05   # Search radius, in degrees -- 0.4 corresponds to about 31 km at 45 N
hc.latlon <- hclust(dist(latlon.unique))
clusters.latlon <- cutree(hc.latlon, h = radius)
latlon.unique[, try.site.id := paste0("TRY_SITE_", clusters.latlon)]

# This computes the site centroid, which is just the mean latitude and longitude for all points in the site
latlon.unique[, c("site.Latitude", "site.Longitude") := list(mean(Latitude, na.rm=TRUE),
                                                             mean(Longitude, na.rm=TRUE)), by=try.site.id]
latlon.unique <- latlon.unique[!(is.na(Latitude) | is.na(Longitude))]

# Merge back into try.latlon.cast
setkey(latlon.unique, latlon.id)
setkey(try.latlon.cast, latlon.id)
try.latlon.merge <- try.latlon.cast[latlon.unique[,list(latlon.id, try.site.id, 
                                                        site.Latitude, site.Longitude)]]

# d. Append location.id and site.id to full data set by merging on ObservationID
setkey(try.latlon.merge, ObservationID)
setkey(try.dat, ObservationID)
try.dat <- try.dat[try.latlon.merge[,list(ObservationID, latlon.id, try.site.id,
                                          site.Latitude, site.Longitude)]]

# e. Create data.table for site creation:
#   sitename = "TRY_SITE_<site.id>"
#   notes = "TRY_DATASETS = <dataset IDs>"
#   geometry = ST_GeomFromText('POINT(lat, lon)', 4263)
try.sites <- try.dat[, paste("TRY_DATASETS =", paste(unique(DatasetID), collapse=" ")),
                     by=list(try.site.id, site.Latitude, site.Longitude)]
setnames(try.sites, "V1", "notes")
try.sites[, bety.site.id := as.character(NA)]
bety.site.index <- which(names(try.sites) == "bety.site.id")

# f. Loop over rows... 
radius.query.string <- 'SELECT id, sitename, ST_Y(ST_Centroid(geometry)) AS lat, ST_X(ST_Centroid(geometry)) AS lon, ST_Distance(ST_Centroid(geometry), ST_SetSRID(ST_MakePoint(%2$f, %1$f), 4326)) as distance FROM sites WHERE ST_Distance(ST_Centroid(geometry), ST_SetSRID(ST_MakePoint(%2$f, %1$f), 4326)) <= %3$f'
insert.query.string <- "INSERT INTO sites(sitename,notes,geometry,user_id,created_at,updated_at) VALUES('%s','%s',ST_Force3D(ST_SetSRID(ST_MakePoint(%f, %f), 4326)),'%s', NOW(), NOW() ) RETURNING id;"

message("Looping over sites and adding to BETY")
pb <- txtProgressBar(0, nrow(try.sites), style=3)
for(r in 1:nrow(try.sites)){
  # Check site centroid against BETY.
  site.lat <- try.sites[r, site.Latitude]
  site.lon <- try.sites[r, site.Longitude]
  search.df <- try(db.query(sprintf(radius.query.string, site.lat, site.lon, radius), con))
  if(class(search.df) == "try-error"){
    warning("Error querying database.")
    next
  }
  if(nrow(search.df) > 0){
    search.df <- search.df[order(search.df$distance),]
    rownames(search.df) <- 1:nrow(search.df)
    newsite <- FALSE
    ## Select closest existing site automatically, if it's within the radius.
    bety.site.id <- as.character(search.df[1,"id"])
    ## TODO: Alternative is to select sites manually at each step, as implemented below.
    ## Print site options and allow user to select site
#     search.df$site.lat <- site.lat
#     search.df$site.lon <- site.lon
#     print(search.df)
#     user.input <- readline("Select site row number or type 'n' to create a new site: ")
#     if(tolower(user.input) == "n"){
#       newsite <- TRUE
#     } else {
#       user.choice <- as.numeric(user.input)
#       bety.site.id <- as.character(search.df[user.choice, "id"])
#     }
  } else {
    newsite <- TRUE
  }
  if(newsite){
    ## Create new site from centroid
    sitename <- try.sites[r, try.site.id]
    notes <- try.sites[r, notes]
    bety.side.id <- db.query(sprintf(insert.query.string, sitename, notes, site.lon, site.lat, user_id), con)$id
  }
  # Append "site_id" to try.sites
  set(try.sites, i=r, j=bety.site.index, value=bety.site.id)
  setTxtProgressBar(pb, r)
}

# Merge bety.site.id back into try.dat
setkey(try.dat, try.site.id)
setkey(try.sites, try.site.id)
try.dat <- try.dat[try.sites[, list(try.site.id, bety.site.id)]]
print(try.dat[sample(1:nrow(try.dat), 20), list(ObservationID, try.site.id, bety.site.id)])

save(try.dat, file="try.3.RData", compress=TRUE)

#   TODO: In the future, change centroid to bounding box containing all sites?
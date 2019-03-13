# Load packages
library(RPostgreSQL)

# Working directory
wd="xs"
setwd(wd)

# Create database
#system("sudo -u postgres createdb -O maxime XS")
#system("sudo -u postgres psql -c 'CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology;' XS")

# Info postgis database
host="localhost"
port="5432"
db="XS"
user="maxime"
mdp=""

# Info dataset
country="country"
epsg="3035"

# Create vrt
res="<OGRVRTDataSource>"
res=c(res, paste0("    <OGRVRTLayer name='", country,"'>"))
res=c(res, paste0("        <SrcDataSource> ", country,".csv</SrcDataSource>"))
res=c(res, paste0("        <LayerSRS>EPSG:", epsg,"</LayerSRS>"))
res=c(res, paste0("        <FID>id</FID>"))
res=c(res, paste0("        <Field name='id' src='id' type='Integer'></Field>"))
res=c(res, paste0("        <Field name='weight' src='weight' type='Real'></Field>"))
res=c(res, paste0("        <GeometryField name='orig' encoding='PointFromColumns' x='X_Ori' y='Y_Ori'>"))
res=c(res, paste0("            <GeometryType>wkbPoint</GeometryType>"))
res=c(res, paste0("            <SRS>EPSG:", epsg,"</SRS>"))
res=c(res, paste0("        </GeometryField>"))
res=c(res, paste0("        <GeometryField name='dest' encoding='PointFromColumns' x='X_Des' y='Y_Des'>"))
res=c(res, paste0("            <GeometryType>wkbPoint</GeometryType>"))
res=c(res, paste0("            <SRS>EPSG:", epsg,"</SRS>"))
res=c(res, paste0("        </GeometryField>"))
res=c(res, paste0("    </OGRVRTLayer>"))
res=c(res, paste0("</OGRVRTDataSource>"))

write.table(res, paste0(country, ".vrt"), col.names=FALSE, row.names=FALSE, quote=FALSE)

# Import table in postgis
system(paste0("ogr2ogr -overwrite -f PostgreSQL PG:'dbname=", db, " user=", user, " password=", mdp, "' -nln '", country,"' '", country, ".vrt' -lco 'SPATIAL_INDEX=NO' --config PG_USE_COPY YES"))

# Spatial index & vaccuum
drv=dbDriver("PostgreSQL")
con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
    dbSendQuery(con, paste("CREATE INDEX ", country, "_orig_gist_idx ON ", country, " USING GIST (orig);", sep=""))
    dbSendQuery(con, paste("CREATE INDEX ", country, "_dest_gist_idx ON ", country, " USING GIST (dest);", sep=""))
    dbSendQuery(con, paste("VACUUM ANALYZE ", country, ";", sep=""))
dbDisconnect(con)



XS=function(country, city, xcenter, ycenter, shape, radius, scale, host, port, db, user, mdp){

       # Name
       idsim=paste(country, city, xcenter, ycenter, shape, radius, scale, sep="_") 

       buf=paste("buf", idsim, sep="_")
       grid=paste("grid", idsim, sep="_")
       div=paste("div", idsim, sep="_")

       # Create buffer
       drv=dbDriver("PostgreSQL")
       con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
           dbSendQuery(con, paste0("DROP TABLE IF EXISTS ", buf, ";"))
           dbSendQuery(con, paste0("CREATE TABLE ", buf, "(id SERIAL PRIMARY KEY , geom geometry(Polygon,", epsg,"));"))
           dbSendQuery(con, paste0("CREATE INDEX ON ", buf, " USING GIST(geom);"))
       dbDisconnect(con)

       if(shape=="circle"){
           drv=dbDriver("PostgreSQL")
           con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
               dbSendQuery(con, paste0("INSERT INTO ", buf, " VALUES (1, ST_Buffer(ST_GeomFromText('POINT(", xcenter, " ", ycenter,")',", epsg,"), ", radius,"));"))
               dbSendQuery(con, paste("VACUUM ANALYZE ", buf, ";", sep=""))
           dbDisconnect(con)
       }
       if(shape=="square"){
           drv=dbDriver("PostgreSQL")
           con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
               dbSendQuery(con, paste0("INSERT INTO ", buf, " VALUES (1, ST_Expand(ST_GeomFromText('POINT(", xcenter, " ", ycenter,")',", epsg,"), ", radius,"));"))
               dbSendQuery(con, paste("VACUUM ANALYZE ", buf, ";", sep=""))
           dbDisconnect(con)
       }

       # Create grid
       minx=xcenter-radius
       maxx=xcenter+radius
       miny=ycenter-radius
       maxy=ycenter+radius

       extx=maxx-minx
       exty=maxy-miny

       width=trunc(extx/scale)+1 
       height=trunc(exty/scale)+1

       newextx=width*scale
       newexty=height*scale

       minx=minx-(newextx-extx)/2
       miny=miny-(newexty-exty)/2

       drv=dbDriver("PostgreSQL")
       con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
	   dbSendQuery(con, paste("DROP TABLE IF EXISTS ", grid,";", sep="")) 
           dbSendQuery(con, paste("CREATE TABLE ", grid," (id serial primary key,geom geometry(polygon,", epsg,"));", sep=""))
	   dbSendQuery(con, paste("CREATE INDEX ON ", grid," using gist (geom);", sep=""))
	   dbSendQuery(con, paste("INSERT INTO ", grid," (geom) SELECT (ST_PixelAsPolygons(ST_AddBand(ST_MakeEmptyRaster(", width,",", height,",", minx,",", miny,", ", scale,", ", scale,", 0, 0, ", epsg,"), '8BSI'::text, 1, 0), 1, false)).geom;", sep=""))            
	   dbSendQuery(con, paste("VACUUM ANALYZE ", grid,";", sep=""))
       dbDisconnect(con) 


       # Intersect buf with grid to obtain the final div
       drv=dbDriver("PostgreSQL")
       con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
           dbSendQuery(con, paste0("DROP TABLE IF EXISTS ", div, ";"))
           dbSendQuery(con, paste0("CREATE TABLE ", div, "(id serial primary key, geom geometry(Polygon,", epsg,"));"))
           dbSendQuery(con, paste0("CREATE INDEX ON ", div, " USING GIST(geom);"))
           dbSendQuery(con, paste0("INSERT INTO ", div, "(geom) SELECT ", grid,".geom FROM ", grid,", ", buf," WHERE ST_Intersects(", buf,".geom, ", grid,".geom);"))
           dbSendQuery(con, paste("VACUUM ANALYZE ", div, ";", sep=""))
       dbDisconnect(con)

       drv=dbDriver("PostgreSQL")
       con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
           dbSendQuery(con, paste("ALTER TABLE ", div, " ADD X double precision;", sep=""))
           dbSendQuery(con, paste("ALTER TABLE ", div, " ADD Y double precision;", sep=""))
           dbSendQuery(con, paste("ALTER TABLE ", div, " ADD Area double precision;", sep=""))
           dbSendQuery(con, paste("UPDATE ", div, " SET X = ST_X(ST_Centroid(geom));", sep=""))
           dbSendQuery(con, paste("UPDATE ", div, " SET Y = ST_Y(ST_Centroid(geom));", sep=""))
           dbSendQuery(con, paste("UPDATE ", div, " SET Area = ST_Area(geom);", sep=""))  
       dbDisconnect(con)

       # Export and import the spatial object div
       system(paste("pgsql2shp -f ", div, ".shp -h ", host, " -u ", user, " -P ", mdp, " ", db, " ", div , sep=""))
       shp=readOGR(dsn = paste0(div, ".shp"), layer = paste0(div), encoding = "Latin1", stringsAsFactors = FALSE)

       # Extract OD
       drv=dbDriver("PostgreSQL")
       con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
           OD=dbGetQuery(con, paste0("SELECT g_orig.id AS idfrom, g_dest.id AS idto, SUM(d.weight) AS w FROM ", div," AS g_orig, ", div," AS g_dest, ", country," AS d WHERE ST_INTERSECTS(g_orig.geom, d.orig) AND ST_INTERSECTS(g_dest.geom, d.dest) GROUP BY g_orig.id, g_dest.id;"))
       dbDisconnect(con)

       colnames(OD)=c("from","to","w")

       id=c(OD[,1],OD[,2])
       id=sort(id[!duplicated(id)])
       x=cbind(id,id,0)
       colnames(x)=c("from","to","w")
       OD=rbind(OD,x)

       OD=xtabs(w ~ from + to, data=OD)
       matflows=as.matrix.xtabs(OD)

       # Round matflows (TO IMPROVE)
       matflows=round(matflows)

       # Compute Euclidean distances
       shp=shp[!is.na(match(shp@data[,1],id)),]

       matcost=as.matrix(dist(shp@data[,2:3]))

       # DROP TABLES
       drv=dbDriver("PostgreSQL") # drop table if any
       con=dbConnect(drv, dbname=db, host=host, port=port, user=user, password=mdp)
           dbSendQuery(con, paste0("DROP TABLE ",buf, ", ", grid,", ", div)) 
       dbDisconnect(con)

       file.remove(paste(div, ".shp",sep=""))
       file.remove(paste(div, ".shx",sep=""))
       file.remove(paste(div, ".dbf",sep=""))
       file.remove(paste(div, ".prj",sep=""))
       file.remove(paste(div, ".cpg",sep=""))

       # Compute matmin
       matmin=ExcessCommuting(matflows, round(matcost/1000, 3))

       # Compute matrand
       matrand=RandomCommuting(matflows)

       # Output
       result=list(idsim=idsim, matflows=matflows, matcost=matcost, matmin=matmin, matrand=matrand, shp=shp)

       return(result)
 
}

# ExcessCommuting
ExcessCommuting <- function(matflows, matcost){
  if(nrow(matflows) == ncol(matflows) & nrow(matcost) == ncol(matcost) & nrow(matflows) == nrow(matcost)){
    n = nrow(matflows)
  } else {
    stop("Check the matrix size (equal size square matrices")
  }
  
  lpResult <- transport(a = apply(matflows, 1, sum), b = apply(matflows, 2, sum), costm = matcost) 
  lpResult$from <- factor(x = lpResult$from, levels = 1:nrow(matflows), labels = 1:nrow(matflows))
  lpResult$to <- factor(x = lpResult$to, levels = 1:nrow(matflows), labels = 1:nrow(matflows))
  lpWide <- dcast(data = lpResult, formula = from ~ to, fill = 0, drop = FALSE, value.var = "mass")
  matMin <- as.matrix(lpWide[, -1])

  return(matMin)
}

# RandomCommuting
RandomCommuting <- function(matflows){
  linSum <- apply(matflows, 1, sum)
  colSum <- apply(matflows, 2, sum)
  lengthMarg <- length(linSum)
  dim(linSum) <- c(lengthMarg, 1)
  dim(colSum) <- c(1, lengthMarg)
  matRand <- (linSum %*% colSum) / sum(linSum)
  row.names(matRand) <- colnames(matRand) <- colnames(matRand)
  return(matRand)
}



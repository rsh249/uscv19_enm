#ecospat functions need to be local to run parallel
# or some other error that is fixed by sourcing this file in your session
#


### FUNCTIONS BELOW BORROWED FROM library(ecospat) to solve parallel error...

overlap.eq.gen <- function(repi, z1, z2) {
  if (is.null(z1$y)) {
    # overlap on one axis
    
    occ.pool <- c(z1$sp, z2$sp)  # pool of random occurrences
    rand.row <- sample(1:length(occ.pool), length(z1$sp))  # random reallocation of occurrences to datasets
    sp1.sim <- occ.pool[rand.row]
    sp2.sim <- occ.pool[-rand.row]
  }
  
  if (!is.null(z1$y)) {
    # overlap on two axes
    
    occ.pool <- rbind(z1$sp, z2$sp)  # pool of random occurrences
    row.names(occ.pool)<-c()  # remove the row names
    rand.row <- sample(1:nrow(occ.pool), nrow(z1$sp))  # random reallocation of occurrences to datasets
    sp1.sim <- occ.pool[rand.row, ]
    sp2.sim <- occ.pool[-rand.row, ]
  }
  
  z1.sim <- ecospat.grid.clim.dyn(z1$glob, z1$glob1, data.frame(sp1.sim), R = length(z1$x))  # gridding
  z2.sim <- ecospat.grid.clim.dyn(z2$glob, z2$glob1, data.frame(sp2.sim), R = length(z2$x))
  
  o.i <- ecospat.niche.overlap(z1.sim, z2.sim, cor = TRUE)  # overlap between random and observed niches
  sim.o.D <- o.i$D  # storage of overlaps
  sim.o.I <- o.i$I
  return(c(sim.o.D, sim.o.I))
}

test_ecospat.niche.equivalency.test <- function(z1, z2, rep, alternative = "greater", ncores=1) {
  
  R <- length(z1$x)
  l <- list()
  
  obs.o <- ecospat.niche.overlap(z1, z2, cor = TRUE)  #observed niche overlap
  
  if (ncores == 1){
    sim.o <- as.data.frame(matrix(unlist(lapply(1:rep, overlap.eq.gen, z1, z2)), byrow = TRUE,
                                  ncol = 2))  #simulate random overlap
  }else{
    #number of cores attributed for the permutation test
    cl <- makeCluster(ncores)  #open a cluster for parallelization
    invisible(clusterEvalQ(cl,library("ecospat")))  #import the internal function into the cluster
    sim.o <- as.data.frame(matrix(unlist(parLapply(cl, 1:rep, overlap.eq.gen, z1, z2)), byrow = TRUE,
                                  ncol = 2))  #simulate random overlap
    stopCluster(cl)  #shutdown the cluster
  }
  colnames(sim.o) <- c("D", "I")
  l$sim <- sim.o  # storage
  l$obs <- obs.o  # storage
  
  if (alternative == "greater") {
    l$p.D <- (sum(sim.o$D >= obs.o$D) + 1)/(length(sim.o$D) + 1)  # storage of p-values alternative hypothesis = greater -> test for niche conservatism/convergence
    l$p.I <- (sum(sim.o$I >= obs.o$I) + 1)/(length(sim.o$I) + 1)  # storage of p-values alternative hypothesis = greater -> test for niche conservatism/convergence
  }
  if (alternative == "lower") {
    l$p.D <- (sum(sim.o$D <= obs.o$D) + 1)/(length(sim.o$D) + 1)  # storage of p-values alternative hypothesis = lower -> test for niche divergence
    l$p.I <- (sum(sim.o$I <= obs.o$I) + 1)/(length(sim.o$I) + 1)  # storage of p-values alternative hypothesis = lower -> test for niche divergence
  }
  
  return(l)
}

test_ecospat.niche.similarity.test <- function(z1, z2, rep, alternative = "greater", rand.type = 1, ncores = 1) {
  
  R <- length(z1$x)
  l <- list()
  obs.o <- ecospat.niche.overlap(z1, z2, cor = TRUE)  #observed niche overlap
  z1$z.uncor <- as.matrix(z1$z.uncor)
  z1$Z <- as.matrix(z1$Z)
  z1$z <- as.matrix(z1$z)
  z2$z.uncor <- as.matrix(z2$z.uncor)
  z2$Z <- as.matrix(z2$Z)
  z2$z <- as.matrix(z2$z)
  
  if (ncores==1) {
    sim.o <- as.data.frame(matrix(unlist(lapply(1:rep, overlap.sim.gen, z1, z2, rand.type = rand.type)),
                                  byrow = TRUE, ncol = 2))  #simulate random overlap  
  } else {
    cl <- makeCluster(ncores)  #open a cluster for parallelization
    invisible(clusterEvalQ(cl,library("ecospat")))  #import the internal function into the cluster
    sim.o <- as.data.frame(matrix(unlist(parLapply(cl, 1:rep, overlap.sim.gen, z1, z2, rand.type = rand.type)),
                                  byrow = TRUE, ncol = 2))  #simulate random overlap
    stopCluster(cl)  #shutdown the cluster
  }
  colnames(sim.o) <- c("D", "I")
  l$sim <- sim.o  # storage
  l$obs <- obs.o  # storage
  
  if (alternative == "greater") {
    l$p.D <- (sum(sim.o$D >= obs.o$D) + 1)/(length(sim.o$D) + 1)  # storage of p-values alternative hypothesis = greater -> test for niche conservatism/convergence
    l$p.I <- (sum(sim.o$I >= obs.o$I) + 1)/(length(sim.o$I) + 1)  # storage of p-values alternative hypothesis = greater -> test for niche conservatism/convergence
  }
  if (alternative == "lower") {
    l$p.D <- (sum(sim.o$D <= obs.o$D) + 1)/(length(sim.o$D) + 1)  # storage of p-values alternative hypothesis = lower -> test for niche divergence
    l$p.I <- (sum(sim.o$I <= obs.o$I) + 1)/(length(sim.o$I) + 1)  # storage of p-values alternative hypothesis = lower -> test for niche divergence
  }
  
  return(l)
}

overlap.sim.gen <- function(repi, z1, z2, rand.type = rand.type) {
  R1 <- length(z1$x)
  R2 <- length(z2$x)
  if (is.null(z1$y) & is.null(z2$y)) {
    if (rand.type == 1) {
      # if rand.type = 1, both z1 and z2 are randomly shifted, if rand.type =2, only z2 is randomly
      # shifted
      center.z1 <- which(z1$z.uncor == 1)  # define the centroid of the observed niche
      Z1 <- z1$Z/max(z1$Z)
      rand.center.z1 <- sample(1:R1, size = 1, replace = FALSE, prob = Z1)  # randomly (weighted by environment prevalence) define the new centroid for the niche
      xshift.z1 <- rand.center.z1 - center.z1  # shift on x axis
      z1.sim <- z1
      z1.sim$z <- rep(0, R1)  # set intial densities to 0
      for (i in 1:length(z1$x)) {
        i.trans.z1 <- i + xshift.z1
        if (i.trans.z1 > R1 | i.trans.z1 < 0)
          (next)()  # densities falling out of the env space are not considered
        z1.sim$z[i.trans.z1] <- z1$z[i]  # shift of pixels
      }
      z1.sim$z <- (z1$Z != 0) * 1 * z1.sim$z  # remove densities out of existing environments
      z1.sim$z.cor <- (z1.sim$z/z1$Z)/max((z1.sim$z/z1$Z), na.rm = TRUE)  #transform densities into occupancies
      z1.sim$z.cor[which(is.na(z1.sim$z.cor))] <- 0
      z1.sim$z.uncor <- z1.sim$z/max(z1.sim$z, na.rm = TRUE)
      z1.sim$z.uncor[which(is.na(z1.sim$z.uncor))] <- 0
    }
    
    center.z2 <- which(z2$z.uncor == 1)  # define the centroid of the observed niche
    Z2 <- z2$Z/max(z2$Z)
    rand.center.z2 <- sample(1:R2, size = 1, replace = FALSE, prob = Z2)  # randomly (weighted by environment prevalence) define the new centroid for the niche
    
    xshift.z2 <- rand.center.z2 - center.z2  # shift on x axis
    z2.sim <- z2
    z2.sim$z <- rep(0, R2)  # set intial densities to 0
    for (i in 1:length(z2$x)) {
      i.trans.z2 <- i + xshift.z2
      if (i.trans.z2 > R2 | i.trans.z2 < 0)
        (next)()  # densities falling out of the env space are not considered
      z2.sim$z[i.trans.z2] <- z2$z[i]  # shift of pixels
    }
    z2.sim$z <- (z2$Z != 0) * 1 * z2.sim$z  # remove densities out of existing environments
    z2.sim$z.cor <- (z2.sim$z/z2$Z)/max((z2.sim$z/z2$Z), na.rm = TRUE)  #transform densities into occupancies
    z2.sim$z.cor[which(is.na(z2.sim$z.cor))] <- 0
    z2.sim$z.uncor <- z2.sim$z/max(z2.sim$z, na.rm = TRUE)
    z2.sim$z.uncor[which(is.na(z2.sim$z.uncor))] <- 0
  }
  
  if (!is.null(z2$y) & !is.null(z1$y)) {
    if (rand.type == 1) {
      # if rand.type = 1, both z1 and z2 are randomly shifted, if rand.type =2, only z2 is randomly
      # shifted
      centroid.z1 <- which(z1$z.uncor == 1, arr.ind = TRUE)[1, ]  # define the centroid of the observed niche
      Z1 <- z1$Z/max(z1$Z)
      rand.centroids.z1 <- which(Z1 > 0, arr.ind = TRUE)  # all pixels with existing environments in the study area
      weight.z1 <- Z1[Z1 > 0]
      rand.centroid.z1 <- rand.centroids.z1[sample(1:nrow(rand.centroids.z1), size = 1, replace = FALSE,
                                                   prob = weight.z1), ]  # randomly (weighted by environment prevalence) define the new centroid for the niche
      xshift.z1 <- rand.centroid.z1[1] - centroid.z1[1]  # shift on x axis
      yshift.z1 <- rand.centroid.z1[2] - centroid.z1[2]  # shift on y axis
      z1.sim <- z1
      z1.sim$z <- matrix(rep(0, R1 * R1), ncol = R1, nrow = R1)  # set intial densities to 0
      for (i in 1:R1) {
        for (j in 1:R1) {
          i.trans.z1 <- i + xshift.z1
          j.trans.z1 <- j + yshift.z1
          if (i.trans.z1 > R1 | i.trans.z1 < 0 | j.trans.z1 > R1 | j.trans.z1 < 0)
            (next)()  # densities falling out of the env space are not considered
          #if (j.trans.z1 > R1 | j.trans.z1 < 0)
          #  (next)()
          z1.sim$z[i.trans.z1, j.trans.z1] <- z1$z[i, j]  # shift of pixels
        }
      }
      z1.sim$z <- (z1$Z != 0) * 1 * z1.sim$z  # remove densities out of existing environments
      z1.sim$z.cor <- (z1.sim$z/z1$Z)/max((z1.sim$z/z1$Z), na.rm = TRUE)  #transform densities into occupancies
      z1.sim$z.cor[which(is.na(z1.sim$z.cor))] <- 0
      z1.sim$z.uncor <- z1.sim$z/max(z1.sim$z, na.rm = TRUE)
      z1.sim$z.uncor[which(is.na(z1.sim$z.uncor))] <- 0
    }
    centroid.z2 <- which(z2$z.uncor == 1, arr.ind = TRUE)[1, ]  # define the centroid of the observed niche
    Z2 <- z2$Z/max(z2$Z)
    rand.centroids.z2 <- which(Z2 > 0, arr.ind = TRUE)  # all pixels with existing environments in the study area
    weight.z2 <- Z2[Z2 > 0]
    rand.centroid.z2 <- rand.centroids.z2[sample(1:nrow(rand.centroids.z2), size = 1, replace = FALSE,
                                                 prob = weight.z2), ]  # randomly (weighted by environment prevalence) define the new centroid for the niche
    xshift.z2 <- rand.centroid.z2[1] - centroid.z2[1]  # shift on x axis
    yshift.z2 <- rand.centroid.z2[2] - centroid.z2[2]  # shift on y axis
    z2.sim <- z2
    z2.sim$z <- matrix(rep(0, R2 * R2), ncol = R2, nrow = R2)  # set intial densities to 0
    for (i in 1:R2) {
      for (j in 1:R2) {
        i.trans.z2 <- i + xshift.z2
        j.trans.z2 <- j + yshift.z2
        #if (i.trans.z2 > R2 | i.trans.z2 < 0)
        if (i.trans.z2 > R2 | i.trans.z2 < 0 | j.trans.z2 > R2 | j.trans.z2 < 0)
          (next)()  # densities falling out of the env space are not considered
        #if (j.trans.z2 > R2 | j.trans.z2 < 0)
        #  (next)()
        z2.sim$z[i.trans.z2, j.trans.z2] <- z2$z[i, j]  # shift of pixels
      }
    }
    z2.sim$z <- (z2$Z != 0) * 1 * z2.sim$z  # remove densities out of existing environments
    z2.sim$z.cor <- (z2.sim$z/z2$Z)/max((z2.sim$z/z2$Z), na.rm = TRUE)  #transform densities into occupancies
    z2.sim$z.cor[which(is.na(z2.sim$z.cor))] <- 0
    z2.sim$z.uncor <- z2.sim$z/max(z2.sim$z, na.rm = TRUE)
    z2.sim$z.uncor[which(is.na(z2.sim$z.uncor))] <- 0
  }
  
  if (rand.type == 1) {
    o.i <- ecospat.niche.overlap(z1.sim, z2.sim, cor = TRUE)
  }
  if (rand.type == 2)
  {
    o.i <- ecospat.niche.overlap(z1, z2.sim, cor = TRUE)
  }  # overlap between random and observed niches
  sim.o.D <- o.i$D  # storage of overlaps
  sim.o.I <- o.i$I
  return(c(sim.o.D, sim.o.I))
}


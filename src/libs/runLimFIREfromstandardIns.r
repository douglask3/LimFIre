runLimFIREfromstandardIns <- function(fireOnly = FALSE, remove = NULL, 
                                      ...) {
    
    
    Obs = lapply(drive_fname, stack)
	test = is.na(Obs[['npp']][[1]]) & !is.na(Obs[['alpha']][[1]])
	Obs[['npp']][test] = 0.0
    if (!is.null(remove)) for (i in remove) Obs[[i]][] = 0
    mnthIndex = 1:12#nlayers(Obs[[1]])
    
    runMonthly <- function(i) {
        cat("simulating fire for month ", i, "\n")
        
        out = LimFIRE(Obs[["npp"   ]][[i]],
                      Obs[["alpha" ]][[i]], Obs[["emc"    ]][[i]], 
                      Obs[["Lightn"]][[i]], Obs[["pas"    ]][[i]],
                      Obs[["crop"  ]][[i]], Obs[["popdens"]][[i]],
					  1.0,
                                  param(    'fuel_x0'),  param('fuel_k'    ),  
                      param('cM'), param('moisture_x0'),  -param('moisture_k'),  
                      param('cP'),
                      param('cD1'),
                                  param(   'igntions_x0'),  param('igntions_k'   ),  
                      param('cD2'), param(    'suppression_x0'),  -param('suppression_k'), fireOnly, ...)
                      
        for (i in 2:length(out)) out[[i]] = 1 - out[[i]]
        return(out)
    }
    if (fireOnly) return(layer.apply(mnthIndex, runMonthly))
    mod = runMonthly(1)
    
    Fire = mod[[1]]
    Fuel = mod[[2]]
    Moisture = mod[[3]]
    Ignitions = mod[[4]]
    Supression = mod[[5]]
    
    for (i in mnthIndex[-1]) {
        mod = runMonthly(i)
        Fire = addLayer(Fire, mod[[1]])
        Fuel = addLayer(Fuel, mod[[2]])
        Moisture = addLayer(Moisture, mod[[3]])
        Ignitions = addLayer(Ignitions, mod[[4]])
        Supression = addLayer(Supression, mod[[5]])
    }
    return(list(Fire, Fuel, Moisture, Ignitions, Supression))
}

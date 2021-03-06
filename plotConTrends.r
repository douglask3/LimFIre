#########################################################################
## cfg                                                                 ##
#########################################################################
source('cfg.r')
graphics.off()

grab_cache = TRUE

fig_fname = 'figs/Trends.png'

limitTitles = c('e) Fire', 'a) Fuel', 'b) Moisture', 'c) Ignitions', 'd) Suppression')

tempF1 = 'temp/limitations4trends-nTree'
tempF2 = 'temp/trendsFromLimitations-nTree'

tempFile <- function(fnames, extraName = '') {
	fnames = paste(fnames, extraName, sep = '')
	fnames = paste(fnames, c('fire', 'fuel', 'moisture', 'igntions', 'suppression'), '.nc', sep = '-')
}

dfire_lims = c(-5, -2, -1, -0.5, -0.2, -0.1, 0.1, 0.2, 0.5, 1, 2, 5)/100
dfire_cols = c('#000033', '#0099DD', 'white', '#DD9900', '#330000')
prob_lims = c(0.001, 0.01, 0.05)

limit_cols = list(c('magenta', 'white', 'green'), c('yellow', 'white', 'blue'), c('cyan', 'white', 'red'), c('white', '#111111'))

#########################################################################
## Run model                                                           ##
#########################################################################
tempF1 = tempFile(tempF1)
lims  = runIfNoFile(tempF1, runLimFIREfromstandardIns, raw = TRUE, test = grab_cache)
lims[[2]] = lims[[2]] -  LimFIRE.fuel(0, param('fuel_x0'), param('fuel_k'))
fire = lims[[1]]


#########################################################################
## Find  Trends                                                        ##
#########################################################################
findTrend <- function(lno, smoothFun = running12, 
				      trendFUN = Trend, removeFire = FALSE) {
	
	lims = lims[-1]
	lim  = lims[[lno]]
	lims = lims[-lno]
	return(trendFUN(lim, smoothFun, lims))
}

findTrends <- function(lims, ...) lapply(1:length(lims), findTrend, ...)
findTrendNoFile <- function(FUN, trendFUN = Trend, ..., trend1 = NULL) {
	if (is.null(trend1))
		trends = runIfNoFile(tempFile(...), findTrends, lims, FUN, trendFUN, test = grab_cache)
	else {
		trends = runIfNoFile(tempFile(...)[-1], findTrends, lims[-1], FUN, trendFUN, removeFire = TRUE, test = grab_cache)
		trends = c(trend1 * 100, trends)
	}	
	return(trends)
}

#########################################################################
## Simple Trends                                                       ##
#########################################################################	
trend12  = findTrendNoFile(running12, Trend, tempF2)

#########################################################################
## Trend removal                                                       ##
#########################################################################

trend12F = findTrendNoFile(running12, removeTrend, tempF2, trend1 = trend12[[1]], 'removeTrend')

## weigted by fire
sfire = sum(fire)
trend12FF = lapply(trend12F, function(i) i / sfire)


#########################################################################
## During fire season                                                  ##
######################################################################### 
findFireMonth <- function(yr) {
	mn = (1 + (yr -1) * 12):(yr*12)
	fmax = fire[[mn]]
	return(which.max(fmax))
}
nyrs = (nlayers(fire)/12)
fireMonths = layer.apply(1:nyrs, findFireMonth)

fireSeasonLim <- function(x, ...) {

	mask = !is.na(x[[1]])
	vx = x[mask]
	fireMonths = fireMonths[mask]
	
	xoutv = vx[,1:nyrs]
	
	for (i in 1:(dim(xoutv)[1])) for (j in 1:nyrs)  xoutv[i,j] = vx[i,fireMonths[i,j]]
	
	xout = x[[1:nyrs]]
	xout[mask] = xoutv
	return(xout)
}

#trendFS = findTrendNoFile(fireSeasonLim, Trend, tempF2,  trend1 = trend12[[1]], 'season')

#########################################################################
## Plot trends                                                         ##
######################################################################### 
plotHotspots <- function(trends, figName, limits = dfire_lims, fire_limits = limits, 
						 lims4way = NULL, ...) {
	
	#trends[[1]] = trend12[[1]] * 100
	#if (normFtrend) trends[[1]][[1]] = trends[[1]][[1]]  /sfire
	#browser()
	png(figName, height = 10, width = 8.5, units = 'in', res = 300)
		layout(rbind(2:3, 4:5, 6, c(1,8), c(7,9), 10), heights = c(1,1,0.3, 1, 0.3, 1.3))
		par(mar = rep(0,4))
		
		limits = c(list(fire_limits), rep(list(limits), 4))
		
		hotspots = mapply(plot_Trend, trends, limitTitles, limits = limits,
						  MoreArgs = list(cols = dfire_cols, ...))[-1]
		
		add_raster_legend2(cols = dfire_cols, limits = limits[[2]], ylabposScling = 2,
								   transpose = FALSE, plot_loc =  c(0.2, 0.9, 0.85, 0.99), 
								   add = FALSE, nx  = 1.75)
		
		add_raster_legend2(cols = dfire_cols, limits = fire_limits, ylabposScling = 2,
								   transpose = FALSE, plot_loc =  c(0.2, 0.9, 0.85, 0.99), 
								   add = FALSE, nx  = 1.75)
		

		hotspots = lapply(hotspots, abs)	
		all = layer.apply(hotspots, function(i) i)
		if (is.null(lims4way)) lims4way = quantile(all[], seq(0.25, 0.75, 0.25), na.rm = TRUE)
		plot_4wayLimit(hotspots, '', FALSE, cols =c("FF","BB","88","44"),
					   limits = lims4way, normalise = FALSE, ePatternRes = 30, ePatternThick = 0.35)	
		mtext.units('f) Hotspots', side = 3, line = -2.25, adj = 0.05)
		plot.new()
		clusters = layer.apply(trends[-1], function(i) i[[1]])
		
		
		mask = !any(is.na(clusters))
		cv = clusters[mask]
		
		mskV = apply(cv, 1, mean)
		mskV = !is.na(mskV) & !is.infinite(mskV)
		fit  = cascadeKM(cv[mskV, ], 1, 10)$results[2,]
		minFit = which(diff(fit) > 0)[1] + 1
		nclusters = which.max(fit[minFit:10]) + minFit - 1
		
		vclusters = matrix(NaN, dim(cv)[1])
		vclusters[mskV] = cascadeKM(cv[mskV,], nclusters, nclusters)[[1]]
		
		cols = sapply(1:as.numeric(nclusters),
					  function(cl) apply(cv[vclusters == cl,], 2,
										 function(i) list(mean(i) + c(-1,1)*sd(i))))
		
		cols = sapply(1:as.numeric(nclusters),
					  function(cl) apply(cv[vclusters == cl,], 2,
										 function(i) list(quantile(i, c(0.1, 0.9)))))
		
		cols = cbind(cols	, list(c(Productive = '#00FF00', Arid = '#FF00FF'),
								c(Drier = '#FFFF00', Wetter = '#0000FF'),
								c("More Ignitions" = '#FF0000',"Less Ignitions" = '#00FFFF'),
								c(Wilding = 0, Supressing = 2)))
		
		findCol <- function(x, cols = NULL) {
			
			if (is.null(cols)) {
				cols = tail(x, 1)[[1]]
				x =  unlist(head(x, -1))
				x = matrix(x, 2)
			}
			nms = names(cols)
			if (is.numeric(cols[1])) cols = seq(cols[1], cols[2], length.out = 3)
				else cols =  make_col_vector(cols, ncol = 3, whiteAt0 = FALSE)
			
			wmax = apply(x >= 0, 2, all)
			wmin = apply(x <= 0, 2, all)
			y = rep(cols[2], length(x))
			z = rep('', length(x))
			y[wmax] = cols[1]
			y[wmin] = cols[3]
			z[wmax] =  nms[1]
			z[wmin] =  nms[2]
			return(c(y,z))
		}
		
		cols = apply(cols, 1, findCol) 
		labs = tail(cols, nclusters)
		labs = apply(labs, 1, paste.miss.blanks, collapse = " & ")
		labs[labs == ''] = 'No Change'
		cols = head(cols, nclusters)
		
		## mean cols		
		elim = cols[,4]
        cols = apply(cols[,1:3], 1, function(i) apply(col2rgb(i), 1, mean)) /255
		cols = hex(colorspace::RGB(cols[1,], cols[2,], cols[3,]))		
		
		cols = saturate(cols, 0.2)
		clusters = clusters[[1]]
		clusters[mask] = vclusters
		
		er = clusters
        for (i in 1:nclusters) er[clusters == i] = as.numeric(elim[i])
		
		plot_raster_from_raster(clusters, y_range = c(-60, 90),
							    cols = cols,
								limits = seq(1.5, nclusters - 0.5),
							    e = er + 1, limits_error = 1:3,
                                ePatternRes = 30, ePatternThick = 0.2,
								ePointPattern = c(25, 0, 24), eThick = c(1.5, 0, 1.5),
								preLeveled = TRUE,
								aggregateFun = max, 
								add_legend = FALSE, quick = TRUE)
			
		
		legend(-180, 15, labs, pch = 15, col = cols, pt.cex = 3, bty = "n")
		col = make.transparent("black", 0.5)
		for (e in 1:3) {
			pch = c(25, 0, 24)[e]
			cex = rep(0, length(labs))
			cex[elim == (e-1)] = c(0.42, 0, 0.42)[e]
			 print(cex)
			for (i in c(-183, -180, -177)) for (j in c(12, 15, 18))
				legend(i, j, rep('', length(labs)), pch = 24,
					   col = col, pt.bg = col, pt.cex = cex, bty = "n")
		}
		
	dev.off.gitWatermark()
}

#plotHotspots(trend12  , 'figs/trend12.png'  , limits = c(-1, -0.5, -0.1, -0.05, -0.01, 0.01, 0.05, 0.1, 0.5, 1))
plotHotspots(trend12F , 'figs/trend12F.png', 
			 limits = dfire_lims * 1000,
			 fire_limits = c(-1, -0.5, -0.1, -0.05, -0.01, 0.01, 0.05, 0.1, 0.5, 1), 
			 scaling = 120)
plotHotspots(trend12FF, 'figs/trend12FF.png', limits = dfire_lims*1000,
		     fire_limits = c(-1, -0.5, -0.1, -0.05, -0.01, 0.01, 0.05, 0.1, 0.5, 1), 
			 lims4way = c(1, 10, 100), scaling = 120)
#plotHotspots(trendFS  , 'figs/trendFS.png'  , limits = dfire_lims * 100)


	
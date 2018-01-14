##################################################################
## cfg                                                          ##
##################################################################
source('cfg.r')
graphics.off()

fracSample    = 200
grabe_cache   = FALSE
obsSampleFile = paste('temp/ObsSample', fracSample, '.Rd', sep = '-')
obsLimsFile   = 'temp/ObsLimsEGs-Tree-alphasMax5.Rd'
if (file.exists(obsSampleFile) & grabe_cache) load(obsSampleFile) else {
	if (file.exists(obsLimsFile)) load(obsLimsFile) else {
		Obs        = openAllObs()
		
		fuel       = ((100 - Obs[['bare']])/100) ^ param('fuel_pw') * 
					  (param('fuel_pg') * (Obs[['alphaMax']] - 1) + 1) / (1 + param('fuel_pg'))
		
		moisture   = (Obs[['alpha']] + param('cM') * Obs[['emc']] * 0.01 + 
					  param('cMT') * Obs[['tree']] / 100) / (1 + param('cM') + param('cMT'))
		
		ignitions  = Obs[['Lightn']] + param('cP') * Obs[['pas']] + 
					 param('cD1') * Obs[['popdens']]
		#ignitions[ignitions < 1] = 1
		supression = Obs[['crop']] + param('cD2') * Obs[['popdens']]

		Obs  = c(fuel, moisture, ignitions, supression, Obs[['fire']])
		save(Obs, file = obsLimsFile)
	}
	names(Obs) = c('fuel', 'moisture', 'ignitions', 'suppression', 'fire')
	grbPntInf <- function(i) {
		cell = cellFromXY(Obs[[1]], unlist(i[1:2]))
		pntObs = sapply(Obs, function(j) j[cell])
		return(pntObs)
	}

	pntObs = lapply(hlghtPnts, grbPntInf)
	
	Obs = applySampleMask(Obs, fracSample)
	
	save(Obs, pntObs, file = obsSampleFile)
}
pntObs =  lapply(pntObs, function(i) apply(i, 2, quantile, c(0.1, 0.5, 0.9)))
#pntObs[[3]][,'ignitions'] = pntObs[[3]][,'ignitions'] * 0.5
#pntObs[[1]][,'ignitions'] = pntObs[[3]][,'ignitions'] * 2.5


plotScatter <- function(name, col, yg = NULL, FUN, dFUN, x0, k, ksc, log = '', x2pc = FALSE,...) {
	colp = make.transparent('black', 0.95)
	
	if (log == 'x') Obs[, name] = log(Obs[,name])
	if (x0 == 'suppression_x0') sc = 1 - FUN(0, param(x0), param(k)) else sc = 1
	print(sc)
	plot(Obs[, name], Obs[, 'fire'], pch = 19, col = colp, ylim = c(0.0, 1.0), xaxt = 'n', xlab = '', ylab = '', yaxt = 'n', ...)
	
	if (log == 'x') {
		mnX = exp(min(Obs[,name]))
		mxX = exp(max(Obs[,name]))
		xi = x = c(1:10) * 10^find.ndig(mnX)
		xlabi = xlab = c(1, rep(NA, 9))
		while (max(x) < mxX) {
			x = x * 10
			xlab = xlab * 10
			xi = c(xi, x)
			xlabi = c(xlabi, xlab)
		}
		
		axis(1, at = log(xi), labels = xlabi)
	} else if (x2pc) {
		at = seq(0, 1, by = 0.2)
		axis(1, at = at , labels = at * 100)
	} else axis(1)
	
	index = sort.int(Obs[,name], index.return= TRUE)[[2]]
	
	x = Obs[index, name]
	#y0 = y
	y = mapply(FUN, paramSample(x0), ksc * paramSample(k), MoreArgs=list(x = Obs[index, name]))
	y = apply(y, 1, quantile, c(0,0.5, 1)) 
	y = y / sc
	#apply(y, 2, lines, x = x, lty = 1, lwd = 2,  col = make.transparent('black', 0.98))
	apply(y, 1, lines, x = x, lty = 2)
	lines(x, y[2,])
	
	addPoints <- function(i, info, index, plotPnts = TRUE, ...) {
		col = info[[3]]
		colt = make.transparent(col, c(0.75, 0.95))
		
		x = seq(min(i[,name]), max(i[, name]), length.out = 1000)	
		y = c(rep(2, length(x)), rep(-2, length(x))); x = c(x, rev(x))
		polygon(x, y, border = colt[1], col = colt[2])
		
		x = i[2,name]
		if (is.null(yg)) {
			y = FUN(x, param(x0), ksc * param(k))	/ sc
			g = dFUN(x, param(x0), ksc * param(k), normalise= FALSE) / sc	
		} else 	{
			c(y, g) := yg[, index]
			gmax =  dFUN(param(x0), param(x0), ksc * param(k), normalise= FALSE)
			g =  g / abs(gmax * diff(par("usr")[1:2]))
		}
	
		dx = 1
		dy = dx * g
		
		dz = sqrt((dx / diff(par("usr")[1:2]))^2) + sqrt((dy / diff(par("usr")[3:4]))^2)
		
		dx = dx * 0.25 * c(-1, 1) / dz
		dy = dy * 0.25 * c(-1, 1) / dz
		
		xl = x + dx
		yl = y + dy
		
		lines(xl, yl, lwd = 3, col = col, xpd = NA, ...)
		
		if (plotPnts)
			points(x, y, col = col, pch = 16 , cex = 2.5 , lwd = 4)
		
		return(c(lim = y, sen = g))
	} 
	
	ygout = mapply(addPoints, pntObs, hlghtPnts, 1:4)	
	mapply(addPoints, pntObs, hlghtPnts, 1:4, MoreArgs = list(plotPnts = FALSE, lty = 3))
	return(ygout)
}

plotAll <- function(fname = NULL, fuel = NULL, moisture = NULL, ignitions = NULL, suppression = NULL, yticks = seq(0,1,by = 0.2)) {
	if (is.null(fname)) fname = 'figs/limLines.png'
		else fname = paste('figs/limLines', fname, '.png', sep = '-')
		
	axis4 = !is.null(fuel)	
		
	png(fname, width = 6, height = 5.5 * 1.15, units = 'in', res = 300)
	layout(rbind(1:2,3:4, 5), heights = c(1,1,0.3))

	par(mar = c(3,0.5,1,0), oma = c(0,3.5,1,3.5))

	leg <- function(pch, col, ...) 
		legend('right', legend = legNames,
			   pch = pch, col = col, lty = 2, lwd = 2, 
			   cex = 1.33, ncol = 1, bty = 'n', seg.len	= 4, ...)

	fuel = plotScatter('fuel', col = 'green', fuel,
					   LimFIRE.fuel, dLimFIRE.fuel, 
					   'fuel_x0', 'fuel_k', 1.0,  xlim = c(0, 1))
	axis(2, at = yticks)
	mtext('Vegetation Cover (%)', 1, line = 2.3)

	moisture = plotScatter('moisture', col = 'blue', moisture,
						   LimFIRE.moisture, dLimFIRE.moisture, 
						   'moisture_x0', 'moisture_k', -1.0, x2pc = TRUE)
	mtext('Fuel Mositure (%)', 1, line = 2.3)
	if (axis4) axis(side = 4, at = yticks, labels = rev(yticks))
	
	ignitions = plotScatter('ignitions', col = 'red', ignitions, 
							LimFIRE.ignitions, dLimFIRE.ignitions, 
							'igntions_x0', 'igntions_k', 1.0, xlim = c(0, 8))
	mtext('No. Ignitions', 1, line = 2.3)
	axis(2, at = yticks)

	legNames =  names(hlghtPnts)
	cols = listSelectItem(hlghtPnts, 'col')
	colt = make.transparent(cols, 0.75)

	leg(15, colt, pt.cex = 5)
	leg(16, cols, pt.cex = 2)
	
	suppression = plotScatter('suppression', col = 'black', suppression,
							  LimFIRE.supression, dLimFIRE.supression, 
							  'suppression_x0', 'suppression_k', -1.0, 
							  xlim = c(0,100))
	mtext('Suppression Index', 1, line = 2.3)
	if (axis4) axis(side = 4, at = yticks, labels = rev(yticks))

	mtext('Fractional Burnt Area', side = 2, line = 2, outer = TRUE)
	if (axis4) 
		mtext('Limitation on Burnt Area', side = 4, line = 2, outer = TRUE)
	dev.off()
	return(list(fuel, moisture, ignitions, suppression))
}

c(fuel, moisture, ignitions, suppression) := plotAll()

suppCon = 1 - LimFIRE.supression(0, param('suppression_x0'), param('suppression_k'))

#suppression[1,] = suppression[1,] / suppCon

lim = rbind(fuel[1,], moisture[1,], ignitions[1,], suppression[1,])
fni <- function(index) apply(lim[-index,], 2, prod)
fgni <- function(x, index) {
	#browser()
	#x[1, ] = 1 - fni(index) / (1 - LimFIRE.supression(0, param('suppression_x0'), param('suppression_k')))
	sc = apply(lim, 2, min)
	x[1, ] = 1 - sc/x[1,]
	
	
	x[2, ] =  x[2, ] * fni(index) / suppCon
	test = x[2,] > 0
	x[2, test] = sqrt(x[2,])
	x[2, !test] = - sqrt(-x[2,])
	
	return(x)
}

fuel = fgni(fuel, 1)
moisture = fgni(moisture, 2)
ignitions = fgni(ignitions, 3)

suppression = fgni(suppression, 4)


plotAll('shifted', fuel, moisture, ignitions, suppression)
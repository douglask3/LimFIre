SeasonLegend <- function(cols, limits, add, plot_loc, dat, e_lims = NULL,
                             mnthLabs = 1:12,
                             mar = c(4,0,0,0),labR = 0.6, ...) {
    
    MonLetters = c('J','F','M','A','M','J','J','A','S','O','N','D')
    if (all(range(limits)==c(0,11))) {
        labelss = rep('', 12)
        labelss[mnthLabs] = MonLetters[mnthLabs]
        mar[1] = mar[1]+1.5
        ncols = c(13,12)
        dang = 0
    } else {
        #labelss = limits[-1]
        mar[4]=mar[4]+1
        labelss = limits + 0.5
        ncols=c(length(labelss)+1,length(labelss))
        dang = 180
    }
    cols = make_col_vector(cols,ncols=ncols[1])[1:ncols[2]]

    z = rep(1,length(cols))
    
    if (!add) {
        mar0  = par("mar")
        par(mar = mar)
        x = 1; y = 1; radius = 1
        plot(1,1, axes = FALSE, type = 'n')      
    } else {
        rnge = par("usr")
        x = rnge[1] + 0.72222 * diff(rnge[1:2])
        y = rnge[3] + 0.30555566666 * diff(rnge[3:4])

        radius = 0.06944444 * diff(rnge[1:2])
        z = z * radius
    }
    
    add.pie(z, x, y, radius = radius, 
            col = cols,labels = '',clockwise = TRUE, init.angle = dang + 90 + 180/length(z))

    angles = dang * pi/180 + head(seq(0,2*pi ,length.out=length(labelss)+1),-1)+pi/2

    pie.labels(x, y,angles,rev(labelss),radius=labR * radius,xpd=NA)

    if (!is.null(e_lims)) {
        ylims = (seq(0, 0.8, length.out = length(e_lims) + 2)[-1])^1.5
        ylim0 = 0.8
        ylims = head(ylims, -1)

        plotElimCircle <- function(i, x, ylim, ...) {
            lim = sqrt(0.8^2-i^2)
            if (is.na(lim)) return()
            xi = x[x<lim & x>(-lim)]

            lim2 = sqrt(ylim - i^2)
            if (!is.na(lim2)) xi = xi[xi<(-lim2) | xi>lim2]
            points(xi, rep(i, length(xi)),...)
        }

        plotElimCirlces <- function(ylim, by, ...) {
            x = y = seq(-ylim0,ylim0,by = by)
            lapply(y, plotElimCircle, x, ylim, ...)
        }

        mapply(plotElimCirlces, ylims,
               by = seq(0.05,0.1,length.out=length(ylims)), cex = c(0.05,0.2),
               pch = 19)
    }
    if (!add) par(mar=mar0)
}
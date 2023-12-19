using Plots, Plots.Measures, LaTeXStrings

#funcs
pscatter! = Plots.scatter!
pplot = Plots.plot
pplot! = Plots.plot!
ptext = Plots.text
rectangle(x0,y0,w,h) = Shape(x0 .+ [0,w,w,0], y0 .+ [0,0,h,h])

#defaults
fontsize = 10
default(
    guidefontsize=fontsize,
    tickfontsize=fontsize,
    legendfontpointsize=fontsize,
    titlefontsize=fontsize,
    colorbar_titlefontsize=fontsize
)
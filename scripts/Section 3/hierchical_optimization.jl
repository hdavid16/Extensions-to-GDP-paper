using DrWatson
@quickactivate "Extensions-to-GDP-paper"
using StatsPlots
include(srcdir("plots.jl"))

##
x = range(0,10,101) #decision variable
ys = 0.1*(x .- 2.5).^2 .+ 3 #scheduler
yp = 0.1*(x .- 7.5).^2 .+ 4.5 #planner
ya = ys .+ yp #aggregated
yamin = findmin(ya)
yi = 0.1*(x .- 4.5).^2 .+ 1.5 #integrated
yimin = findmin(yi)
c=palette(:seaborn_bright)
fig = pplot(
    x,ys,label="Scheduler Cost",
    linewidth=3,linestyle=:auto,
    color=c[1],
    xlabel="Decision Variable",
    ylabel="Cost",
    legend=:outertopright,
    xlim=(0,10),
    ylim=(0,10),
    xticks=0:10,
    yticks=0:10,
)
pscatter!(fig,
    [2.5],[3],label="Scheduler Optimum",
    markershape=:auto,color=c[1],markersize=5
)
pplot!(fig,
    x,yp,label="Planner Cost",
    color=c[2],linewidth=3,linestyle=:auto,
)
pscatter!(fig,
    [7.5],[4.5],label="Planner Optimum",
    markershape=:auto,color=c[2],markersize=5
)
pplot!(fig,
    x,ya,label="Aggregated Cost",
    color=c[3],linewidth=3,linestyle=:auto,
)
pscatter!(fig,
    [x[yamin[2]]],[yamin[1]],
    label="Aggregated Optimum",color=c[3],
    markershape=:auto,markersize=5
)
pplot!(fig,
    x,yi,label="Integrated Cost",
    color=c[4],linewidth=3,linestyle=:auto,
)
pscatter!(fig,
    [x[yimin[2]]],[yimin[1]],
    label="Integrated Optimum",color=c[4],
    markershape=:dtriangle,markersize=5
)
#synergy
xs = x[yimin[2]]#(x[yimin[2]] + x[yamin[2]])/2
pplot!(fig,
    ones(2)*xs,[yimin[1],yamin[1]],label=nothing,
    linewidth=2,color=:black,markershape=:hline,markersize=10
)
annotate!(fig,
    [2.5],[3.75],
    [("Scheduler's\nOptimum",10,:center,:black)]
)
annotate!(fig,
    [7.5],[3.85],
    [("Planner's\nOptimum",10,:center,:black)]
)
annotate!(fig,
    [x[yamin[2]]],[9.5],
    [("Aggregated\nOptimum",10,:center,:black)]
)
annotate!(fig,
    [x[yimin[2]]],[0.85],
    [("Integrated\nOptimum",10,:center,:black)]
)
pplot!(fig,
    rectangle(4,6,1,1),
    color=:white,
    linewidth=0
)
annotate!(fig,
    [xs],[6.5],
    [("Synergistic\nPotential",10,:center,:black)]
)
pplot!(fig, legend=:none,size=(500,450))
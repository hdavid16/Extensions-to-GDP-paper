using DrWatson
@quickactivate "Extensions-to-GDP-paper"
include(srcdir("plots.jl"))
c = palette(:seaborn_bright)

## create variables
x1_range = range(0,5,101)
x2_range = range(0,5,101)
x1 = repeat(reshape(x1_range, 1, :), length(x2_range), 1)
x2 = repeat(x2_range, 1, length(x1_range))

## create global constraint
con1 = 3 .- 1/10 * x1_range.^2 #quadratic constraint
con2 = 10 .- 2 * x1_range #linear constraint

## create objective function
function f(x1,x2)
    if x2 > 3 - 1/10*x1^2 || x2 > 10 - 2*x1
        Inf
    else
        0.5*(x1-2)^2 + 1.5*(x2-3)^2 
    end
end
z_grid = f.(x1, x2)

## build figure
fig = Plots.contour(
    x1_range,
    x2_range,
    z_grid,
    levels=30,
    color=:hsv,
    xlim=(0,5),
    ylim=(0,5),
    clims=(0,20),
    colorbar_ticks=0:5:20,
    colorbar_formatter=:plain,
    size=(500,400),
    xlabel=L"x_1",
    ylabel=L"x_2",
    colorbar_title="\n\$z\$",
    guidefont=14,
    colorbar_titlefontsize=15,
    right_margin=10mm
)
pplot!(fig,rectangle(0,2,1,1),color=c[2],label="",alpha=0.85)#label="\$Y_1\$")
pplot!(fig,rectangle(0.5,0,1.5,1),color=c[1],label="",alpha=0.85)#label="\$Y_2\$")
pplot!(fig,rectangle(2.25,1,1.5,1.2),color=c[3],label="",alpha=0.85)#label="\$Y_3\$")
annotate!(fig,0.5,2.5,ptext(L"Y_1",:black,:center,12))
annotate!(fig,1.25,0.5,ptext(L"Y_2",:black,:center,12))
annotate!(fig,3.0,1.6,ptext(L"Y_3",:black,:center,12))
pplot!(fig,x1_range,con1,ribbon=(0,0.2),fillalpha=0.4,label="",color=:black,linewidth=2)
pplot!(fig,x1_range,con2,ribbon=(0,0.4),fillalpha=0.4,label="",color=:black,linewidth=2)
pplot!(fig,[0,5],[0,0],ribbon=(0.15,0),fillalpha=0.4,label="",color=:black,linewidth=2)
pplot!(fig,[0,0],[0,5],label="",color=:black,linewidth=2)
pplot!(fig,rectangle(-0.15,-0.15,0.15,5.2),color=:black,alpha=0.4,label="")
pplot!(fig,xlim=(-0.2,5),ylim=(-0.2,5))
using DrWatson
@quickactivate "Extensions-to-GDP-paper"
using BARON
section43dir(args...) = scriptsdir("Section 4.3", args...)
include(section43dir("model.jl"))
using StatsPlots, DataFrames
include(srcdir("plots.jl"))

##
magic = true
if magic
    options = ()
else
    options = (
        "PreSolve" => 0,
        "DoLocal" => 0,
        "NumLoc" => 0,
        "MaxTime" => 3600,
        "TDo" => 0,
        "MDo" => 0,
        "LBTTDo" => 0,
        "OBTTDo" => 0,
        "PDo" => 0,
        # "LPSol" => 3 #3 = CPLEX, 8 = CBC
    )
end

##hull
hull_n = model_4_3(;hierarchy = :nested, reformulation = :hull);
optimize_model(hull_n; options)
hull_e = model_4_3(;hierarchy = :equivalent, reformulation = :hull);
optimize_model(hull_e; options)
hull_a = model_4_3(;hierarchy = :none, reformulation = :hull);
optimize_model(hull_a; options)

##create models RMIP
rhull_n = model_4_3(;hierarchy = :nested, reformulation = :hull)
rhull_e = model_4_3(;hierarchy = :equivalent, reformulation = :hull)
rhull_a = model_4_3(;hierarchy = :none, reformulation = :hull)
##solve RMIP
optimize_model(rhull_n;RMIP=true)
optimize_model(rhull_e;RMIP=true)
optimize_model(rhull_a;RMIP=true)

##plot results
Qval = value.(hull_a[:Q])
Q_df = DataFrame(
    "time" => Qval.axes[2] .- 1,
    "Process 1" => Qval[1,:].data,
    "Process 2" => Qval[2,:].data,
    "Process 3" => Qval[3,:].data,
)
Q_fig = @df stack(Q_df,Not(:time)) pplot(
    :time,:value,group=:variable,
    linetype=:steppost, linewidth=2,
    palette=:seaborn_bright,
    xlabel="Time",
    ylabel="Capacity (tons)",
    xticks=0:21,
    yticks=0:0.1:1.2,
    legend=:right,
    linestyle=:auto,
    size=(800,300),
    margins=5mm
)
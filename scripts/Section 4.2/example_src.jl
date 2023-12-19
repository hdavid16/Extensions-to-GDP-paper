using DrWatson
@quickactivate "Extensions-to-GDP-paper"
section42dir(args...) = scriptsdir("Section 4.2", args...)
include(section42dir("graph.jl"))
include(section42dir("model.jl"))
include(section42dir("model_results.jl"))

## create and show network
net = network(
    Ktank = ["A","B","C","D"],
    I = 1:6
)
net_fig = plot_network(net)

##
time_points = 31
reactors = 2
max_reactors = 2
magic = true
if magic
    options = ("CPXPARAM_TimeLimit" => 3600,)
else
    options = (
        "CPXPARAM_Preprocessing_Presolve" => 0,
        "CPXPARAM_MIP_Strategy_HeuristicEffort" => 0,
        "CPXPARAM_TimeLimit" => 3600,
    )
end
##create and solve
#hull
hull_n = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :nested, reformulation = :hull);
optimize_model(hull_n; options)
hull_e = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :equivalent, reformulation = :hull);
optimize_model(hull_e; options)

#tight-m
tightm_n = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :nested, reformulation = :big_m);
optimize_model(tightm_n; options)
tightm_e = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :equivalent, reformulation = :big_m);
optimize_model(tightm_e; options)

##big-m
bigm_n = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :nested, reformulation = :big_m, M = 1000);
optimize_model(bigm_n; options)
bigm_e = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :equivalent, reformulation = :big_m, M = 1000);
optimize_model(bigm_e; options)

##create models RMIP
rbigm_e = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :equivalent, reformulation = :big_m, M = 1000);
rbigm_n = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :nested, reformulation = :big_m, M = 1000);
rtightm_e = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :equivalent, reformulation = :big_m);
rtightm_n = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :nested, reformulation = :big_m);
rhull_e = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :equivalent, reformulation = :hull)
rhull_n = model_4_2(net; time_points, reactors, max_reactors, hierarchy = :nested, reformulation = :hull)
##solve RMIP
optimize_model(rbigm_e;RMIP=true)
optimize_model(rbigm_n;RMIP=true)
optimize_model(rtightm_e;RMIP=true)
optimize_model(rtightm_n;RMIP=true)
optimize_model(rhull_e;RMIP=true)
optimize_model(rhull_n;RMIP=true)

##PLOTS
net_sol_fig = plot_network(hull_e)
oper_sched_fig = plot_schedule(hull_e,fontsize=26)
mat_sched_fig = plot_flow_schedule(hull_e,fontsize=26)
tank_level_fig = plot_tank_levels(hull_e)
tank_levels_df = get_tank_levels(hull_e)
tank_level_fig2 = pplot(
    xlim=(-0.1,maximum(tank_levels_df.time)+0.1),
    xticks=0:2:maximum(tank_levels_df.time),
    xlabel="Time",
    ylabel="Quantity (kg)",
    size=(800,300),
    margins=5mm,
    legend=:outertopright    
)
Q = value.(hull_e[:Q])
for (i,mat) in enumerate(["B","C"])
    pplot!(tank_level_fig2,
        tank_levels_df.time, 
        tank_levels_df[:,mat],
        label="Tank: $mat",
        linetype=:steppost,
        linewidth=2,
        color=palette(:tab20)[2i-1],
        linestyle=:auto,
        legend=:outertopright
    )
    pplot!(tank_level_fig2, 
        [0,maximum(tank_levels_df.time)],
        ones(2)*Q[mat],
        linewidth=2,
        color=palette(:tab20)[i+1],
        label="Capacity: $mat",
        linestyle=:auto
    )
end
tank_level_fig2
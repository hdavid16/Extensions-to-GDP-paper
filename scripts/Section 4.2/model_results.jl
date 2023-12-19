using CairoMakie, StatsPlots, DataFrames
include(srcdir("plots.jl"))

## build df with schedule
function extract_schedule(m)
    I,Kreact,T,U,τ,ν = m[:I],m[:Kreact],m[:T],m[:U],m[:τ],m[:ν]
    schedule = DataFrame(
        process = Int[], technology = Int[], reactor = Any[], unit = Symbol[], 
        start = Int[], stop = Int[], size=Real[]
    )
    for t in T, i in I, k in Kreact, u in U[k]
        if value(m[Symbol("N($i,$k,$t)")][u+1]) > 0.9
            iszero(u) && continue
            j = findfirst(>(0.9), value.(m[Symbol("W($i)")]))
            if isone(u) && !isempty(filter([:reactor, :unit, :start, :stop] => (r,u,a,b) -> r == k && u == :U1 && a <= t-1 < b, schedule, view=true))
                U1 = [2]
            else
                U1 = 1:u
            end
            for u1 in U1 #add a row for each unit
                b = value(m[:B][i,t])*ν[i,j]/u #divide by number of units used
                push!(schedule, (i, j, k, Symbol("U",u1), t-1, t+τ[i]-1, b)) #-1 is to start at 0
            end
        end
    end
    filter!(:size => !iszero, schedule)
    sort!(schedule, :start)
    return schedule
end

## build df with exernal flow amounts
function get_external_flows(m)
    T = m[:T]
    DataFrame(
        time = T .- 1, 
        A = round.(value.(m[:F][end-3,:]).data, digits=3), 
        B = round.(value.(m[:F][end-2,:]).data, digits=3), 
        C = round.(value.(m[:F][end-1,:]).data, digits=3),
        D = round.(value.(m[:F][end,:]).data, digits=3)
    )
end

## build df with tank levels
function get_tank_levels(m)
    T = vcat(0,m[:T])
    DataFrame(
        time = T .- 1,
        A = value.(m[:L]["A",:]).data,
        B = value.(m[:L]["B",:]).data,
        C = value.(m[:L]["C",:]).data,
        D = value.(m[:L]["D",:]).data,
    )
end

## plot operations gantt chart
function plot_schedule(df::DataFrame; 
    size=(1500,300), 
    xticks = 0:2:maximum(df.stop; init=0),
    colorticks = 0:20:100,
    fontsize=22
)
    RU_id = Dict(
        (:R1,:U1) => 4, #"R1_U1" => 4, 
        (:R1,:U2) => 3, #"R1_U2" => 3, 
        (:R2,:U1) => 2, #"R2_U1" => 2, 
        (:R2,:U2) => 1 #"R2_U2" => 1
    )
    transform!(df,
        [:start,:stop] => ByRow((a,b) -> (a+b)/2) => :mean, #text location
        [:reactor,:unit] => ByRow((r,u) -> RU_id[r,u]) => :reactor_unit
    )

    #create fig
    fig = Figure(;fontsize, resolution = size)
    ax = Axis(
        fig[1,1];
        title = "Production Schedule",
        xlabel = "Time",
        ylabel = "Reactor_Unit",
        xticks,
        yticks = (1:4, ["R2_U2", "R2_U1", "R1_U2", "R1_U1"])
    )
    CairoMakie.xlims!(ax, 0, xticks[end])
    CairoMakie.ylims!(ax, 0.5, 4.5)
    barplot!(ax,
        df.reactor_unit,
        df.stop,
        fillto = df.start,
        direction = :x,
        colormap = :Spectral,
        color = df.size,
        colorrange = (0,100),
        strokecolor = :black,
        strokewidth = 1,
        width = 0.75
    )
    text!(ax, df.mean, df.reactor_unit;
        text = string.(df.process,"-",df.technology),
        color = :black,
        align = (:center, :center)
    )
    Colorbar(fig[1,2], colormap = :Spectral, limits=(0,100), ticks = colorticks, label="Batch Size (kg)")

    return fig
end
plot_schedule(m; kwargs...) = plot_schedule(extract_schedule(m); kwargs...)

## plot procurement gantt chart
function plot_flow_schedule(df::DataFrame; 
    size=(1500,300), 
    xticks = 0:2:maximum(df.time; init=0),
    colorticks = 0:20:100,
    fontsize = 22
)
    material_map = Dict(
        "A" => 4,
        "B" => 3,
        "C" => 2,
        "D" => 1
    )

    df = subset!(
        transform!(
            stack(df, Not(:time), variable_name = :material, value_name = :amount),
            :time => :start,
            :time => ByRow(i -> i + 1) => :stop,
            :material => ByRow(x -> material_map[x]) => :material_id,
        ),
        :amount => ByRow(>(0))
    )

    fig = Figure(; fontsize, resolution = size)
    ax = Axis(
        fig[1,1];
        title = "External Flow Schedule",
        xlabel = "Time",
        ylabel = "Material",
        xticks,
        yticks = (1:4, ["D", "C", "B", "A"])
    )
    CairoMakie.xlims!(ax, 0, xticks[end]+1)
    CairoMakie.ylims!(ax, 0.5, 4.5)
    barplot!(ax,
        df.material_id,
        df.stop,
        fillto = df.start,
        direction = :x,
        color = df.amount,
        colormap = :Spectral,
        colorrange = (0,100),
        strokecolor = :black,
        strokewidth = 1,
        width = 0.5
    )
    Colorbar(fig[1,2], colormap = :Spectral, limits=(0,100), ticks = colorticks, label="Quantity (kg)")

    return fig
end
plot_flow_schedule(m; kwargs...) = plot_flow_schedule(get_external_flows(m); kwargs...)

## tank levels
function plot_tank_levels(df::DataFrame, materials::Vector=["A","B","C","D"])
    select!(df, "time", materials...)
    df_stack = stack(df, Not(:time))
    @df df_stack pplot(
        :time, :value, group=:variable,
        linetype=:steppost,
        xlim=(0,maximum(df.time)),
        xticks=0:2:maximum(df.time),
        xlabel="Time",
        ylabel="Quantity (kg)",
        linewidth = 2,
        palette = :seaborn_bright,
        size=(800,300),
        margins=5mm,
        linestyle=:auto,
        legend=:outertopright
    )
end
function plot_tank_levels(m, materials::Vector=["A","B","C","D"])
    df = get_tank_levels(m)
    fig = plot_tank_levels(df,materials)
    Q = value.(m[:Q])
    for mat in materials
        pplot!(fig, [0,maximum(df.time)],ones(2)*Q[mat],label="Capacity: $mat",linestyle=:auto)
    end
    return fig
end
using DrWatson
@quickactivate "Extensions-to-GDP-paper"
section41dir(args...) = scriptsdir("Section 4.1", args...)
include(section41dir("plot_defaults.jl"))
include(section41dir("projection.jl"))
include(srcdir("optimization.jl"))

## helper function to plot feasible regions
function draw_disjunctions!(fig)
    pplot!(fig, rectangle(1,4,2,2), fillalpha=0, linecolor=:black, linewidth=1.5, label="")
    pplot!(fig, rectangle(1,5,1,1), fillalpha=0, linecolor=:black, linewidth=1.5, label="")
    pplot!(fig, rectangle(2,4,1,1), fillalpha=0, linecolor=:black, linewidth=1.5, label="")
    pplot!(fig, rectangle(8,1,1,1), fillalpha=0, linecolor=:black, linewidth=1.5, label="")
    annotate!(fig, 2, 6.5, ptext(L"Y_1",:black,:center))
    annotate!(fig, 1.5, 5.5, ptext(L"W_1",:black,:center))
    annotate!(fig, 2.5, 4.5, ptext(L"W_2",:black,:center))
    annotate!(fig, 8.5, 1.5, ptext(L"Y_2",:black,:center))
end

## initialize model and plot
m = Model()
@variable(m, 1 <= x[i=1:2] <= [9,6][i])
@constraint(m, w1_con[i=1:2], [1,5][i] <= x[i] <= [2,6][i])
@constraint(m, w2_con[i=1:2], [2,4][i] <= x[i] <= [3,5][i])
@constraint(m, y1_con[i=1:2], [1,4][i] <= x[i] <= [3,6][i])
@constraint(m, y2_con[i=1:2], [8,1][i] <= x[i] <= [9,2][i])

## equivalent gdp
function egdp(m0, method, M=missing)
    m = copy(m0)
    add_disjunction!(m, m[:y1_con], m[:y2_con], reformulation = method, name = :y, M = M)
    add_disjunction!(m, m[:w1_con], m[:w2_con], nothing, reformulation = method, name = :w, M = M)
    choose!(m, 1, m[:w]...; name = "xor_w")
    choose!(m, 1, m[:y]...; name = "xor_y")
    choose!(m, m[:y][1], m[:w][1], m[:w][2]; name = "link")
    print_model_size(m)
    return m
end

## nested gdp
function ngdp_inner(m0, method, M=missing)
    m = copy(m0)
    m.ext[:variable_bounds_dict] = Dict(
        "x[1]" => (1,3),
        "x[2]" => (4,6)
    )
    add_disjunction!(m, m[:w1_con], m[:w2_con], reformulation = method, name = :w, M = M)
    return m
end
function ngdp(m0, inner_method, outer_method, inner_M=missing, outter_M=missing)
    m = ngdp_inner(m0, inner_method, inner_M)
    m.ext[:variable_bounds_dict] = Dict(
        "x[1]" => (1,9),
        "x[2]" => (1,6)
    )
    add_disjunction!(m, (m[:y1_con], m.ext[:w]...), m[:y2_con], reformulation = outer_method, name = :y, M = outter_M)
    choose!(m, m[:y][1], m[:w][1], m[:w][2]; name = "link")
    choose!(m, 1, m[:y]...; name = "xor")
    print_model_size(m)
    return m
end

## basic step gdp
function bgdp(m0, method, M = missing)
    m = copy(m0)
    @constraint(m, y1_con1[i=1:2], [1,4][i] <= m[:x][i] <= [3,6][i])
    add_disjunction!(m, (m[:y1_con], m[:w1_con]), (m[:y1_con1], m[:w2_con]), m[:y2_con], reformulation = method, name = :yw, M = M)
    choose!(m, 1, m[:yw]...; name = "xor")
    print_model_size(m)
    return m
end

## big-m plots
bigm = egdp(m, :big_m, 100);
bigmp = projection(bigm);
bigmp_area = area(bigmp)
fig = pplot(;plot_kw_args...)
pplot!(fig, bigmp, label="Big-M: 100%", linewidth=0, alpha=1, color=c[10], legend=:outertopright)

## tight-m (approach 3: basic step)
tightm3 = bgdp(m, :big_m);
tightm3p = projection(tightm3);
tightm3p_area = round(Int,area(tightm3p)/bigmp_area*100)
pplot!(fig, tightm3p, label="Tight-M (basic step): $tightm3p_area%", linewidth=0, alpha=1, color=c[5], legend=:outertopright)

## tight-m (approach 1)
tightm1 = egdp(m, :big_m);
tightm1p = projection(tightm1);
tightm1p_area = round(Int,area(tightm1p)/bigmp_area*100)
pplot!(fig, tightm1p, label="Tight-M (equivalent): $tightm1p_area%", linewidth=0, alpha=1, color=c[9], legend=:outertopright)

## tight-m (approach 2)
tightm2 = ngdp(m, :big_m, :big_m);
tightm2p = projection(tightm2);
tightm2p_area = round(Int,area(tightm2p)/bigmp_area*100)
pplot!(fig, tightm2p, label="Tight-M (nested): $tightm2p_area%", linewidth=0, alpha=1, color=c[8], legend=:outertopright)

## hull (approach 1)
hull1 = egdp(m, :hull);
hull1p = projection(hull1);
hull1p_area = round(Int,area(hull1p)/bigmp_area*100)
pplot!(fig, hull1p, label="Hull (equivalent): $hull1p_area%", linewidth=0, alpha=1, color=c[8], legend=:outertopright)

## hull (approach 2)
hull2 = ngdp(m, :hull, :hull);
hull2p = projection(hull2);
hull2p_area = round(Int,area(hull2p)/bigmp_area*100)
pplot!(fig, hull2p, label="Hull (nested): $hull2p_area%", linewidth=0, alpha=1, color=c[7], legend=:outertopright)

## hull (approach 3: basic step)
hull3 = bgdp(m, :hull);
hull3p = projection(hull3);
hull3p_area = round(Int,area(hull3p)/bigmp_area*100)
pplot!(fig, hull3p, label="Hull (basic step): $hull3p_area%", linewidth=0, alpha=1, color=c[7], legend=:outertopright)

## disjunctions
draw_disjunctions!(fig)
using Graphs, MetaGraphs
using GraphPlot

## define network
function network(;
    Ktank::Vector{String}, #material names (tanks)
    I::UnitRange{Int} #processes
)

    #create graph
    g = MetaDiGraph(length(Ktank)*2 + length(I))

    #add nodes
    for i in I #first nodes are processes
        set_indexing_prop!(g, i, :id, "Process\n$i")
    end
    for k in eachindex(Ktank) #next are tanks and then source/demand
        set_indexing_prop!(g, k + length(I), :id, "Tank\n$(Ktank[k])")
        set_indexing_prop!(g, k + length(I) + length(Ktank), :id, Ktank[k])
    end

    #add edges
    IM = length(I)/(length(Ktank)-1) #process per stage
    stream = 1
    for k in eachindex(Ktank[1:end-1])
        for m in (1:IM) .+ (k-1)*IM #connect tanks to downstream processes
            add_edge!(g, g["Tank\n$(Ktank[k])",:id], Int(m), :stream, "F$stream")
            set_prop!(g, g["Tank\n$(Ktank[k])",:id], Int(m), :id, stream)
            stream += 1
        end
        for m in (1:IM) .+ (k-1)*IM #connect tanks to upstream processes
            add_edge!(g, Int(m), g["Tank\n$(Ktank[k+1])",:id], :stream, "F$stream")
            set_prop!(g, Int(m), g["Tank\n$(Ktank[k+1])",:id], :id, stream)
            stream += 1
        end
    end
    for k in eachindex(Ktank[1:end-1])
        add_edge!(g, g[Ktank[k],:id], g["Tank\n$(Ktank[k])",:id], :stream, "F$stream")
        set_prop!(g, g[Ktank[k],:id], g["Tank\n$(Ktank[k])",:id], :id, stream)
        stream += 1
    end
    add_edge!(g, g["Tank\n$(Ktank[end])",:id], g[Ktank[end],:id], :stream, "F$stream")
    set_prop!(g, g["Tank\n$(Ktank[end])",:id], g[Ktank[end],:id], :id, stream)

    #store graph metadata
    set_prop!(g, :processes, I)
    set_prop!(g, :materials, Ktank)
    set_prop!(g, :processes_per_stage, IM)

    return g
end

## plot network
function plot_network(g0::MetaDiGraph;
    nodelabel = [g0[v,:id] for v in vertices(g0)],
    nodesize = 1,
    kwargs...
)
    #extract graph
    g = copy(g0)
    I = get_prop(g, :processes)
    Ktank = get_prop(g, :materials)
    IM = get_prop(g, :processes_per_stage)

    #add dummy node to get tweak aspect ratio
    add_vertex!(g, :id, "")

    #locations
    xloc = [
        v in I ? floor(v/(IM+1e-6)) : 
        v == nv(g) ? 0 : ((v-length(I)) % (length(Ktank)+1e-6)) - 1.5
        for v in vertices(g)
    ]
    yloc = [
        v in I ? ceil(v % (IM+1e-6)) : 
        g[v,:id] in Ktank ? 0 : 
        v == nv(g) ? -4 : (IM+1)/2
        for v in vertices(g)
    ]
    #node colors
    node_colors = [
        v in I ? "lightblue" :
        g[v,:id] in Ktank[1:end-1] ? "lightgreen" :
        g[v,:id] == Ktank[end] ? "gold" : 
        v == nv(g) ? nothing : "red"
        for v in vertices(g)
    ]
    #plot
    gplot(g, xloc, yloc;
        nodelabel = vcat(nodelabel,[""]),
        edgelabel = [get_prop(g,e,:stream) for e in edges(g)], 
        background_color = "white",
        arrowangleoffset = pi/9,
        arrowlengthfrac = 0.05,
        EDGELINEWIDTH = 1,
        EDGELABELSIZE = 3,
        NODELABELSIZE = 3,
        NODESIZE = 0.1,
        nodesize,
        nodefillc = node_colors,
        plot_size = (20cm, 20cm),
        kwargs...
    ) 
end

## plot solution
function plot_network(m)
    Fval = round.(abs.(value.(m[:F])), digits = 1)
    g = copy(m[:network])
    remove_list = []
    no_src = []
    for e in edges(g)
        Fid = get_prop(g,e,:id)
        if iszero(maximum(Fval[Fid,:]))
            push!(remove_list, e)
            if !occursin("Tank",get_prop(g,src(e),:id))
                push!(no_src, src(e)) #remove unused nodes (unless they are tanks)
            end
        end
    end
    for e in remove_list
        rem_edge!(g,e)
    end
    no_tank = filter(mat -> isone(value(m[Symbol("X($mat)")][1])), get_prop(g,:materials))
    no_tank_names = string.("Tank\n",no_tank)
    plot_network(g; 
        edgelinewidth = [log10(maximum(Fval[get_prop(g,e,:id),:])) for e in edges(g)],
        nodesize = vcat([get_prop(g,n,:id) in no_tank_names || n in no_src ? 0.001 : 1 for n in vertices(g)],0.1),
        nodelabel = [get_prop(g,n,:id) in no_tank_names || n in no_src  ? "" : g[n,:id] for n in vertices(g)]
    )
end
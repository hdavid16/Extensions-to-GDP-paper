using CPLEX
import Random:seed!
include(srcdir("optimization.jl"))
include(section42dir("model_nested.jl"))
include(section42dir("model_equivalent.jl"))

function model_4_2(
    network;
    time_points,
    reactors,
    max_reactors,
    hierarchy, 
    reformulation,
    M=missing, 
    seed=0
)
    m = Model(CPLEX.Optimizer)

    ##sets
    I = get_prop(network, :processes) #processes
    J = 1:2 #technologies per process
    Ktank = get_prop(network, :materials) #materials
    Kreact = [Symbol("R",k) for k in 1:reactors]
    K = Ktank ∪ Kreact #equipment (tanks + reactors)
    S = 1:(length(I)*2 + length(Ktank)) #streams
    T = 1:time_points #time points
    U = merge( #number of identical equipment in system
        Dict(k => 0:1 for k in Ktank),
        Dict(k => 0:max_reactors for k in Kreact)
    ) 
    Sout = merge(
        Dict( # process => stream (exit flow)
            i => get_prop(network, i, outneighbors(network, i)[1], :id)
            for i in I
        ),
        Dict( #streams exiting tank
            k => [get_prop(network, network["Tank\n$k",:id], n, :id) for n in outneighbors(network, network["Tank\n$k",:id])]
            for k in Ktank
        )
    )
    Sin = merge(
        Dict( # process => stream (inlet flow)
            i => get_prop(network, inneighbors(network, i)[1], i, :id)
            for i in I
        ),
        Dict( #streams entering tank
            k => [get_prop(network, n, network["Tank\n$k",:id], :id) for n in inneighbors(network, network["Tank\n$k",:id])]
            for k in Ktank
        )
    )
    Q_ub = merge( #equipment capacities
        Dict(k => 300 for k in Ktank),
        Dict(k => 100 for k in Kreact)
    )
    Smap = Dict(
        get_prop(network,e,:id) => (network[src(e),:id],network[dst(e),:id])
        for e in edges(network)
    )
    F_ub = Dict( #flow upper bound
        s => 
            s in values(Sin) ∪ values(Sout) ? #connected to process
            maximum(U[k][end]*Q_ub[k] for k in Kreact) : #maximum reactor capacity
            Q_ub[string(Smap[s][1][end])] #tank capacity (get source node and take last character, which is the material leter)
        for s in S
    )

    #store sets and dicts
    m[:I], m[:J], m[:K], m[:S], m[:T], m[:U] = I, J, K, S, T, U
    m[:Kreact], m[:Ktank] = Kreact, Ktank
    m[:Sin], m[:Sout], m[:Smap] = Sin, Sout, Smap
    m[:Q_ub], m[:F_ub], m[:network]  = Q_ub, F_ub, network

    ##parameters
    generate_model_parameters!(m, seed)
    α, β, γ, ν, τ = m[:α], m[:β], m[:γ], m[:ν], m[:τ]
    p = [1,7,8,10] #material prices
    m[:p] = p

    ##variables
    @variables(m, begin
        0 ≤ B[i = I, t = T] ≤ sum(U[k][end]*Q_ub[k] for k in Kreact) #total batch sizes
        0 ≤ B̂[i = I, t = T] ≤ maximum(Q_ub[k] for k in Kreact) #batch size per reactor
        0 ≤ F[s = S, t = T] ≤ F_ub[s] #flows
        0 ≤ IC[k = K] ≤ α[k] + β[k]*U[k][end]*Q_ub[k] #tank and reactor installation costs
        0 ≤ L[k = Ktank, t = [0] ∪ T] ≤ U[k][end]*Q_ub[k] #tank levels availability
        0 ≤ L̂[k = Ktank] ≤ U[k][end]*Q_ub[k] #slack on final tank level
        0 ≤ OC[i = I, t = T] ≤ sum(γ[i,k]*U[k][end]*Q_ub[k] for k in Kreact) #operating costs
        0 ≤ Q[k = K] ≤ Q_ub[k] #installed tank and ractor capacities
        0 ≤ R[k = Kreact, t = [0] ∪ T] ≤ U[k][end] #reactor availability
        0 ≤ ΔR[i = I, k = Kreact, t = T] ≤ U[k][end] #reactor consumption trigger
    end)

    #objective
    p1 = Dict(mat => pval for (mat,pval) in zip(Ktank,p))
    @objective(m, Max,
        + sum(p[end]*F[end,:]) #revenue
        - sum(p[end-x]*F[end-x,t] for x in eachindex(Ktank[1:end-1]), t in T) #purchase costs
        - sum(IC) #installation costs
        - sum(OC) #operating costs
        - sum(p1[k]*L̂[k] for k in Ktank) #tank slacks
    )

    #initial conditions
    @constraints(m, begin
        initial_flow_out[i = I, t = 1:max(τ[i],1)], #no flows out up to first processing time
            F[Sout[i],t] ≤ 0
    end)

    #global tank constraints
    @constraints(m, begin
        capacity[k = Ktank, t = T],
            L[k,t] ≤ Q[k]
        tank_levels[k = Ktank, t = T],
            L[k,t] == L[k,t-1] + sum(F[s,t] for s in Sin[k]) - sum(F[s,t] for s in Sout[k])
    end)

    #global reactor constraints
    @constraint(m, reactor[k = Kreact, t = T], 
        R[k,t] == R[k,t-1]
            - sum(ΔR[:,k,t])
            + sum(ΔR[i,k,t-τ[i]] for i in I if 1 ≤ t-τ[i]; init=0)
    )

    #equipment installation constraints
    @constraints(m, begin
        equipment_cost[k = K, u = setdiff(U[k],0)], 
            IC[k] == α[k] + β[k]*u*Q[k]
        initial_tank_levels[k = Ktank, u = setdiff(U[k],0)], #tank is full at t=0
            L[k,0] == u*Q[k]
        final_tank_levels[k = Ktank, u = setdiff(U[k],0)], #final tank level should be close to full
            L[k,T[end]] + L̂[k] == u*Q[k]
        initial_reactors[k = Kreact, u = setdiff(U[k],0)], #all reactor units are available at t=0
            R[k,0] == u
        no_equipment_cost[k = K],
            IC[k] ≤ 0
        no_equipment[k = K], 
            Q[k] ≤ 0
        no_tank[k = Ktank, t = vcat(0,T)], #tank is empty
            L[k,t] ≤ 0 
        no_tank_slack[k = Ktank],
            L̂[k] ≤ 0
        no_reactor[k = Kreact, t = vcat(0,T)],
            R[k,t] ≤ 0
    end)
    #equipment installation disjunctions
    for k in Ktank
        add_disjunction!(m, 
            (
                no_equipment_cost[k], 
                no_equipment[k],
                no_tank[k,:],
                no_tank_slack[k]
            ),
            [
                (
                    equipment_cost[k,u],
                    initial_tank_levels[k,u],
                    final_tank_levels[k,u]
                )
                for u in setdiff(U[k],0)
            ]...;
            reformulation,
            M,
            name = Symbol("X($k)")
        )
        choose!(m, 1, m[Symbol("X($k)")]...)
    end
    for k in Kreact
        add_disjunction!(m, 
            (
                no_equipment_cost[k], 
                no_equipment[k],
                no_reactor[k,:]
            ),
            [
                (
                    equipment_cost[k,u],
                    initial_reactors[k,u]
                )
                for u in setdiff(U[k],0)
            ]...;
            reformulation,
            M,
            name = Symbol("X($k)")
        )
        choose!(m, 1, m[Symbol("X($k)")]...)
    end

    #disjunction constraints
    @constraints(m, begin
        in_flow[i = I, s = Sin[i], t = T],
            F[s,t] == B[i,t]
        batch_size[i = I, k = Kreact, t = T],
            B̂[i,t] ≤ Q[k]
        operating_cost[i = I, k = Kreact, t = T], 
            OC[i,t] == γ[i,k]*B[i,t]
        reactor_use[i = I, k = Kreact, t = T, u = U[k]],
            ΔR[i,k,t] == u
        total_batch[i = I, k = Kreact, t = T, u = U[k]],
            B[i,t] == u*B̂[i,t]
        out_flow[i = I, j = J, s = Sout[i], t = T[1]:T[end]-τ[i]], 
            F[s,t+τ[i]] == ν[i,j]*B[i,t]
    end)
    @constraints(m, begin
        no_in_flow[i = I, s = Sin[i], t = T],
            F[s,t] ≤ 0
        no_out_flow[i = I, s = Sout[i], t = T],
            F[s,t] ≤ 0
        no_batch_size[i = I, t = T],
            B̂[i,t] ≤ 0
        no_batch[i = I, t = T],
            B[i,t] ≤ 0
        no_operating_cost[i = I, t = T],
            OC[i,t] ≤ 0
        no_reactor_use[i = I, k = Kreact, t = T],
            ΔR[i,k,t] ≤ 0
    end)

    if hierarchy == :nested
        nested_model_4_2!(m, reformulation, M)
    elseif hierarchy == :equivalent
        equivalent_model_4_2!(m, reformulation, M)
    end

    print_model_size(m)

    return m
end

function generate_model_parameters!(m::Model, seed::Int)
    seed!(seed)
    I,J,K,Kreact = m[:I],m[:J],m[:K],m[:Kreact]

    ##generate parameters
    m[:α] = Dict(k => rand() for k in K) #equipment fixed installation costs
    m[:β] = Dict(k => 0.1*rand() for k in K) #equipment variable installation costs
    m[:γ] = Dict((i,k) => rand() for i in I, k in Kreact) #process operating costs
    m[:ν] = Dict((i,j) => rand() for i in I, j in J) #process yields
    m[:τ] = Dict(i => rand(1:5) for i in I) #process durations

    return nothing
end
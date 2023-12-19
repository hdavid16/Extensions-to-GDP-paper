using BARON
import Random:seed!
include(srcdir("optimization.jl"))
include(section43dir("model_nested.jl"))
include(section43dir("model_equivalent.jl"))
include(section43dir("model_alternate.jl"))

function model_4_3(; hierarchy, reformulation, M=missing)

    m = Model(BARON.Optimizer)
    #SETS
    I = 1:8 #streams
    J = 1:3 #units
    T = 1:21 #time
    #PARAMETERS (all $ values are scaled down by 1,000)
    c = [ #cost coefficients for each stream
        1.8, 0, 0, 0.3, 0.1, 7, 0, -10.8 
    ]
    γ = [ #fixed operating cost for each unit
        0.9, 1, 1.2
    ]
    β = [ #fixed cost for expansion of each unit
        3.5, 1, 1.5
    ]
    α = [ #variable cost coefficient for capacity expansion of each unit
        1.2, 0.7, 1.1
    ]
    arcs = Dict( #streams connected to each unit
        1 => [7,8],
        2 => [2,4],
        3 => [3,5]
    )
    i_out = Dict( #stream exiting each unit
        1 => 8,
        2 => 4,
        3 => 5
    )
    #STORE OBJECTS
    m[:I],m[:J],m[:T]=I,J,T
    m[:c],m[:γ],m[:β],m[:α]=c,γ,β,α
    m[:arcs],m[:i_out]=arcs,i_out
    #VARIABLES
    seed!(0)
    QE_ub = Dict(1 => 0.4, 2 => 0.3, 3 => 0.3)
    x_ub = 5
    m[:QE_ub] = QE_ub
    @variables(m, begin
        0 ≤ x[i = I, t = T] ≤ x_ub #flows
        0 ≤ Q[j = J, t = T] ≤ QE_ub[j]*t #capacity (UB = expand at every period)
        0 ≤ QE[j = J, t = T] ≤ QE_ub[j] #expansion amount (UB = maximum expansion)
        0 ≤ CE[j = J, t = T] ≤ α[j]*QE_ub[j] + β[j] #expansion cost (UB = cost for maximum expansion)
        0 ≤ CO[j = J, t = T] ≤ γ[j] #operating cost (UB = fixed operating cost)
    end)
    #OBJECTIVE FUNCTION
    @objective(m, Min,
        sum(
            sum(CO[j,t] + CE[j,t] for j in J)
            +
            sum(c[i]*x[i,t] for i in I)
            for t in T
        )
    )
    #GLOBAL CONSTRAINTS
    @constraints(m, begin
        mass_balance_1[t = T],
            x[1,t] == x[2,t] + x[3,t]
        mass_balance_2[t = T],
            x[4,t] + x[5,t] + x[6,t] == x[7,t]
        import_ub[t = T],
            x[6,t] ≤ 5
        export_level[t = T],
            x[8,t] ≤ 1
    end)
    #DISJUNCTION CONSTRAINTS
    @constraints(m, begin
        #design decisions
        capacity_expansion[j = J, t = T],
            Q[j,t] == (t > 1 ? Q[j,t-1] : 0) + QE[j,t]
        no_flows[i = union(values(arcs)...), t = T],
            x[i,t] ≤ 0
        no_capacity[j = J, t = T],
            Q[j,t] ≤ 0
        no_capacity_expansion_y[j = J, t = T],
            QE[j,t] ≤ 0
        #operating decisions
        capacity[j = J, t = T],
            x[i_out[j],t] ≤ Q[j,t]
        operating_cost[j = J, t = T],
            CO[j,t] == γ[j]
        no_out_flows[i = union(values(i_out)...), t = T],
            x[i,t] ≤ 0
        no_operating_cost[j = J, t = T],
            CO[j,t] ≤ 0
        #expansion decisions
        expansion_costs[j = J, t = T],
            CE[j,t] == α[j]*QE[j,t] + β[j]
        no_capacity_expansion_z[j = J, t = T],
            QE[j,t] ≤ 0
        no_expansion_costs_z[j = J, t = T],
            CE[j,t] ≤ 0 
    end)
    if hierarchy in [:nested, :equivalent]
        @constraints(m, begin
            no_operating_cost_y[j = J, t = T],
                CO[j,t] ≤ 0
            no_expansion_costs_y[j = J, t = T],
                CE[j,t] ≤ 0 
            no_capacity_expansion_w[j = J, t = T],
                QE[j,t] ≤ 0
            no_expansion_costs_w[j = J, t = T],
                CE[j,t] ≤ 0 
        end)
    end
    #operating decision (yields)
    m[:yields] = Dict(
        1 => @constraint(m, yields_1[t = T], x[8,t] == 0.9*x[7,t]),
        2 => @NLconstraint(m, yields_2[t = T], x[4,t] == log(1+x[2,t])),
        3 => @NLconstraint(m, yields_3[t = T], x[5,t] == 1.2*log(1+x[3,t]))
    )

    #disjunctions
    if hierarchy == :nested
        nested_model_4_3!(m, reformulation, M)
    elseif hierarchy == :equivalent
        equivalent_model_4_3!(m, reformulation, M)
    elseif hierarchy == :none
        alternate_model_4_3!(m, reformulation, M)
    end

    #propositions
    choose!(m, 1, m[:y2][1], m[:y3][1], mode = :at_most) #unit 2 and 3 can't both be installed
    y3, y2, y1 = m[:y3][1], m[:y2][1], m[:y1][1]
    add_proposition!(m, :($y2 ⇒ $y1))
    add_proposition!(m, :($y3 ⇒ $y1))
    for j in J
        @constraint(m, (1-m[Symbol("y$j")][1]) + sum(m[Symbol("w$j$t")][1] for t in T) ≥ 1)
        for t in T
            @constraint(m, (1-m[Symbol("w$j$j")][1]) + sum(m[Symbol("z$j$t1")][1] for t1 in 1:t) ≥ 1)
        end
    end

    print_model_size(m)

    return m
end
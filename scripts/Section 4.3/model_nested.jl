function nested_model_4_3!(m, reformulation, M)
    J,T,arcs,i_out=m[:J],m[:T],m[:arcs],m[:i_out]
    Q,QE,CE,CO=m[:Q],m[:QE],m[:CE],m[:CO]
    for j in J
        for t in T
            #expansion decision
            add_disjunction!(m,
                m[:expansion_costs][j,t],
                (
                    m[:no_capacity_expansion_z][j,t],
                    m[:no_expansion_costs_z][j,t]
                );
                reformulation,
                M,
                name = Symbol("z$j$t")
            )
            #operating decisions
            add_disjunction!(m,
                (
                    m[:capacity][j,t],
                    m[:operating_cost][j,t],
                    m.ext[Symbol("z$j$t")]
                ),
                (
                    m[:no_out_flows][i_out[j],t],
                    m[:no_operating_cost][j,t],
                    m[:no_capacity_expansion_w][j,t],
                    m[:no_expansion_costs_w][j,t]
                );
                reformulation,
                M,
                name = Symbol("w$j$t")
            )
        end
        #design decision
        add_disjunction!(m,
            (
                m[:yields][j][:],
                m[:capacity_expansion][j,:],
                [
                    m.ext[Symbol("w$j$t")]
                    for t in T
                ]...,
            ),
            (
                m[:no_flows][arcs[j],:],
                m[:no_capacity][j,:],
                m[:no_capacity_expansion_y][j,:],
                m[:no_operating_cost_y][j,:],
                m[:no_expansion_costs_y][j,:]
            );
            reformulation,
            M,
            name = Symbol("y$j")
        )
        #logical constraints
        choose!(m, 1, m[Symbol("y$j")]...)
        #linking constraints
        for t in T
            choose!(m, m[Symbol("y$j")][1], m[Symbol("w$j$t")]...)
            choose!(m, m[Symbol("w$j$t")][1], m[Symbol("z$j$t")]...)
        end
    end
end
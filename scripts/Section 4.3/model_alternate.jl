function alternate_model_4_3!(m, reformulation, M)
    J,T,arcs,i_out=m[:J],m[:T],m[:arcs],m[:i_out]
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
            choose!(m, 1, m[Symbol("z$j$t")]...)
            #operating decisions
            add_disjunction!(m,
                (
                    m[:capacity][j,t],
                    m[:operating_cost][j,t],
                ),
                (
                    m[:no_out_flows][i_out[j],t],
                    m[:no_operating_cost][j,t],
                );
                reformulation,
                M,
                name = Symbol("w$j$t")
            )
            choose!(m, 1, m[Symbol("w$j$t")]...)
        end
        add_disjunction!(m,
            (
                m[:yields][j][:],
                m[:capacity_expansion][j,:]
            ),
            (
                m[:no_flows][arcs[j],:],
                m[:no_capacity][j,:],
                m[:no_capacity_expansion_y][j,:],
            );
            reformulation,
            M,
            name = Symbol("y$j")
        )
        #logical constraints
        choose!(m, 1, m[Symbol("y$j")]...)
        #linking constraints
        yj_1 = m[Symbol("y$j")][1]
        for t in T
            wjt_1 = m[Symbol("w$j$t")][1]
            zjt_1 = m[Symbol("z$j$t")][1]
            add_proposition!(m, :($wjt_1 ⇒ $yj_1))
            add_proposition!(m, :($zjt_1 ⇒ $wjt_1))
        end
    end
end
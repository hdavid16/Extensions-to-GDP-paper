function equivalent_model_4_2!(m, reformulation, M)
    #load parameters and sets and vars
    I = m[:I] 
    J = m[:J] 
    Kreact = m[:Kreact]
    T = m[:T] 
    U = m[:U]

    for i in I
        #schedule triggers
        for k in Kreact, t in T
            add_disjunction!(m,
                [
                    (
                        m[:reactor_use][i,k,t,u],
                        m[:total_batch][i,k,t,u]
                    )
                    for u in U[k]
                ]...,
                nothing;
                reformulation,
                M,
                name = Symbol("N($i,$k,$t)")
            )
            choose!(m, 1, m[Symbol("N($i,$k,$t)")]...)
        end
        #reactor type assignment
        add_disjunction!(m,
            [
                (
                    m[:batch_size][i,k,:],
                    m[:operating_cost][i,k,:]
                )
                for k in Kreact
            ]...,
            nothing;
            reformulation,
            M,
            name = Symbol("V($i)")
        )
        choose!(m, 1, m[Symbol("V($i)")]...)
        #technology selection for process
        add_disjunction!(m,
            [m[:out_flow][i,j,:,:] for j in J]...,
            nothing;
            reformulation,
            M,
            name = Symbol("W($i)")
        )
        choose!(m, 1, m[Symbol("W($i)")]...)
        #process installation
        add_disjunction!(m,
            m[:in_flow][i,:,:],
            (
                m[:no_in_flow][i,:,:],
                m[:no_out_flow][i,:,:],
                m[:no_batch_size][i,:],
                m[:no_batch][i,:],
                m[:no_operating_cost][i,:],
                m[:no_reactor_use][i,:,:],
            );
            reformulation,
            M,
            name = Symbol("Y($i)")
        )
        choose!(m, 1, m[Symbol("Y($i)")]...)
        #linking constraints
        choose!(m, m[Symbol("Y($i)")][1], m[Symbol("V($i)")][1:end-1]...)
        choose!(m, m[Symbol("Y($i)")][1], m[Symbol("W($i)")][1:end-1]...)
        for k_idx in eachindex(Kreact), t in T
            k = Kreact[k_idx]
            choose!(m, m[Symbol("V($i)")][k_idx], m[Symbol("N($i,$k,$t)")][1:end-1]...)
            #logic proposition
            @constraint(m, [u in setdiff(U[k],0)],
                (1-m[Symbol("N($i,$k,$t)")][u+1]) + sum(m[Symbol("X($k)")][u1+1] for u1 in setdiff(U[k],0:(u-1))) ≥ 1
            )
        end
    end
end
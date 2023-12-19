using JuMP, DisjunctiveProgramming

## print model size
function print_model_size(m::Model)
    bin = num_constraints(m,VariableRef,MOI.ZeroOne) #number of binaries
    integer = num_constraints(m,VariableRef,MOI.Integer) #number of integers
    cont = num_variables(m) - bin - integer #number of continuous vars
    #tally number of constraints
    constr = 0
    for ctype in list_of_constraint_types(m)
        constr += num_constraints(m,ctype[1],ctype[2])
    end
    #print model size
    println("Binaries: $bin, Integers: $integer, Continuous: $cont, Constraints: $constr \n")

    return bin, integer, cont, constr
end

## solve
function optimize_model(m; RMIP=false, verbose=false, options = missing)
    if !ismissing(options)
        set_optimizer_attributes(m, options...)
    end
    if RMIP
        undo = relax_integrality(m)
    end
    optimize!(m)
    @show m[Symbol("Summary_RMIP=$RMIP")] = solution_summary(m; verbose)
    RMIP && undo()
    return nothing
end

## solve both RMIP and MIP
function run_model(m; verbose=true)
    ##solve LP relaxation
    optimize_model(m; RMIP=true, verbose)
    ##solve MILP
    optimize_model(m; RMIP=false, verbose)
    return nothing
end
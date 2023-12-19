# Extensions-to-GDP-paper

This repository contains the code used in the article [Extensions to Generalized Disjunctive Programming: Hierarchical Structures and First-order Logic](https://arxiv.org/abs/2303.04375) by Hector D. Perez and Ignacio E. Grossmann.

# Installation

This code base is using the [Julia Language](https://julialang.org/) and
[DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/)
to make a reproducible scientific project named
> Extensions-to-GDP-paper

It is authored by Hector D. Perez.

To (locally) reproduce this project, do the following:

0. Download this code base. Notice that raw data are typically not included in the
   git-history and may need to be downloaded independently.
1. Open a Julia console and do:
   ```
   julia> using Pkg
   julia> Pkg.add("DrWatson") # install globally, for using `quickactivate`
   julia> Pkg.activate("path/to/this/project")
   julia> Pkg.instantiate()
   ```

This will install all necessary packages for you to be able to run the scripts and
everything should work out of the box, including correctly finding local paths.

You may notice that most scripts start with the commands:
```julia
using DrWatson
@quickactivate "Extensions-to-GDP-paper"
```
which auto-activate the project and enable local path handling from DrWatson.

# Plotting Libraries

The graphics in this repository are made with [Makie.jl](https://docs.makie.org/stable/) and [GraphPlot.jl](https://github.com/hdavid16/GraphPlot.jl/tree/up). **Note: GraphPlot should be installed from the `up` branch on the fork the link given above for the network plots to work properly.**

# Optimizaton Solvers

The repository uses CPLEX and BARON solvers, which should be installed as instruced in [CPLEX.jl](https://github.com/jump-dev/CPLEX.jl) and [BARON.jl](https://github.com/jump-dev/BARON.jl), respectively.

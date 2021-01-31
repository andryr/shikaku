include("generation.jl")
include("resolution.jl")

"""
Run tests and return results aggregated by a parameter

Arguments:
solveFunc: solving function, take a grid as argument and must return if the solution is optimal and the solving duration
paramFunc: takes grid, depth, nbMergeIter as arguments, must an integer (usually just returns one of its arguments)
"""
function tests(solveFunc, paramFunc)
    sizes = [4, 9, 16, 25, 50]

    results = Dict{Int, Vector{Tuple{Bool, Float64}}}()

    # Dummy solve, required as first call to solve function is usually much slower
    solveFunc(generateInstance(1, 1, 1, 0, 0.0))

    # For each grid size considered
    for (k, size) in enumerate(sizes)
        m = size
        n = size

        # For each depth considered
        for depth in 1:(size ÷ 2)
            for nbMergeIter = 0:3
                # Generate and solve 5 instances
                for instance in 1:5
                    println("Instance m=$m, n=$n, depth=$depth, nbMergeIter=$nbMergeIter")
                    g = generateInstance(m, n, depth, nbMergeIter, 0.5)
                    
                    isOptimal, elapsedTime = solveFunc(g)
                    param = paramFunc(g, depth, nbMergeIter)
                    if !haskey(results, param)
                        results[param] = Vector{Tuple{Bool, Float64}}()
                    end
                    push!(results[param], (isOptimal, elapsedTime))
                end
            end
        end
    end

    optRatio = Dict{Int, Float64}()
    means = Dict{Int, Float64}()

    # Aggregate results
    for (param, vec) in results
       optRatio[param], means[param] = aggregate(results[param])
    end

    return optRatio, means
end

function aggregate(res::Vector{Tuple{Bool, Float64}})
    optRatio = sum(function(x)
        isOpt, _ = x
        return isOpt
        end, res) / length(res)
    means = sum(function(x)
        _, elapsedTime = x
        return elapsedTime
        end, res) / length(res)
    return optRatio, means
end

function gurobiSolveTest(g)
    isOptimal, elapsedTime, _ = ipSolve(g, Gurobi.Optimizer)
    return isOptimal, elapsedTime
end

function cbcSolveTest(g)
    isOptimal, elapsedTime, _ = ipSolve(g, Cbc.Optimizer)
    return isOptimal, elapsedTime
end

function heuristicSolveTest(g)
    start = time()
    isOptimal, _ = heuristicSolve(g)
    return isOptimal, time() - start
end

function paramSize(grid, depth,nbMergeIter)
    return size(grid, 1)
end

function paramDepth(grid,depth,nbMergeIter)
    return depth
end

function paramNbRect(grid, depth, nbMergeIter)
    return sum(grid .> 0)
end

function plotResults(res::Dict{Int, Float64}; kwargs...)
    plot(sort(pairs(res)); kwargs...)
end
# This file contains methods to solve an instance (heuristically or with CPLEX)
import Cbc
import Gurobi
include("generation.jl")

TOL = 0.00001

"""
Solve an instance using integer programming
"""
function ipSolve(grid::Array{Int,2}, optimizer)

    # Start a chronometer
    start = time()
    
    # Create the model
    model = Model(optimizer)

    m, n = size(grid)

    numberPos = Vector{Tuple{Int,Int}}()

    for i in 1:m
        for j in 1:n
            if grid[i,j] > 0
                push!(numberPos, (i, j))
            end
        end
    end

    p = length(numberPos)

    R = Vector{Vector{Array{Int,2}}}()
    for k = 1:p
        gridList = Vector{Array{Int,2}}()
        (i0, j0) = numberPos[k]
        val = grid[i0, j0]
        div = divisors(val)
        for (d1, d2) in vcat(div, reversePairs(div))
            if d1 > m || d2 > n
                continue
            end
            for i1 = 1:m - d1 + 1
                if !(i1 <= i0 < i1 + d1) # rectangle must contain its associated number
                    continue
                end
                for j1 = 1:n - d2 + 1
                    if !(j1 <= j0 < j1 + d2) # rectangle must contain its associated number
                        continue
                    end
                    # (i1, j1) are the coordinates of the top-left corner of the considered rectangle
                    rectGrid = Array{Int,2}(undef, m, n)
                    for i = 1:m
                        for j = 1:n
                            if i1 <= i < i1 + d1 && j1 <= j < j1 + d2
                                rectGrid[i,j] = 1
                            else
                                rectGrid[i,j] = 0
                            end
                        end
                    end
                    push!(gridList, rectGrid)
                end
            end
        end
        push!(R, gridList)
    end

    indices = variableIndices(R)

    @variable(model, x[indices], Bin)

    for k = 1:p
        (i0, j0) = numberPos[k]
        q = length(R[k])

        # Exactly one rectangle per number is active
        @constraint(model, sum(x[(k, l)] for l = 1:q) == 1)
    end

    # Rectangles do not overlap each other
    for i in 1:m,j in 1:n
        @constraint(model, sum(R[k][l][i, j] * x[(k, l)] for k = 1:p,l = 1:length(R[k])) == 1)
    end

    # @objective(model, Min, 0)

    # Solve the model
    optimize!(model)

    elapsedTime = time() - start

    status = JuMP.primal_status(model)
    if status != MOI.NO_SOLUTION
        sol = round.(Int, value.(x)) # solution of the LP problem

        # build a more compact representation of the solution
        rects = Vector{Tuple{Int,Int,Int,Int}}()
        for k = 1:p
            q = length(R[k])
            for l = 1:q
                if sol[(k, l)] == 1
                    i1, j1, i2, j2 = m + 1, n + 1, 0, 0
                    for i in 1:m, j in 1:n
                        if R[k][l][i,j] == 1
                            i1 = min(i1, i)
                            j1 = min(j1, j)
                            i2 = max(i2, i)
                            j2 = max(j2, j)
                        end
                    end
                    push!(rects, (i1, j1, i2, j2))
                    break
                end
            end
        end
        return true, elapsedTime, rects
    else
        return false, elapsedTime, Nothing
    end
end

function variableIndices(R::Vector{Vector{Array{Int,2}}})
    indices = Vector{Tuple{Int,Int}}()
    p = length(R)
    for i = 1:p
        q = length(R[i])
        for j = 1:q
            push!(indices, (i, j))
        end
    end
    return indices
end

"""
Returns a list of positive integer pairs (d1, d2) such that d1<=d2 and d1*d2=n
"""
function divisors(n::Int)
    divList = [(1, n)]
    for d = 2:ceil(Int, sqrt(n))
        if n % d == 0
            push!(divList, (d, n ÷ d))
        end
    end
    return divList
end

function reversePairs(pairs::Array{Tuple{Int,Int},1})
    return map(
        function (x)
        (i, j) = x
        return (j, i)
    end,
        pairs)
end


"""
Heuristically solve an instance
"""
function heuristicSolve(grid::Array{Int,2}, kMax::Int = 10000, initT::Float64 = 10000.0, lambda::Float64 = 0.999)
    m, n = size(grid)

    numberPos = Vector{Tuple{Int,Int}}()

    for i in 1:m
        for j in 1:n
            if grid[i,j] > 0
                push!(numberPos, (i, j))
            end
        end
    end


    p = length(numberPos)

    # Determine all possible rectangles
    possibleRects = Vector{Vector{Tuple{Int,Int,Int,Int}}}(undef, p)

    for k = 1:p
        possibleRects[k] = Vector{Tuple{Int,Int,Int,Int}}()
        (i0, j0) = numberPos[k]
        val = grid[i0, j0]
        div = divisors(val)
        for (d1, d2) in vcat(div, reversePairs(div))
            if d1 > m || d2 > n
                continue
            end
            for i1 = 1:m - d1 + 1
                i2 = i1 + d1 - 1
                if !(i1 <= i0 <= i2) # rectangle must contain its associated number
                    continue
                end
                for j1 = 1:n - d2 + 1
                    j2 = j1 + d2 - 1
                    if !(j1 <= j0 <= j2) # rectangle must contain its associated number
                        continue
                    end
                    goodRect = true
                    for i in i1:i2, j in j2:j2
                        if (i, j) != (i0, j0) && grid[i,j] > 0
                            goodRect = false
                        end
                    end
                    if goodRect
                        rect = (i1, j1, i2, j2)
                        push!(possibleRects[k], rect)
                    end
                end
            end
        end
    end

    # Solve using simulated annealing
    state = Vector{Int}(undef, p)
    for k = 1:p
        l = ceil(Int, rand() * length(possibleRects[k]))
        state[k] = l
    end

    optState = state
    T = initT
    E = energy(m, n, state, possibleRects)
    Eopt = E
    k = 1
    while k <= kMax && E > m * n
        sk = randomNeighbor(state, possibleRects)
        Ek = energy(m, n, sk, possibleRects)
        if Ek < E || rand() < exp(-(Ek - E) / T)
            state = sk
            E = Ek
            if E < Eopt
                Eopt = E
                optState = state
            end
        end
        T = lambda * T
        k += 1
    end

    rects = Vector{Tuple{Int,Int,Int,Int}}(undef, p)
    for k = 1:p
        rects[k] = possibleRects[k][optState[k]]
    end

    isOptimal = Eopt == m * n
    return isOptimal, rects
end

function energy(m::Int, n::Int, state::Vector{Int}, possibleRects::Vector{Vector{Tuple{Int,Int,Int,Int}}})
    E = 0
    p = length(state)
    grid = fill(0, m, n)
    for k = 1:p
        i1, j1, i2, j2 = possibleRects[k][state[k]]
        for i in i1:i2,j in j1:j2
            grid[i,j] += 1
        end
    end

    for i in 1:m, j in 1:n
        E += grid[i,j]^2
    end

    return E
end

function randomNeighbor(state::Vector{Int}, possibleRects::Vector{Vector{Tuple{Int,Int,Int,Int}}})
    p = length(state)
    k = ceil(Int, rand() * p)
    l = ceil(Int, rand() * length(possibleRects[k]))
    newState = copy(state)
    newState[k] = l
    return newState
end

"""
Solve all the instances contained in "../data" through IP and heuristics

The results are written in "../res/gurobi", "../res/cbc" and "../res/heuristic"

Remark: If an instance has previously been solved (either by cplex or the heuristic) it will not be solved again
"""
function solveDataSet()

    dataFolder = "../data/"
    resFolder = "../res/"

    # Array which contains the name of the resolution methods
    resolutionMethod = ["gurobi", "cbc", "heuristic"]
    # resolutionMethod = ["cbc", "gurobi", "heuristic"]

    # Array which contains the result folder of each resolution method
    resolutionFolder = resFolder .* resolutionMethod

    # Create each result folder if it does not exist
    for folder in resolutionFolder
        if !isdir(folder)
            mkdir(folder)
        end
    end

    global isOptimal = false
    global solveTime = -1

    # For each instance
    # (for each file in folder dataFolder which ends by ".txt")
    for file in filter(x->occursin(".txt", x), readdir(dataFolder))

        println("-- Resolution of ", file)
        grid = readInputFile(dataFolder * file)


        # For each resolution method
        for methodId in 1:size(resolutionMethod, 1)

            outputFile = resolutionFolder[methodId] * "/" * file

            # If the instance has not already been solved by this method
            if !isfile(outputFile)

                fout = open(outputFile, "w")

                resolutionTime = -1
                isOptimal = false

                if resolutionMethod[methodId] == "gurobi"
                    optimizer = Gurobi.Optimizer 
                    # Solve it and get the results
                    isOptimal, resolutionTime, sol = ipSolve(grid, optimizer)
                elseif resolutionMethod[methodId] == "cbc"
                    optimizer = Cbc.Optimizer 
                    # Solve it and get the results
                    isOptimal, resolutionTime, sol = ipSolve(grid, optimizer)
                else # heuristic
                    # Start a chronometer
                    startingTime = time()
                    kMax = 1000
                    initT = 1000.0

                    while !isOptimal && kMax <= 1000000
                        # Solve it and get the results
                        isOptimal, sol = heuristicSolve(grid, kMax, initT, 0.999)

                        # Stop the chronometer
                        resolutionTime = time() - startingTime
                        kMax *= 10
                        initT *= 100
                    end
                end

                println(fout, "solveTime = ", resolutionTime)
                println(fout, "isOptimal = ", isOptimal)

                if isOptimal
                    writeSolution(fout, grid, sol)
                end

                close(fout)
            end


            # Display the results obtained with the method on the current instance
            include(outputFile)
            println(resolutionMethod[methodId], " optimal: ", isOptimal)
            println(resolutionMethod[methodId], " time: " * string(round(solveTime, sigdigits = 2)) * "s\n")
        end
    end
end

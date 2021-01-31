# This file contains methods to generate a data set of instances (i.e., sudoku grids)
include("io.jl")

"""
Generate a m*n grid with k numbers

Argument
- m: number of rows
- n: number of columns
- depth: depth of recursion, the deeper the more rectangles
"""
function generateInstance(m::Int, n::Int, depth::Int, nbMergeIter::Int, mergeProb::Float64)
    grid = fill(0, m, n)
    rectSplit = rectangleSplit((1, 1, m, n), depth)

    # Merge some rectangles
    for k = 1:nbMergeIter
        toRemove = Set{Tuple{Int,Int,Int,Int}}()
        toAdd = Vector{Tuple{Int,Int,Int,Int}}()
        for rect1 in rectSplit, rect2 in rectSplit
            if rect1 == rect2 || rect1 in toRemove || rect2 in toRemove
                continue
            end
            (i1, j1, i2, j2) = rect1
            (i3, j3, i4, j4) = rect2
            if i1 == i3 && i2 == i4 && (j3 - j2 == 1 || j1 - j4 == 1) && rand() < mergeProb # rects are horizontally aligned
                push!(toRemove, rect1)
                push!(toRemove, rect2)
                push!(toAdd, (i1, min(j1, j3), i2, max(j2, j4)))
            elseif j1 == j3 && j2 == j4 && (i3 - i2 == 1 || i1 - i4 == 1) && rand() < mergeProb # rects are vertically aligned
                push!(toRemove, rect1)
                push!(toRemove, rect2)
                push!(toAdd, (min(i1, i3), j1, max(i2, i4), j2))
            end
        end
        filter!((x)->x ∉ toRemove, rectSplit)
        rectSplit = vcat(rectSplit, toAdd)
    end

    for (i1, j1, i2, j2) in rectSplit
        area = (i2 - i1 + 1) * (j2 - j1 + 1)
        i = i1 + ceil(Int, rand() * (i2 - i1))
        j = j1 + ceil(Int, rand() * (j2 - j1))
        grid[i,j] = area
    end
    return grid
end

function rectangleSplit(rectangle::Tuple{Int,Int,Int,Int}, depth::Int)
    i1, j1, i2, j2 = rectangle
    H = i2 - i1 + 1
    W = j2 - j1 + 1
    if depth == 0 || H * W <= 3 
        return [rectangle]
    end

    if i1 == i2 && j1 != j2
        sp = false
    elseif j1 == j2 && i1 != i2
        sp = true
    else
        sp = (H + W) * rand() < H
    end 
    if sp
        iSplit = i1 + ceil(Int, rand() * min(i2 - i1 - 2, max(1, i2 - i1 - 2)))
        return vcat(rectangleSplit((i1, j1, iSplit, j2), depth - 1), rectangleSplit((iSplit + 1, j1, i2, j2), depth - 1))
    else
        jSplit = j1 + ceil(Int, rand() * min(j2 - j1 - 2, max(1, j2 - j1 - 2)))
        return vcat(rectangleSplit((i1, j1, i2, jSplit), depth - 1), rectangleSplit((i1, jSplit + 1, i2, j2), depth - 1))
    end
end


"""
Generate all the instances

Remark: a grid is generated only if the corresponding output file does not already exist
"""
function generateDataSet()

    sizes = [4, 9, 16, 25]
    # For each grid size considered
    for size in sizes
        m = size
        n = size
        # For each depth considered
        for depth in 1:(size ÷ 2)
            for nbMergeIter = 0:3
            # Generate 5 instances
                for instance in 1:5
                    fileName = "../data/instance_h" * string(m) * "_w" * string(n) * "_d" * string(depth) * "_it" * string(nbMergeIter) * "_" * string(instance) * ".txt"
                    if !isfile(fileName)
                        println("-- Generating file " * fileName)
                        saveInstance(generateInstance(m, n, depth, nbMergeIter, 0.5), fileName)
                    end 
                end
            end
        end
    end
    
end




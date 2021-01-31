# This file contains functions related to reading, writing and displaying a grid and experimental results

using JuMP
using Plots
using DelimitedFiles
import GR

"""
Read an instance from an input file

- Argument:
inputFile: path of the input file
"""
function readInputFile(inputFile::String)
    return readdlm(inputFile, ',', Int, '\n')
end

function saveInstance(grid::Array{Int,2}, fileName)
    open(fileName, "w") do io
        writedlm(io, grid, ',')
    end
end

"""
Write a solution in an output stream

Arguments
- fout: the output stream (usually an output file)
- grid: 2-dimensional array representing the initial game state
- sol: solution of the game consisting of a list of rectangle coordinates
"""
function writeSolution(fout::IOStream, grid::Array{Int, 2}, sol::Vector{Tuple{Int,Int,Int,Int}})

    println(fout, "grid = [")
    m, n = size(grid)
    
    for i = 1:m
        for j = 1:n
            print(fout, string(grid[i, j]) * " ")
        end 

        println(fout, ";")
    end
    println(fout, "]")
    println(fout, "sol = [")
    for rect in sol
        println(fout, rect)
        print(fout, ",")
    end
    println(fout, "]")
end

"""
Display grid

Arguments
- grid: 2-dimensional array representing the initial game state
"""
function displayGrid(grid::Array{Int, 2})
    m, n = size(grid)

    cellWidth = digitCount(maximum(grid))
    
    # Grid that will be displayed
    dispGrid = fill(repeat(' ', cellWidth), 2*m+1, 2*n+1)

    # Add the numbers to the grid
    for i = 1:m
        for j = 1:n
            if grid[i,j] > 0
                dispGrid[2*i,2*j] = intToString(grid[i,j], cellWidth)
            end
        end
    end

    # Add a frame around the grid
    for i = 1:2*m+1
        dispGrid[i, 1] = "|"
        dispGrid[i, 2*n+1] = "|"
    end
    for j = 1:2*n+1
        dispGrid[1, j] = "-"
        dispGrid[2*m+1,j] = "-"
    end

    # Print the grid
    for i = 1:2*m+1
        for j=1:2*n+1
            print(dispGrid[i,j])
        end
        println()
    end
end

"""
Display solution

Arguments
- grid: 2-dimensional array representing the initial game state
- sol: rectangles of the solved game
"""
function displaySolution(grid::Array{Int, 2}, sol::Vector{Tuple{Int, Int, Int, Int}})
    m, n = size(grid)

    cellWidth = digitCount(maximum(grid))
    
    # Grid that will be displayed
    dispGrid = fill(" ",2*m+1, 2*n+1)

    # Add the numbers to the grid
    for i = 1:m
        for j = 1:n
            if grid[i,j] > 0
                dispGrid[2*i,2*j] = intToString(grid[i,j], cellWidth)
            else
                dispGrid[2*i,2*j] = repeat(' ', cellWidth)
            end
            dispGrid[2*i-1,2*j] = repeat(' ', cellWidth)
            dispGrid[2*i+1,2*j] = repeat(' ', cellWidth)
        end
    end

    # Add a frame around the grid
    # for i = 1:2*m+1
    #     dispGrid[i, 1] = "|"
    #     dispGrid[i, 2*n+1] = "|"
    # end
    # for j = 1:2*n+1
    #     dispGrid[1, j] = "-"
    #     dispGrid[2*m+1,j] = "-"
    # end

    # Add the rectangles
    for (i1, j1, i2, j2) in sol
        for i=i1:i2
            dispGrid[2*i,2*j1-1] = "|"
            dispGrid[2*i,2*j2+1] = "|"
        end
        for j=j1:j2
            dispGrid[2*i1-1,2*j] = repeat("-", cellWidth)
            dispGrid[2*i2+1,2*j] = repeat("-", cellWidth)
        end
    end

    # Print the grid
    for i = 1:2*m+1
        for j=1:2*n+1
            print(dispGrid[i,j])
        end
        println()
    end
end

function digitCount(n::Int)
    c = 0
    while n > 0
        n = n ÷ 10
        c += 1
    end
    return c
end

"""
Returns the string representation of an integer n of length strLen, with space padding if necessary
"""
function intToString(n::Int, strLen::Int)
    res = string(n)
    l = length(res)
    return "$(repeat(' ', strLen - l))$res"
end

"""
Create a pdf file which contains a performance diagram associated to the results of the ../res folder
Display one curve for each subfolder of the ../res folder.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
- Each text file contains a variable "solveTime" and a variable "isOptimal"
"""
function performanceDiagram(outputFile::String)

    resultFolder = "../res/"
    
    # Maximal number of files in a subfolder
    maxSize = 0

    # Number of subfolders
    subfolderCount = 0

    folderName = Array{String, 1}()

    # For each file in the result folder
    for file in readdir(resultFolder)

        path = resultFolder * file
        
        # If it is a subfolder
        if isdir(path)
            
            folderName = vcat(folderName, file)
             
            subfolderCount += 1
            folderSize = size(readdir(path), 1)

            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    # Array that will contain the resolution times (one line for each subfolder)
    results = Array{Float64}(undef, subfolderCount, maxSize)

    for i in 1:subfolderCount
        for j in 1:maxSize
            results[i, j] = Inf
        end
    end

    folderCount = 0
    maxSolveTime = 0

    # For each subfolder
    for file in readdir(resultFolder)
            
        path = resultFolder * file
        
        if isdir(path)

            folderCount += 1
            fileCount = 0

            # For each text file in the subfolder
            for resultFile in filter(x->occursin(".txt", x), readdir(path))

                fileCount += 1
                include(path * "/" * resultFile)

                if isOptimal
                    results[folderCount, fileCount] = solveTime

                    if solveTime > maxSolveTime
                        maxSolveTime = solveTime
                    end 
                end 
            end 
        end
    end 

    # Sort each row increasingly
    results = sort(results, dims=2)

    println("Max solve time: ", maxSolveTime)

    # For each line to plot
    for dim in 1: size(results, 1)

        x = Array{Float64, 1}()
        y = Array{Float64, 1}()

        # x coordinate of the previous inflexion point
        previousX = 0
        previousY = 0

        append!(x, previousX)
        append!(y, previousY)
            
        # Current position in the line
        currentId = 1

        # While the end of the line is not reached 
        while currentId != size(results, 2) && results[dim, currentId] != Inf

            # Number of elements which have the value previousX
            identicalValues = 1

             # While the value is the same
            while results[dim, currentId] == previousX && currentId <= size(results, 2)
                currentId += 1
                identicalValues += 1
            end

            # Add the proper points
            append!(x, previousX)
            append!(y, currentId - 1)

            if results[dim, currentId] != Inf
                append!(x, results[dim, currentId])
                append!(y, currentId - 1)
            end
            
            previousX = results[dim, currentId]
            previousY = currentId - 1
            
        end

        append!(x, maxSolveTime)
        append!(y, currentId - 1)

        # If it is the first subfolder
        if dim == 1

            # Draw a new plot
            plot(x, y, label = folderName[dim], legend = :bottomright, xaxis = "Time (s)", yaxis = "Solved instances",linewidth=3)

        # Otherwise 
        else
            # Add the new curve to the created plot
            savefig(plot!(x, y, label = folderName[dim], linewidth=3), outputFile)
        end 
    end
end 

"""
Create a latex file which contains an array with the results of the ../res folder.
Each subfolder of the ../res folder contains the results of a resolution method.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
- Each text file contains a variable "solveTime" and a variable "isOptimal"
"""
function resultsArray(outputFile::String)
    
    resultFolder = "../res/"
    dataFolder = "../data/"
    
    # Maximal number of files in a subfolder
    maxSize = 0

    # Number of subfolders
    subfolderCount = 0

    # Open the latex output file
    fout = open(outputFile, "w")

    # Print the latex file output
    println(fout, raw"""\documentclass{article}

\usepackage[french]{babel}
\usepackage [utf8] {inputenc} % utf-8 / latin1 
\usepackage{multicol}

\setlength{\hoffset}{-18pt}
\setlength{\oddsidemargin}{0pt} % Marge gauche sur pages impaires
\setlength{\evensidemargin}{9pt} % Marge gauche sur pages paires
\setlength{\marginparwidth}{54pt} % Largeur de note dans la marge
\setlength{\textwidth}{481pt} % Largeur de la zone de texte (17cm)
\setlength{\voffset}{-18pt} % Bon pour DOS
\setlength{\marginparsep}{7pt} % Séparation de la marge
\setlength{\topmargin}{0pt} % Pas de marge en haut
\setlength{\headheight}{13pt} % Haut de page
\setlength{\headsep}{10pt} % Entre le haut de page et le texte
\setlength{\footskip}{27pt} % Bas de page + séparation
\setlength{\textheight}{668pt} % Hauteur de la zone de texte (25cm)

\begin{document}""")

    header = raw"""
\begin{center}
\renewcommand{\arraystretch}{1.4} 
 \begin{tabular}{l"""

    # Name of the subfolder of the result folder (i.e, the resolution methods used)
    folderName = Array{String, 1}()

    # List of all the instances solved by at least one resolution method
    solvedInstances = Array{String, 1}()

    # For each file in the result folder
    for file in readdir(resultFolder)

        path = resultFolder * file
        
        # If it is a subfolder
        if isdir(path)

            # Add its name to the folder list
            folderName = vcat(folderName, file)
             
            subfolderCount += 1
            folderSize = size(readdir(path), 1)

            # Add all its files in the solvedInstances array
            for file2 in filter(x->occursin(".txt", x), readdir(path))
                solvedInstances = vcat(solvedInstances, file2)
            end 

            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    # Only keep one string for each instance solved
    unique(solvedInstances)

    # For each resolution method, add two columns in the array
    for folder in folderName
        header *= "rr"
    end

    header *= "}\n\t\\hline\n"

    # Create the header line which contains the methods name
    for folder in folderName
        header *= " & \\multicolumn{2}{c}{\\textbf{" * folder * "}}"
    end

    header *= "\\\\\n\\textbf{Instance} "

    # Create the second header line with the content of the result columns
    for folder in folderName
        header *= " & \\textbf{Temps (s)} & \\textbf{Optimal ?} "
    end

    header *= "\\\\\\hline\n"

    footer = raw"""\hline\end{tabular}
\end{center}

"""
    println(fout, header)

    # On each page an array will contain at most maxInstancePerPage lines with results
    maxInstancePerPage = 30
    id = 1

    # For each solved files
    for solvedInstance in solvedInstances

        # If we do not start a new array on a new page
        if rem(id, maxInstancePerPage) == 0
            println(fout, footer, "\\newpage")
            println(fout, header)
        end 

        # Replace the potential underscores '_' in file names
        print(fout, replace(solvedInstance, "_" => "\\_"))

        # For each resolution method
        for method in folderName

            path = resultFolder * method * "/" * solvedInstance

            # If the instance has been solved by this method
            if isfile(path)

                include(path)

                println(fout, " & ", round(solveTime, digits=2), " & ")

                if isOptimal
                    println(fout, "\$\\times\$")
                end 
                
            # If the instance has not been solved by this method
            else
                println(fout, " & - & - ")
            end
        end

        println(fout, "\\\\")

        id += 1
    end

    # Print the end of the latex file
    println(fout, footer)

    println(fout, "\\end{document}")

    close(fout)
    
end 
#! /usr/bin/env julia

using ArgParse
using Gumbo
using Cascadia
using AbstractTrees
import Base.replace!


# get all HTML elements from HTML documents of the given directory
function get_elements(directory)
    files = HTMLfiles(directory)

    elements = Dict()
    foreach(files) do file
        doc = parsehtml(read(file, String))
        for element in PreOrderDFS(doc.root)
            if element isa HTMLText continue end
            if "id" ∈ keys(element.attributes)
                ischild = false
                id = element.attributes["id"]
                sel = Selector("#$id")
                foreach(values(elements)) do element
                    matched = eachmatch(sel, element) |> collect
                    if length(matched) > 0
                        ischild = true
                    end
                end

                if !ischild
                    push!(elements, id => element)
                end
            end
        end
    end

    return elements
end

# get all HTML documents from given directory, and replace elements with matching IDs with given elements
function replace_elements!(elements, directory = pwd())
    files = HTMLfiles(directory)

    for file in files
        changes = false
        doc = parsehtml(read(file, String))
        for element in PreOrderDFS(doc.root)
            if element isa HTMLText continue end
            if "id" ∈ keys(element.attributes)
                for id in keys(elements)
                    if id == getattr(element, "id")
                        if !isequal(element, elements[id])
                            println("replace \"$id\" in $file")
                            replace_nodes!(element => elements[id])
                            changes = true
                        end
                    end
                end
            end
        end

        if changes
            open(file, "w") do io
                print(io, doc.root, pretty = true)
            end
        end
    end
end

# checks if HTML elements are equal
function isequal(one::HTMLNode, another::HTMLNode)
    remove_whitespace(string(one)) == remove_whitespace(string(another))
end

# remove white space in a string
function remove_whitespace(string::String)
    tmp = replace(string, " " => "")
    tmp = replace(tmp, "\n" => "")
    tmp = replace(tmp, "\t" => "")
end

# get paths to all HTML files in the given directory
function HTMLfiles(directory)
    files = map(x->joinpath(directory, x), readdir(directory))
    filter!(f->isfile(f) && endswith(f, r".html|.htm"), files)

    return files
end

# replace one HTMLNodes by another
function replace_nodes!(old_new::Pair{<:HTMLNode,<:HTMLNode})
    parent = old_new.first.parent
    for i in 1:length(parent.children)
        if old_new.first == parent.children[i]
            parent.children[i] = old_new.second
        end
    end
end


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "source"
        help = "a directory with HTML documents acting as templates, containing common HTML elements"
        required = true
        "target"
        help = "a directory with HTML documnets, containing HTML elements to be replaced by matching elements from source directory"
        required = false
    end
    
    return parse_args(s)
end

function main()
    args = parse_commandline()

    elements = get_elements(args["source"])
    if args["target"] !== nothing
        replace_elements!(elements, args["target"])
    else
        replace_elements!(elements)
    end
end

main()
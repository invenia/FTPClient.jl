function is_headers_equal(original::AbstractArray{A}, expected::AbstractArray{B}) where {A<:AbstractString, B<:AbstractString}
    length(original) == length(expected) || return false
    for (a, b) in zip(original, expected)
        is_header_equal(a, b) || return false
    end
    return true
end

"""
    is_header_equal(original, expected) -> Bool

Compares a header line returned from the server with a simplified pattern matching that
supports `...` to match any number of characters and `||` which allows for alternatives.
Note we could use regular expressions directly to compare the headers but this can be
annoying to escape most of the expected headers. If more and more functionality is needed
to match against headers regular expressions should be used instead.
"""
function is_header_equal(original::AbstractString, expected::AbstractString)
    if occursin("...", expected) || occursin("||", expected)
        # Change `...` to `.*` and `||` to `|` while quoting the rest of the string.
        expected = replace(expected, "..." => "\\E.*\\Q")
        expected = replace(expected, "||" => "\\E|\\Q")
        expected = string("^(?:\\Q", expected, "\\E)\$")

        # Remove empty quoted sections
        expected = replace(expected, "\\Q\\E" => "")
        return occursin(Regex(expected), original)
    else
        return original == expected
    end
end

function cleanup_file(filename::AbstractString)
    if isfile(filename)
        rm(filename)
    end
    @test !isfile(filename)
end

function cleanup_dir(dirname::AbstractString, recursive = true)
    if isdir(dirname)
        rm(dirname)
    end
    @test !isdir(dirname)
end

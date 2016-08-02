function is_headers_equal{A<:AbstractString, B<:AbstractString}(original::AbstractArray{A}, expected::AbstractArray{B})
    length(original) == length(expected) || return false
    for (a, b) in zip(original, expected)
        is_header_equal(a, b) || return false
    end
    return true
end

function is_header_equal(original::AbstractString, expected::AbstractString)
    if contains(expected, "...")
        # Change `...` to `.*` while quoting the rest of the string.
        expected = string("^\\Q", replace(expected, "...", "\\E.*\\Q"), "\\E\$")
        expected = replace(expected, "\\Q\\E", "")  # Remove empty quoted sections
        return ismatch(Regex(expected), original)
    else
        return original == expected
    end
end

function cleanup_file(filename::AbstractString)
    if (isfile(filename))
        rm(filename)
    end
    @test !isfile(filename)
end

function cleanup_dir(dirname::AbstractString, recursive = true)
    if (isdir(dirname))
        rm(dirname)
    end
    @test !isdir(dirname)
end

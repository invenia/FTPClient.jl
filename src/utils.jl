function safe_uri(uri::URI)
    parts = split(uri.userinfo, ':', limit=2)

    userinfo = if length(parts) > 1
        parts[1] * ":*****"
    else
        parts[1]
    end

    URI(uri; userinfo=userinfo)
end

safe_uri(uri::AbstractString) = string(safe_uri(URI(uri)))

function trailing(str::AbstractString, tail::Char)
    endswith(str, tail) ? str : string(str, tail)
end

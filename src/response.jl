"""
    Response

The response returned from a connection to an FTP server.

# Parameters
* `body::IO`: contains the result of a command from ftp_command.
    or the content of a downloaded file from ftp_get (if no destination file was defined).
* `headers::Array{AbstractString}`: the header responses from the server.
* `code::UInt`: the last header response code from the server.
* `total_time::Float64`: the time the connection took.
* `bytes_recd::Int`: the amount of bytes transmitted from the server (the file size in the
    case of ftp_get).
"""
mutable struct Response
    body::IO
    headers::Array{AbstractString}
    code::UInt
    total_time::Float64
    bytes_recd::Int

    Response() = new(IOBuffer(), AbstractString[], 0, 0.0, 0)
end

function Base.show(io::IO, o::Response)
    println(io, "Response Code :", o.code)
    println(io, "Request Time  :", o.total_time)
    println(io, "Headers       :", o.headers)
    println(io, "Length of body: ", o.bytes_recd)
end

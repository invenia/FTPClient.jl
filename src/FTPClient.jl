__precompile__()

module FTPClient

using URIParser: URI

mutable struct FTPClientError <: Exception
    msg::AbstractString
    lib_curl_error::UInt32
end

@enum FTP_MODE ascii_mode binary_mode
Base.showerror(io::IO, err::FTPClientError) = print(io, err.msg, " :: LibCURL error #", err.lib_curl_error)

export RequestOptions,
    Response,
    ConnContext,
    ftp_init,
    ftp_cleanup,
    ftp_connect,
    ftp_close_connection,
    ftp_get,
    ftp_put,
    ftp_command,
    FTP,
    ftp,
    upload,
    download,
    rmdir,
    FTPClientError,
    FTP_MODE,
    ascii_mode,
    binary_mode,
    close

include("utils.jl")
include("FTPC.jl")
include("response.jl")
include("request_options.jl")
include("conn_context.jl")
include("FTPObject.jl")

const C_WRITE_FILE_CB = Ref{Ptr{Cvoid}}(C_NULL)
const C_HEADER_COMMAND_CB = Ref{Ptr{Cvoid}}(C_NULL)
const C_CURL_READ_CB = Ref{Ptr{Cvoid}}(C_NULL)

function __init__()
    C_WRITE_FILE_CB[] = @cfunction(write_file_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))
    C_HEADER_COMMAND_CB[] = @cfunction(header_command_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))
    C_CURL_READ_CB[] = @cfunction(curl_read_cb, Csize_t, (Ptr{Cvoid}, Csize_t, Csize_t, Ptr{Cvoid}))
end

end


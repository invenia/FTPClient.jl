module FTPClient

using Compat

if VERSION >= v"0.5-"
       typealias RemoteRef Future
else
       typealias unsafe_write write
end

import Base: convert, show, open, mkdir, ascii, mv
import Base: readdir, cd, pwd, rm, close, download

type FTPClientError <: Exception
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
       ascii,
       binary,
       ascii_mode,
       binary_mode

include("FTPC.jl")
include("FTPObject.jl")

end


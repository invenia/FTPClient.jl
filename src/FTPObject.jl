# FTP code for when the file transfer is complete.
const complete_transfer_code = 226


mutable struct FTP
    ctxt::ConnContext

    function FTP(ctxt::ConnContext)
        ftp = new(ctxt)
        @compat finalizer(close, ftp)  # 0.7.0-DEV.2562
        return ftp
    end
end

function FTP(options::RequestOptions; verbose::Union{Bool,IOStream}=false)
    ctxt = setup_easy_handle(options; verbose=verbose)
    return FTP(ctxt)
end

"""
    FTP(; kwargs...) -> FTP

Create an FTP object.

# Keywords
- `hostname::AbstractString=""`: the hostname or address of the FTP server.
- `username::AbstractString=""`: the username used to access the FTP server.
- `password::AbstractString=""`: the password used to access the FTP server.
- `ssl::Bool=false`: use a secure FTP connection.
- `implicit::Bool=false`: use implicit security (FTPS).
- `verify_peer::Bool=true`: verify authenticity of peer's certificate.
- `active_mode::Bool=false`: use active mode to establish data connection.
- `verbose::Union{Bool,IOStream}=false`: an `IOStream` to capture LibCurl's output or a
    `Bool`, if true output is written to STDERR.
"""
function FTP(;
    hostname::AbstractString="",
    port::Integer=0,
    username::AbstractString="",
    password::AbstractString="",
    ssl::Bool=false,
    implicit::Bool=false,
    verify_peer::Bool=true,
    active_mode::Bool=false,
    verbose::Union{Bool,IOStream}=false,
)
    options = RequestOptions(
        username=username, password=password, hostname=hostname, port=port,
        ssl=ssl, implicit=implicit, verify_peer=verify_peer, active_mode=active_mode,
    )

    FTP(options; verbose=verbose)
end

"""
    FTP(url; kwargs...)

Connect to an FTP server using the information specified in the URI.

# Keywords
- `verify_peer::Bool=true`: verify the authenticity of the peer's certificate.
- `active_mode::Bool=false`: use active mode to establish data connection.

# Example
```julia
julia> FTP("ftp://user:password@ftp.example.com");  # FTP connection with no security

julia> FTP("ftpes://user:password@ftp.example.com");  # Explicit security (FTPES)

julia> FTP("ftps://user:password@ftp.example.com");  # Implicit security (FTPS)
```
"""
function FTP(
    url::AbstractString;
    verify_peer::Bool=true,
    active_mode::Bool=false,
    verbose::Union{Bool,IOStream}=false,
)
    options = RequestOptions(url; verify_peer=verify_peer, active_mode=active_mode)
    FTP(options; verbose=verbose)
end

function show(io::IO, ftp::FTP)
    opts = ftp.ctxt.options
    join(io, [
        "URL:       $(safe_uri(ftp.ctxt.url))",
        "Transfer:  $(ispassive(opts) ? "passive" : "active") mode",
        "Security:  $(security(opts))",
    ], "\n")
end

"""
    close(ftp::FTP)

Close FTP connection.
"""
function close(ftp::FTP)
    ftp_close_connection(ftp.ctxt)
end

"""
    download(
        ftp::FTP,
        file_name::AbstractString,
        save_path::AbstractString="";
        mode::FTP_MODE=binary_mode,
    )

Download the file "file_name" from FTP server and return IOStream.
If "save_path" is not specified, contents are written to and returned as an IOBuffer.
"""
function download(
    ftp::FTP,
    file_name::AbstractString,
    save_path::AbstractString="";
    mode::FTP_MODE=binary_mode,
    verbose=nothing,
)
    _dep_verbose_kw(verbose, typeof(ftp), :download)
    resp = nothing
    try
        resp = ftp_get(ftp.ctxt, file_name, save_path; mode=mode, verbose=verbose)
    catch err
        if isa(err, FTPClientError)
            err.msg = "Failed to download $file_name."
        end
        rethrow()
    end
    return resp.body
end

"""
    upload(
        ftp::FTP,
        local_path_io::IO,
        remote_path::AbstractString;
        ftp_options=ftp.ctxt,
        mode::FTP_MODE=binary_mode,
        verbose=nothing
) -> Response

Upload IO object "local_path_io" to the FTP server and save as "remote_path".

# Arguments
- `ftp::FTP`: The FTP to deliver to. See FTPClient.FTP for details.
- `local_path_io::IO`: The IO object that we want to deliver.
- `remote_path::AbstractString`: The path that we want to deliver to.

# Keywords
- `ftp_options=ftp.ctxt`: FTP Options
- `mode::FTP_MODE=binary_mode`: Set the ftp mode.
- `verbose=nothing`: Set the verbosity

# Returns
`FTPResponse`: Returns the ftp response object
"""
function upload(
    ftp::FTP,
    local_path_io::IO,
    remote_path::AbstractString;
    ftp_options=ftp.ctxt,
    mode::FTP_MODE=binary_mode,
    verbose=nothing,
)
    _dep_verbose_kw(verbose, typeof(ftp), :upload)

    resp = nothing

    try
        resp = ftp_put(ftp_options, remote_path, local_path_io; mode=mode, verbose=verbose)
    catch e
        if isa(e, FTPClientError)
            e.msg = "Failed to upload $remote_path"
        end
        rethrow()
    end
    return resp
end


"""
    upload(
        ftp::FTP,
        local_path::AbstractString,
        remote_path::AbstractString;
        ftp_options=ftp.ctxt,
        mode::FTP_MODE=binary_mode,
        verbose=nothing,
    ) -> Response

Uploads the file specified in "local_path" to the file or directory specifies in
"remote_path".

If "remote_path" is a full file name path, then the file will be uploaded to the FTP
using the full file path name. If "remote_path" is a path to a directory (which means
it ends in "/"), then the file will be uploaded to the specified directory but with the
"local_path" basename as the file name.

# Arguments
- `ftp::FTP`: The FTP to deliver to. See FTPClient.FTP for details.
- `local_path::AbstractString`: The file path to the file we want to deliver.
- `remote_path::AbstractString`: The file/dir path that we want to deliver to.

# Keywords
- `ftp_options=ftp.ctxt`: FTP Options
- `mode::FTP_MODE=binary_mode`: Set the ftp mode.
- `verbose=nothing`: Set the verbosity

# Returns
`FTPResponse`: Returns the ftp response object
"""
function upload(
    ftp::FTP,
    local_path::AbstractString,
    remote_path::AbstractString;
    ftp_options=ftp.ctxt,
    mode::FTP_MODE=binary_mode,
    verbose=nothing
)
    _dep_verbose_kw(verbose, typeof(ftp), :upload)

    # The location we are going to drop the file in the FTP server
    if basename(remote_path) == ""
        # If the remote path was just a directory, then the full remote path should be
        # that directory plus the basename of the local_path
        server_location = joinpath(dirname(remote_path), basename(local_path))
    elseif basename(remote_path) == "."
        # Handle the special case where remote_path ends with '.'
        # Since the dirname/basename strategy doesn't work in this specific case, we just
        # handle it here.
        server_location = joinpath(remote_path, basename(local_path))
    else
        # If the remote path is a full file path, then just use that
        server_location = remote_path
    end

    # ftp_put requires an io, so open the file
    open(local_path) do local_path_io
        return upload(
            ftp, local_path_io, server_location;
            ftp_options=ftp_options, mode=mode, verbose=verbose
        )
    end
end

"""
    readdir(ftp::FTP)

Return the contents of the current working directory of the FTP server.
"""
function readdir(ftp::FTP; verbose=nothing)
    _dep_verbose_kw(verbose, typeof(ftp), :readdir)
    resp = nothing

    try
        resp = ftp_command(ftp.ctxt, "LIST"; verbose=verbose)
    catch err
        if isa(err, FTPClientError)
            err.msg = "Failed to list directories."
        end
        rethrow()
    end

    dir = split(read(resp.body, String), '\n')
    dir = filter(x -> !isempty(x), dir)
    dir = [join(split(line)[9:end], ' ') for line in dir]
end


"""
    cd(ftp::FTP, dir::AbstractString)

Set the current working directory of the FTP server to "dir".
"""
function cd(ftp::FTP, dir::AbstractString; verbose=nothing)
    _dep_verbose_kw(verbose, typeof(ftp), :cd)
    resp = ftp_command(ftp.ctxt, "CWD $dir"; verbose=verbose)

    if resp.code != 250
        throw(FTPClientError("Failed to change to directory $dir. $(resp.code)", 0))
    end
end


"""
    pwd(ftp::FTP)

Get the current working directory of the FTP server
"""
function pwd(ftp::FTP; verbose=nothing)
    _dep_verbose_kw(verbose, typeof(ftp), :pwd)
    resp = ftp_command(ftp.ctxt, "PWD"; verbose=verbose)

    if resp.code != 257
        throw(FTPClientError("Failed to get the current working directory. $(resp.code)", 0))
    end

    dir = split(resp.headers[end], '\"')[end-1]
end


"""
    rm(ftp::FTP, file_name::AbstractString)

Delete file "file_name" from FTP server.
"""
function rm(ftp::FTP, file_name::AbstractString; verbose=nothing)
    _dep_verbose_kw(verbose, typeof(ftp), :rm)
    resp = ftp_command(ftp.ctxt, "DELE $file_name"; verbose=verbose)

    if resp.code != 250
        throw(FTPClientError("Failed to remove $file_name. $(resp.code)", 0))
    end
end


"""
    rmdir(ftp::FTP, dir_name::AbstractString)

Delete directory "dir_name" from FTP server.
"""
function rmdir(ftp::FTP, dir_name::AbstractString; verbose=nothing)
    _dep_verbose_kw(verbose, typeof(ftp), :rmdir)
    resp = ftp_command(ftp.ctxt, "RMD $dir_name"; verbose=verbose)

    if resp.code != 250
        throw(FTPClientError("Failed to remove $dir_name. $(resp.code)", 0))
    end
end


"""
    mkdir(ftp::FTP, dir::AbstractString)

Make directory "dir" on FTP server.
"""
function mkdir(ftp::FTP, dir::AbstractString; verbose=nothing)
    _dep_verbose_kw(verbose, typeof(ftp), :mkdir)
    resp = ftp_command(ftp.ctxt, "MKD $dir"; verbose=verbose)

    if resp.code != 257
        throw(FTPClientError("Failed to make $dir. $(resp.code)", 0))
    end
end


"""
    mv(
        ftp::FTP,
        file_name::AbstractString,
        new_name::AbstractString;
    )

Move (rename) file "file_name" to "new_name" on FTP server.
"""
function mv(
    ftp::FTP,
    file_name::AbstractString,
    new_name::AbstractString;
    verbose=nothing,
)
    _dep_verbose_kw(verbose, typeof(ftp), :mv)
    resp = ftp_command(ftp.ctxt, "RNFR $file_name"; verbose=verbose)

    if resp.code != 350
        throw(FTPClientError("Failed to move $file_name. $(resp.code)", 0))
    end

    resp = ftp_command(ftp.ctxt, "RNTO $new_name"; verbose=verbose)

    if resp.code != 250
        throw(FTPClientError("Failed to move $file_name. $(resp.code)", 0))
    end
end

"""
    ftp(
        code::Function;
        hostname::AbstractString="", implicit::Bool=false, ssl::Bool=false,
        verify_peer::Bool=true, active_mode::Bool=false, username::AbstractString="",
        password::AbstractString="", verbose::Union{Bool,IOStream}=false,
    )

Execute Function "code" on FTP server.
"""
function ftp(
    code::Function;
    hostname::AbstractString="", port::Integer=0, implicit::Bool=false, ssl::Bool=false,
    verify_peer::Bool=true, active_mode::Bool=false, username::AbstractString="",
    password::AbstractString="", verbose::Union{Bool,IOStream}=false,
)
    ftp_init()
    ftp_client = FTP(
        hostname=hostname, port=port, implicit=implicit, ssl=ssl, verify_peer=verify_peer,
        active_mode=active_mode, username=username, password=password, verbose=verbose,
    )

    try
        code(ftp_client)
    finally
        close(ftp_client)
        ftp_cleanup()
    end
end

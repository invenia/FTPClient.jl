"""
    FTP(; kwargs...) -> FTP

Create an FTP object.

# Arguments
* `hostname::AbstractString=""`: the hostname or address of the FTP server.
* `implicit::Bool=false`: use implicit security.
* `ssl::Bool=false`: use FTPS.
* `verify_peer::Bool=true`: verify authenticity of peer's certificate.
* `active_mode::Bool=false`: use active mode to establish data connection.
* `username::AbstractString=""`: the username used to access the FTP server.
* `password::AbstractString=""`: the password used to access the FTP server.
"""
type FTP
    ctxt::ConnContext

    function FTP(;hostname::AbstractString="", implicit::Bool=false, ssl::Bool=false,
            verify_peer::Bool=true, active_mode::Bool=false, username::AbstractString="",
            password::AbstractString="")
        options = RequestOptions(implicit=implicit, ssl=ssl,
                    verify_peer=verify_peer, active_mode=active_mode,
                    username=username, password=password, hostname=hostname)

        ctxt = nothing
        try
            ctxt, resp = ftp_connect(options)
        catch err
            if isa(err, FTPClientError)
                err.msg = "Failed to connect."
            end
            rethrow()
        end

        new(ctxt)
    end
end

function show(io::IO, ftp::FTP)
    o = ftp.ctxt.options
    println(io, "Host:      $(ftp.ctxt.url)")
    println(io, "User:      $(o.username)")
    println(io, "Transfer:  $(o.active_mode ? "active" : "passive") mode")
    println(io, "Security:  $(o.ssl ? (o.implicit ? "implicit" : "explicit") : "None")")
end

"""
    close(ftp::FTP)

Close FTP connection.
"""
function close(ftp::FTP)
    ftp_close_connection(ftp.ctxt)
end

"""
    download(ftp::FTP, file_name::AbstractString, save_path::AbstractString=""; mode::FTP_MODE=binary_mode)

Download the file "file_name" from FTP server and return IOStream.
If "save_path" is not specified, contents are written to and returned as an IOBuffer.
"""
function download(ftp::FTP, file_name::AbstractString, save_path::AbstractString=""; mode::FTP_MODE=binary_mode)
    resp = nothing
    try
        resp = ftp_get(ftp.ctxt, file_name, save_path; mode=mode)
    catch err
        if isa(err, FTPClientError)
            err.msg = "Failed to download $file_name."
        end
        rethrow()
    end
    return resp.body
end

"""
    upload(ftp::FTP, local_name::AbstractString; mode::FTP_MODE=binary_mode)

Upload the file "local_name" to the FTP server and save as "local_name".
"""
function upload(ftp::FTP, local_name::AbstractString; mode::FTP_MODE=binary_mode)
    return upload(ftp, local_name, local_name; mode=mode)
end

"""
    upload(ftp::FTP, local_name::AbstractString, remote_name::AbstractString; mode::FTP_MODE=binary_mode)

Upload the file "local_name" to the FTP server and save as "remote_name".
"""
function upload(ftp::FTP, local_name::AbstractString, remote_name::AbstractString; mode::FTP_MODE=binary_mode)
    open(local_name) do local_file
        return upload(ftp, local_file, remote_name; mode=mode)
    end
end

"""
    upload(ftp::FTP, local_file::IO, remote_name::AbstractString; mode::FTP_MODE=binary_mode)

Upload IO object "local_file" to the FTP server and save as "remote_name".
"""
function upload(ftp::FTP, local_file::IO, remote_name::AbstractString; mode::FTP_MODE=binary_mode)
    try
        ftp_put(ftp.ctxt, remote_name, local_file; mode=mode)
    catch err
        if isa(err, FTPClientError)
            err.msg = "Failed to upload $remote_name."
        end
        rethrow()
    end
    return nothing
end


"""
    readdir(ftp::FTP)

Return the contents of the current working directory of the FTP server.
"""
function readdir(ftp::FTP)
    resp = nothing

    try
        resp = ftp_command(ftp.ctxt, "LIST")
    catch err
        if isa(err, FTPClientError)
            err.msg = "Failed to list directories."
        end
        rethrow()
    end

    @compat dir = split(readstring(resp.body), '\n')
    dir = filter(x -> !isempty(x), dir)
    dir = [join(split(line)[9:end], ' ') for line in dir]
end


"""
    cd(ftp::FTP, dir::AbstractString)

Set the current working directory of the FTP server to "dir".
"""
function cd(ftp::FTP, dir::AbstractString)
    if !endswith(dir, "/")
        dir *= "/"
    end

    resp = ftp_command(ftp.ctxt, "CWD $dir")

    if resp.code != 250
        throw(FTPClientError("Failed to change to directory $dir. $(resp.code)", 0))
    end
end


"""
    pwd(ftp::FTP)

Get the current working directory of the FTP server
"""
function pwd(ftp::FTP)
    resp = ftp_command(ftp.ctxt, "PWD")

    if resp.code != 257
        throw(FTPClientError("Failed to get the current working directory. $(resp.code)", 0))
    end

    dir = split(resp.headers[end], '\"')[end-1]
end


"""
    rm(ftp::FTP, file_name::AbstractString)

Delete file "file_name" from FTP server.
"""
function rm(ftp::FTP, file_name::AbstractString)
    resp = ftp_command(ftp.ctxt, "DELE $file_name")

    if resp.code != 250
        throw(FTPClientError("Failed to remove $file_name. $(resp.code)", 0))
    end
end


"""
    rmdir(ftp::FTP, dir_name::AbstractString)

Delete directory "dir_name" from FTP server.
"""
function rmdir(ftp::FTP, dir_name::AbstractString)
    resp = ftp_command(ftp.ctxt, "RMD $dir_name")

    if resp.code != 250
        throw(FTPClientError("Failed to remove $dir_name. $(resp.code)", 0))
    end
end


"""
    mkdir(ftp::FTP, dir::AbstractString)

Make directory "dir" on FTP server.
"""
function mkdir(ftp::FTP, dir::AbstractString)
    resp = ftp_command(ftp.ctxt, "MKD $dir")

    if resp.code != 257
        throw(FTPClientError("Failed to make $dir. $(resp.code)", 0))
    end
end


"""
    mv(ftp::FTP, file_name::AbstractString, new_name::AbstractString)

Move (rename) file "file_name" to "new_name" on FTP server.
"""
function mv(ftp::FTP, file_name::AbstractString, new_name::AbstractString)
    resp = ftp_command(ftp.ctxt, "RNFR $file_name")

    if resp.code != 350
        throw(FTPClientError("Failed to move $file_name. $(resp.code)", 0))
    end

    resp = ftp_command(ftp.ctxt, "RNTO $new_name")

    if resp.code != 250
        throw(FTPClientError("Failed to move $file_name. $(resp.code)", 0))
    end
end

"""
    ftp(code::Function;
    hostname::AbstractString="", implicit::Bool=false, ssl::Bool=false,
    verify_peer::Bool=true, active_mode::Bool=false, username::AbstractString="", password::AbstractString="")

Execute Function "code" on FTP server.
"""
function ftp(code::Function;
    hostname::AbstractString="", implicit::Bool=false, ssl::Bool=false,
    verify_peer::Bool=true, active_mode::Bool=false, username::AbstractString="", password::AbstractString="")
    ftp_init()
    ftp_client = FTP(
        hostname=hostname, implicit=implicit, ssl=ssl, verify_peer=verify_peer,
        active_mode=active_mode, username=username, password=password,
    )

    try
        code(ftp_client)
    finally
        close(ftp_client)
        ftp_cleanup()
    end
end

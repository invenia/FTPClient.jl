# FTP code for when the file transfer is complete.
const complete_transfer_code = 226

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
mutable struct FTP
    ctxt::ConnContext

    function FTP(;hostname::AbstractString="", implicit::Bool=false, ssl::Bool=false,
            verify_peer::Bool=true, active_mode::Bool=false, username::AbstractString="",
            password::AbstractString="", url::AbstractString="")
        options = RequestOptions(implicit=implicit, ssl=ssl,
                    verify_peer=verify_peer, active_mode=active_mode,
                    username=username, password=password, hostname=hostname, url=url)

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
    upload(
        ftp::FTP,
        local_file_paths::Vector{<:AbstractString},
        ftp_dir<:AbstractString;
        retry_callback::Function=(count, options) -> (count < 4, options),
        retry_wait_seconds::Integer = 5
    )

Uploads the files specified in local_file_paths to the directory specifed by
ftp_dir. The files will have the same names.

By default, will try to deliver the files 4 times with a 5 second wait in between
each failed attempt.

You can specify a function for retry_callback to change behaviour. This function must
take as parameters the number of attempts that have been made so far, and the current
ftp connection options as a FTPClient.ConnContext type. It must return a boolean
that is true if another delivery attempt can be made, and a TPClient.ConnContext
type that is the connection options to use for all future files to be delivered. This
allows backup ftp directories to be used for example.

# Arguments
`ftp::FTP`: The FTP to deliver to. See FTPClient.FTP for details.
`file_paths::Vector{T}`: The file paths to the files we want to deliver.
`ftp_dir`: The directory on the ftp server where we want to drop the files.
`retry_callback::Function=(count, options) -> (count < 4, options)`: Function for retrying
                                                                     when delivery fails.
`retry_wait_seconds::Integer = 5`: How many seconds to wait in between retries.

# Returns
- `Array{Bool,1}`: Returns a vector of booleans with true for each successfully delivered
                   file and false for any that failed to transfer.
"""
@compat function upload(
    ftp::FTP,
    local_file_paths::Vector{<:AbstractString},
    ftp_dir::AbstractString;
    retry_callback::Function=(count, options) -> (count < 4, options),
    retry_wait_seconds::Integer = 5
)

    successful_delivery = Bool[]

    ftp_options = ftp.ctxt

    for single_file in local_file_paths
        # The location we are going to drop the file in the FTP server
        server_location = joinpath(ftp_dir, basename(single_file))

        # ftp_put requires an io so open up our file.
        open(single_file) do single_file_io
            # Whether or not the current file was successfully delivered to the FTP
            file_delivery_success = false

            attempts = 1
            # The loops should break after an appropriate amount of retries.
            # This way of doing retries makes testing easier.
            # Defaults to 4 attempts, waiting 5 seconds between each retry.
            while true
                try
                    resp = ftp_put(ftp_options, server_location, single_file_io)
                    file_delivery_success = resp.code == complete_transfer_code
                    if file_delivery_success
                        break
                    end
                catch e
                    warn(e)
                end
                sleep(retry_wait_seconds)
                # It returns ftp_options for testing purposes, where the ftp server
                # starts not existing then comes into existence during retries.
                do_retry, ftp_options = retry_callback(attempts, ftp_options)
                if !do_retry
                    break
                end
                attempts += 1
            end

            push!(successful_delivery, file_delivery_success)

        end
    end

    return successful_delivery
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

    dir = split(readstring(resp.body), '\n')
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

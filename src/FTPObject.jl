
function process_response(resp)
    if isa(resp, RemoteRef)
        resp = fetch(resp)
    end

    return resp
end


type FTP
    ctxt::ConnContext

    function FTP(;host="", block=true, implt=false, ssl=false, ver_peer=true, act_mode=false, user="", pswd="")
        options = RequestOptions(blocking=block, implicit=implt, ssl=ssl,
                    verify_peer=ver_peer, active_mode=act_mode,
                    username=user, passwd=pswd, hostname=host)

        resp = ftp_connect(options)
        ctxt, resp = process_response(resp)

        if resp.code == 226
            new(ctxt)
        else
            error("Failed to connect to server.")
        end
    end
end


function show(io::IO, ftp::FTP)
    o = ftp.ctxt.options
    println(io, "Host:      $(ftp.ctxt.url)")
    println(io, "User:      $(o.username)")
    println(io, "Transfer:  $(o.active_mode ? "active" : "passive") mode")
    if (o.ssl)
        println(io, "Security:  $(o.implicit ? "implicit" : "explicit")")
    else
        println(io, "Security:  None")
    end
end


@doc """
Close FTP connection.
""" ->
function close(ftp::FTP)
    ftp_close_connection(ftp.ctxt)
end


@doc """
Download the file "file_name" from FTP server and return IOStream.
If "save_path" is not specified, contents are written to and returned as IOBuffer.
""" ->
function download(ftp::FTP, file_name::String, save_path::String="")
    resp = ftp_get(ftp.ctxt, file_name, save_path)
    resp = process_response(resp)

    if resp.code == 226
        file = resp.body
    else
        error("Failed to download \'$file_name\'.")
    end
end


@doc """
Non-blocking download of file "file_name" from FTP server. Returns a RemoteRef.
""" ->
function non_block_download(ftp::FTP, file_name::String, save_path::String="")
    ftp.ctxt.options.blocking = false
    ref = ftp_get(ftp.ctxt, file_name, save_path)
end


@doc """
Get the response from non_block_download. Returns an IO object.
""" ->
function get_download_resp(ref)
    resp = process_response(ref)

    if resp.code == 226
        file = resp.body
    else
        error("Failed to download \'$file_name\'.")
    end
end


@doc """
Upload IO object "file" to the FTP server and save as "file_name".
If "file" is not specified, the file "file_name" is uploaded.
""" ->
function upload(ftp::FTP, file_name::String, file=nothing)
    if file == nothing
        file = open(file_name)
    end

    resp = ftp_put(ftp.ctxt, file_name, file)
    resp = process_response(resp)

    if (resp.code != 226)
        error("Failed to upload \'$file_name\'")
    end
end


@doc """
Non-blocking upload of "file" to the FTP server. Returns a RemoteRef.
""" ->
function non_block_upload(ftp::FTP, file_name::String, file=nothing)
    if file == nothing
        file = open(file_name)
    end

    ftp.ctxt.options.blocking = false
    ref = ftp_put(ftp.ctxt, file_name, file)
end


@doc """
Process response form non_block_upload. Throws error if upload failed.
""" ->
function get_upload_resp(ref)
    resp = process_response(ref)

    if (resp.code != 226)
        error("Failed to upload \'$file_name\'")
    end
end


@doc """
Returns the contents of the current working directory of the FTP server.
""" ->
function readdir(ftp::FTP)
    resp = ftp_command(ftp.ctxt, "LIST")

    if resp.code == 226
        dir = split(readall(resp.body), '\n')
        dir = filter( x -> ~isempty(x), dir)
        dir = [ split(line)[end] for line in dir ]
    else
        error("Failed to read directory.")
    end
end


@doc """
Sets the current working directory of the FTP server to "dir".
""" ->
function cd(ftp::FTP, dir::String)
    if (~endswith(dir, "/"))
        dir *= "/"
    end
    resp = ftp_command(ftp.ctxt, "CWD $dir")

    if resp.code != 250
        error("Failed to change directory.")
    end
end


@doc """
Get the current working directory of the FTP server
""" ->
function pwd(ftp::FTP)
    resp = ftp_command(ftp.ctxt, "PWD")

    if resp.code == 257
        dir = split(resp.headers[end], '\"')[end-1]
    else
        error("Failed to get the current working directory.")
    end
end


@doc """
Delete file "file_name" from FTP server.
""" ->
function rm(ftp::FTP, file_name::String)
    resp = ftp_command(ftp.ctxt, "DELE $file_name")

    if resp.code != 250
        error("Failed to remove \'$file_name\'.")
    end
end


@doc """
Delete directory "dir_name" from FTP server.
""" ->
function rmdir(ftp::FTP, dir_name::String)
    resp = ftp_command(ftp.ctxt, "RMD $dir_name")

    if resp.code != 250
        error("Failed to remove directory \'$dir_name\'.")
    end
end


@doc """
Make directory "dir" on FTP server.
""" ->
function mkdir(ftp::FTP, dir::String)
    resp = ftp_command(ftp.ctxt, "MKD $dir")

    if resp.code != 257
        error("Failed to make directory \'$dir\'.")
    end
end


@doc """
Move (rename) file "file_name" to "new_name" on FTP server.
""" ->
function mv(ftp::FTP, file_name::String, new_name::String)
    resp = ftp_command(ftp.ctxt, "RNFR $file_name")

    if resp.code == 350
        resp = ftp_command(ftp.ctxt, "RNTO $new_name")

        if resp.code != 250
            error("Failed to rename \'$file_name\'.")
        end
    else
        error("Failed to rename \'$file_name\'.")
    end
end


@doc """
Set the transfer mode to binary.
""" ->
function binary(ftp::FTP)
    resp = ftp_command(ftp.ctxt, "TYPE I")

    if resp.code != 200
        error("Failed to switch to binary mode.")
    end
end


@doc """
Set the transfer mode to ASCII.
""" ->
function ascii(ftp::FTP)
    resp = ftp_command(ftp.ctxt, "TYPE A")

    if resp.code != 200
        error("Failed to switch to ASCII mode.")
    end
end

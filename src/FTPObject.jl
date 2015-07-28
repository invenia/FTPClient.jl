module FTPObject

using Debug
using FTPClient

import Base.show, Base.readdir, Base.cd, Base.pwd, Base.rm, Base.close, Base.download
import Base.mkdir

export FTP, upload


type FTP
    ctxt::ConnContext

    function FTP(;host="", block=true, implt=false, ssl=false, ver_peer=true, act_mode=false, user="", pswd="")
        options = RequestOptions(blocking=block, implicit=implt, ssl=ssl,
                    verify_peer=ver_peer, active_mode=act_mode,
                    username=user, passwd=pswd, url=host)
        ctxt, resp = ftp_connect(options)

        if (resp.code == 226)
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

function close(ftp::FTP)
    ftp_close_connection(ftp.ctxt)
end

function download(ftp::FTP, file_name::String, save_path::String="")
    resp = ftp_get(ftp.ctxt, file_name, save_path)

    if (resp.code == 226)
        file = resp.body
    else
        error("Failed to download \'$file_name\'.")
    end
end

function upload(ftp::FTP, file_name::String)
    file = open(file_name)

    resp = ftp_put(ftp.ctxt, file_name, file)

    if (resp.code != 226 || resp.code != 56)
        error("Failed to upload \'$file_name\'")
    elseif (resp.code == 56)
        println("Did not get response from server")
    end
end

function readdir(ftp::FTP)
    resp = ftp_command(ftp.ctxt, "LIST")

    if (resp.code == 226)
        dir = split(readall(resp.body), '\n')
        dir = filter( x -> ~isempty(x), dir)
        dir = [ split(line)[end] for line in dir ]
    else
        error("Failed to read directory.")
    end
end

function cd(ftp::FTP, dir::String)
    if (~endswith(dir, "/"))
        dir *= "/"
    end
    resp = ftp_command(ftp.ctxt, "CWD $dir")

    if (resp.code != 250)
        error("Failed to change directory.")
    end
end

function pwd(ftp::FTP)
    resp = ftp_command(ftp.ctxt, "PWD")

    if (resp.code == 257)
        dir = split(resp.headers[end], '\"')[end-1]
    else
        error("Failed to get the current working directory.")
    end
end

function rm(ftp::FTP, file_name::String)
    resp = ftp_command(ftp.ctxt, "DELE $file_name")

    if (resp.code != 250)
        error("Failed to remove \'$file_name\'.")
    end
end

function mkdir(ftp::FTP, dir::String)
    resp = ftp_command(ftp.ctxt, "MKD $dir")

    if (resp.code != 257)
        error("Failed to make directory \'$dir\'.")
    end
end

end
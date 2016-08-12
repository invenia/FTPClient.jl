import Compat: readstring
using FTPClient
using Base.Test


include("server/server.jl")
include("utils.jl")

setup_server()
ftp_init()
server = FTPServer()

testdir = "test_dir"
upload_file = "test_upload.txt"
download_file = "test_download.txt"

try
    tempfile(upload_file)
    tempfile(joinpath(ROOT,download_file))
    cleanup_file(download_file)
    cleanup_file(joinpath(ROOT, upload_file))
    include("ftp_object.jl")
    include("non_ssl.jl")
    include("ssl.jl")

finally
    cleanup_file(upload_file)
    cleanup_file(joinpath(ROOT, download_file))

    teardown_server()
    close(server)

    for line in eachline(server.io)
        print(line)
        if contains(line, "FTP session closed")
            break
        end
    end
end

ftp_cleanup()

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
tempfile(upload_file)
tempfile(joinpath(ROOT,download_file))

cleanup_file(download_file)
cleanup_file(joinpath(ROOT, upload_file))

include("ssl.jl")
include("non_ssl.jl")
include("ftp_object.jl")

cleanup_file(upload_file)
cleanup_file(joinpath(ROOT, download_file))

ftp_cleanup()
teardown_server()

close(server)

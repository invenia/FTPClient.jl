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
upload_file_2 = "test_upload_2.txt"
upload_file_3 = "test_upload_3.txt"
upload_file_4 = "test_upload_4.txt"

download_file = "test_download.txt"

try
    tempfile(upload_file)
    tempfile(upload_file_2)
    tempfile(upload_file_3)
    tempfile(upload_file_4)

    tempfile(joinpath(ROOT,download_file))
    cleanup_file(download_file)
    cleanup_file(joinpath(ROOT, upload_file))

    @testset "All Tests" begin
        include("ftp_object.jl")
        include("non_ssl.jl")
        include("ssl.jl")
    end

finally
    # ensure the server is cleaned up if one of the tests fail
    cleanup_file(upload_file)
    cleanup_file(upload_file_2)
    cleanup_file(upload_file_3)
    cleanup_file(upload_file_4)
    cleanup_file(joinpath(ROOT, download_file))

    teardown_server()
    close(server)
end

ftp_cleanup()

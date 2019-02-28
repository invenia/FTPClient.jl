using Test
using FTPClient
using FTPServer
using FTPServer: username, password, hostname, port, HOMEDIR, tempfile

# FTP code for when the file transfer is complete.
const complete_transfer_code = 226

include("utils.jl")

FTPServer.init()
ftp_init()
server = FTPServer.Server()

# Note: port is always supplied with the test server
prefix = "ftp://$(username(server)):$(password(server))@$(hostname(server)):$(port(server))"

testdir = "test_dir"

upload_file = "test_upload.txt"
upload_file_2 = "test_upload_2.txt"
upload_file_3 = "test_upload_3.txt"
upload_file_4 = "test_upload_4.txt"

download_file = "test_download.txt"

@testset "all_tests" begin

    try
        tempfile(upload_file)
        tempfile(upload_file_2)
        tempfile(upload_file_3)
        tempfile(upload_file_4)

        tempfile(joinpath(HOMEDIR, download_file))
        cleanup_file(download_file)
        cleanup_file(joinpath(HOMEDIR, upload_file))

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
        cleanup_file(joinpath(HOMEDIR, download_file))

        FTPServer.cleanup()
        close(server)
    end

    ftp_cleanup()

end

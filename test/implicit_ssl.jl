# ftp_init()
import Compat: readstring
using FTPClient
using Base.Test


include("server/server.jl")
include("utils.jl")
server = FTPServer(ssl = "implicit")

setup_server()
ftp_init()

user = "user"
pswd = "passwd"
host = hostname(server)
upload_file = "test_upload.txt"
download_file = "test_download.txt"
# ###############################################################################
# # Non-persistent connection tests using ssl, explicit security, passive mode
# ###############################################################################

 options = RequestOptions(ssl=true, implicit=true, active_mode=false, verify_peer=false, username=user, passwd=pswd, hostname=host)
 println("Test non-persistent connection using ssl, explicit security and passive mode:\n")

 # test 1, download file from server
 resp = ftp_get(download_file, options)
 @test resp.code == 226
 @test readstring(resp.body) == readstring(joinpath(ROOT, download_file))
 println("Test 1 passed.\n$resp")


local_file = upload_file
tempfile(local_file)
server_file = joinpath(ROOT, local_file)
if (isfile(server_file))
    rm(server_file)
end
# test 2, upload file to server

    resp = open(local_file) do fp
        ftp_put(local_file, fp, options)
    end
    @test resp.code ==226
    @test readstring(server_file) == readstring(local_file)
    println("Test 2 passed.\n$resp")

# test 3, pass command to server
resp = ftp_command("PWD", options)
@test resp.code == 257
@test readstring(resp.body) == ""
println("Test 3 passed.\n$resp")

# ###############################################################################
# Non-persistent connection tests using ssl, explicit security, active mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=true, verify_peer=false, username=user, passwd=pswd, hostname=host)
println("Test non-persistent connection using ssl, explicit security and active mode:\n")

server_file = joinpath(ROOT, download_file)
# test 4, download file from server
resp = ftp_get(download_file, options)
@test resp.code == 226
@test readstring(resp.body) == readstring(server_file)
println("Test 4 passed.\n$resp")


# test 5, upload file to server
local_file = upload_file
server_file = joinpath(ROOT, local_file)
tempfile(local_file)

    resp = open(local_file) do fp
        ftp_put(local_file, fp, options)
    end
    @test resp.code ==226
    @test readstring(server_file) == readstring(local_file)
    println("Test 5 passed.\n$resp")

# test 6, pass command to server
resp = ftp_command("PWD", options)
@test resp.code == 257
@test readstring(resp.body) == ""
println("Test 6 passed.\n$resp")

###############################################################################
# Persistent connection tests using ssl, explicit security, passive mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=false, verify_peer=false, username=user, passwd=pswd, hostname=host)
println("Test persistent connection using ssl, explicit security and passive mode:\n")

# test 7, establish connection
ctxt, resp = ftp_connect(options)
@test resp.code == 226
println("Test 7 passed.\n$(resp)")

# test 8, pass command to server
resp = ftp_command(ctxt, "PWD")
@test resp.code == 257
@test readstring(resp.body) == ""
println("Test 8 passed.\n$(resp)")

# test 9, download file from server

resp = ftp_get(ctxt, download_file)
@test resp.code == 226
@test readstring(resp.body) == readstring(joinpath(ROOT, download_file))
println("Test 9 passed.\n$(resp)")



# test 10, upload file to server

    file = open(upload_file)
    resp = ftp_put(ctxt, "test_upload.txt", file)
    @test resp.code ==226
    @test readstring(upload_file) == readstring(joinpath(ROOT, upload_file))
    println("Test 10 passed.\n$(resp)")
    Base.close(file)

rm(joinpath(ROOT, upload_file))
ftp_close_connection(ctxt)

###############################################################################
# Persistent connection tests using ssl, explicit security, active mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=true, verify_peer=false, username=user, passwd=pswd, hostname=host)
println("Test persistent connection using ssl, explicit security and active mode:\n")

# test 11, establish connection
ctxt, resp = ftp_connect(options)
@test resp.code == 226
println("Test 11 passed.\n$(resp)")

# test 12, pass command to server
resp = ftp_command(ctxt, "PWD")
@test resp.code == 257
@test readstring(resp.body) == ""

println("Test 12 passed.\n$(resp)")

# test 13, download file from server
resp = ftp_get(ctxt, download_file)
@test resp.code == 226
@test readstring(resp.body) == readstring(joinpath(ROOT, download_file))
println("Test 13 passed.\n$(resp)")


# test 14, upload file to server

    file = open(upload_file)
    resp = ftp_put(ctxt, upload_file, file)
    @test resp.code ==226
    @test readstring(upload_file) == readstring(joinpath(ROOT, upload_file))
    println("Test 14 passed.\n$(resp)")
    Base.close(file)


 ftp_close_connection(ctxt)

 ftp_cleanup()

 println("\nFTPC implicit ssl tests passed.\n")
close(server)

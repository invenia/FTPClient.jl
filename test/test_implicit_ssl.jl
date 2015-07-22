using FTPClient
using Base.Test

ftp_init()

###############################################################################
# Non-persistent connection tests using ssl, implicit security, passive mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=false, verify_peer=false, username=user, passwd=pswd)
println("Test non-persistent connection using ssl, implicit security and passive mode:\n")

# test 1, download file from server
resp, buff = ftp_get(url, file_name, options)
@test resp.code == 226
println("Test 1 passed.\n$resp")
# rm(file_name)

# test 2, upload file to server
try
    file = open(upload_file)
    resp = ftp_put(url, "test_upload.txt", file, options)
    @test resp.code ==226
    println("Test 2 passed.\n$resp")
    close(file)
catch e
    println("Test 2 failed: $e\n")
end

# test 3, pass command to server
resp = ftp_command(url, "PWD", options)
@test resp.code == 257
println("Test 3 passed.\n$resp")

###############################################################################
# Non-persistent connection tests using ssl, implicit security, active mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=true, verify_peer=false, username=user, passwd=pswd)
println("Test non-persistent connection using ssl, implicit security and active mode:\n")

# test 4, download file from server
resp, buff = ftp_get(url, file_name, options)
@test resp.code == 226
println("Test 4 passed.\n$resp")
# rm(file_name)

# test 5, upload file to server
try
    file = open(upload_file)
    resp = ftp_put(url, "test_upload.txt", file, options)
    @test resp.code ==226
    println("Test 5 passed.\n$resp")
    close(file)
catch e
    println("Test 5 failed: $e\n")
end

# test 6, pass command to server
resp = ftp_command(url, "PWD", options)
@test resp.code == 257
println("Test 6 passed.\n$resp")

###############################################################################
# Persistent connection tests using ssl, implicit security, passive mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=false, verify_peer=false, username=user, passwd=pswd)
println("Test persistent connection using ssl, implicit security and passive mode:\n")

# test 7, establish connection
ctxt = ftp_connect(url, options)
@test ctxt.resp.code == 226
println("Test 7 passed.\n$(ctxt.resp)")

# test 8, pass command to server
resp = ftp_command(ctxt, "PWD")
@test resp.code == 257
println("Test 8 passed.\n$(ctxt.resp)")

# test 9, download file from server
buff = ftp_get(ctxt, file_name)
@test ctxt.resp.code == 226
println("Test 9 passed.\n$(ctxt.resp)")
# rm(file_name)

# test 10, upload file to server
try
    file = open(upload_file)
    resp = ftp_put(ctxt, "test_upload.txt", file)
    @test resp.code ==226
    println("Test 10 passed.\n$(ctxt.resp)")
    close(file)
catch e
    println("Test 10 failed: $e\n")
end

ftp_close_connection(ctxt)

###############################################################################
# Persistent connection tests using ssl, implicit security, active mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=true, verify_peer=false, username=user, passwd=pswd)
println("Test persistent connection using ssl, implicit security and active mode:\n")

# test 11, establish connection
ctxt = ftp_connect(url, options)
@test ctxt.resp.code == 226
println("Test 11 passed.\n$(ctxt.resp)")

# test 12, pass command to server
resp = ftp_command(ctxt, "PWD")
@test resp.code == 257
println("Test 12 passed.\n$(ctxt.resp)")

# test 13, download file from server
resp, buff = ftp_get(ctxt, file_name)
@test resp.code == 226
println("Test 13 passed.\n$(ctxt.resp)")
# rm(file_name)

# test 14, upload file to server
try
    file = open(upload_file)
    resp = ftp_put(ctxt, "test_upload.txt", file)
    @test resp.code ==226
    println("Test 14 passed.\n$(ctxt.resp)")
    close(file)
catch e
    println("Test 14 failed: $e\n")
end

ftp_close_connection(ctxt)

ftp_cleanup()
using FTPClient
using Base.Test

ftp_init()

###############################################################################
# Non-persistent connection tests using ssl, implicit security, passive mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=false, verify_peer=false, username=user, passwd=pswd)
println("Test non-persistent connection using ssl, implicit security and passive mode:\n")

# test 1, download file from server
resp = ftp_get(file_name, options)
@test resp.code == 226
println("Test 1 passed.\n$resp")
# rm(file_name)

# test 2, upload file to server
try
    file = open(upload_file)
    resp = ftp_put("test_upload.txt", file, options)
    @test resp.code ==226
    println("Test 2 passed.\n$resp")
    close(file)
catch e
    println("Test 2 failed: $e\n")
end

# test 3, pass command to server
resp = ftp_command("PWD", options)
@test resp.code == 257
println("Test 3 passed.\n$resp")

###############################################################################
# Non-persistent connection tests using ssl, implicit security, active mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=true, verify_peer=false, username=user, passwd=pswd)
println("Test non-persistent connection using ssl, implicit security and active mode:\n")

# test 4, download file from server
resp = ftp_get(file_name, options)
@test resp.code == 226
println("Test 4 passed.\n$resp")
# rm(file_name)

# test 5, upload file to server
try
    file = open(upload_file)
    resp = ftp_put("test_upload.txt", file, options)
    @test resp.code ==226
    println("Test 5 passed.\n$resp")
    close(file)
catch e
    println("Test 5 failed: $e\n")
end

# test 6, pass command to server
resp = ftp_command("PWD", options)
@test resp.code == 257
println("Test 6 passed.\n$resp")

###############################################################################
# Persistent connection tests using ssl, implicit security, passive mode
###############################################################################

options = RequestOptions(ssl=true, implicit=true, active_mode=false, verify_peer=false, username=user, passwd=pswd)
println("Test persistent connection using ssl, implicit security and passive mode:\n")

# test 7, establish connection
ctxt, resp = ftp_connect(options)
@test resp.code == 226
println("Test 7 passed.\n$(resp)")

# test 8, pass command to server
resp = ftp_command(ctxt, "PWD")
@test resp.code == 257
println("Test 8 passed.\n$(resp)")

# test 9, download file from server
resp = ftp_get(ctxt, file_name)
@test resp.code == 226
println("Test 9 passed.\n$(resp)")
# rm(file_name)

# test 10, upload file to server
try
    file = open(upload_file)
    resp = ftp_put(ctxt, "test_upload.txt", file)
    @test resp.code ==226
    println("Test 10 passed.\n$(resp)")
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
ctxt, resp = ftp_connect(options)
@test resp.code == 226
println("Test 11 passed.\n$(resp)")

# test 12, pass command to server
resp = ftp_command(ctxt, "PWD")
@test resp.code == 257
println("Test 12 passed.\n$(resp)")

# test 13, download file from server
resp = ftp_get(ctxt, file_name)
@test resp.code == 226
println("Test 13 passed.\n$(resp)")
# rm(file_name)

# test 14, upload file to server
try
    file = open(upload_file)
    resp = ftp_put(ctxt, "test_upload.txt", file)
    @test resp.code ==226
    println("Test 14 passed.\n$(resp)")
    close(file)
catch e
    println("Test 14 failed: $e\n")
end

ftp_close_connection(ctxt)

# test 15 & 16, test uploading text from a buffer
ctxt, resp = ftp_connect(options)
@test resp.code == 226
println("Test 15 passed.\n$(resp)")

buff = IOBuffer("Test buffer to upload.\n")

try
    resp = ftp_put(ctxt, "test_uploadbuff.txt", buff)
    @test resp.code ==226
    println("Test 16 passed.\n$(resp)")
catch e
    println("Test 16 failed: $e\n")
end
ftp_close_connection(ctxt)

###############################################################################
# FTPObject
###############################################################################

testdir = "testdir"
test_upload = "test_upload.txt"

###############################################################################
# Persistent connection tests using ssl, implicit security, passive mode
###############################################################################

println("\nTest persistent connection with passive mode:\n")

# test 17, establish connection
ftp = FTP(ssl=true, implt=true, act_mode=true, ver_peer=false, user=user, pswd=pswd, host=host)
println("\nTest 17 passed.\n$(ftp)")

# test 18, get a list of directories
readdir(ftp)
println("\nTest 18 passed.\n$(ftp)")

# test 19, download file from server
download(ftp, file_name)
println("\nTest 19 passed.\n$(ftp)")

# test 20, upload a file (our test server sometimes thorws an error)
try
    upload(ftp, test_upload)
    println("\nTest 20 passed.\n$(ftp)")
    close(ftp)
catch e
    println("Test 20 failed: $e\n")
finally
    ftp = FTP(ssl=true, implt=true, act_mode=false, ver_peer=false, user=user, pswd=pswd, host=host)
end

# Just trying to make sure our test directory doesn't exsit
try
    rmdir(ftp, "testdir")
catch e
    println("The directory either doesn't exists or couldn't remove it.")
end

# test 21, make a diretory
mkdir(ftp, testdir)
println("\nTest 21 passed.\n$(ftp)")

# test 22, try making a directory that already exists
try
    mkdir(ftp, testdir)
catch e
    if e.msg == "Failed to make directory '$(testdir)'."
        println("\nTest 22 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

# test 23, change directory
cd(ftp, testdir)
println("\nTest 23 passed.\n$(ftp)")

# test 24, try changing to a directory that doesn't exsit
try
    cd(ftp, "not_a_directory")
catch e
    if e.msg == "Failed to change directory."
        println("\nTest 24 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

# test 25, go to parent directory
cd(ftp, "..")
readdir(ftp)
println("\nTest 25 passed.\n$(ftp)")

# test 26, remove the test directory
rmdir(ftp, testdir)
println("\nTest 26 passed.\n$(ftp)")

# test 27, try removing a directory that doesn't exists
try
    rmdir(ftp, testdir)
catch e
    if e.msg == "Failed to remove directory '$(testdir)'."
        println("\nTest 27 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

# test 28, get current directory path
pwd(ftp)
println("\nTest 28 passed.\n$(ftp)")

# test 29, remove the uploaded
rm(ftp, test_upload)
println("\nTest 29 passed.\n$(ftp)")

# test 30, try removing a file that doesn't exists
try
    rm(ftp, test_upload)
catch e
    if e.msg == "Failed to remove '$(test_upload)'."
        println("\nTest 30 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

close(ftp)
ftp_cleanup()

###############################################################################
# Persistent connection tests using ssl, implicit security, active mode
###############################################################################

println("\nTest persistent connection with active mode:\n")

# test 31, establish connection
ftp = FTP(ssl=true, implt=true, act_mode=true, ver_peer=false, user=user, pswd=pswd, host=host)
println("\nTest 31 passed.\n$(ftp)")

# test 32, get a list of directories
readdir(ftp)
println("\nTest 32 passed.\n$(ftp)")

# test 33, download file from server
download(ftp, file_name)
println("\nTest 33 passed.\n$(ftp)")

# test 34, upload a file (our test server sometimes thorws an error)
try
    upload(ftp, test_upload)
    println("\nTest 34 passed.\n$(ftp)")
    close(ftp)
catch e
    println("Test 34 failed: $e\n")
finally
    ftp = FTP(ssl=true, implt=true, act_mode=true, ver_peer=false, user=user, pswd=pswd, host=host)
end

# Just trying to make sure our test directory doesn't exsit
try
    rmdir(ftp, "testdir")
catch e
    println("The directory either doesn't exists or couldn't remove it.")
end

# test 35, make a diretory
mkdir(ftp, testdir)
println("\nTest 35 passed.\n$(ftp)")

# test 36, try making a directory that already exists
try
    mkdir(ftp, testdir)
catch e
    if e.msg == "Failed to make directory '$(testdir)'."
        println("\nTest 36 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

# test 37, change directory
cd(ftp, testdir)
println("\nTest 37 passed.\n$(ftp)")

# test 38, try changing to a directory that doesn't exsit
try
    cd(ftp, "not_a_directory")
catch e
    if e.msg == "Failed to change directory."
        println("\nTest 38 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

# test 39, go to parent directory
cd(ftp, "..")
readdir(ftp)
println("\nTest 39 passed.\n$(ftp)")

# test 40, remove the test directory
rmdir(ftp, testdir)
println("\nTest 40 passed.\n$(ftp)")

# test 41, try removing a directory that doesn't exists
try
    rmdir(ftp, testdir)
catch e
    if e.msg == "Failed to remove directory '$(testdir)'."
        println("\nTest 41 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

# test 42, get current directory path
pwd(ftp)
println("\nTest 42 passed.\n$(ftp)")

# test 43, remove the uploaded
rm(ftp, test_upload)
println("\nTest 43 passed.\n$(ftp)")

# test 44, try removing a file that doesn't exists
try
    rm(ftp, test_upload)
catch e
    if e.msg == "Failed to remove '$(test_upload)'."
        println("\nTest 44 passed.\n$(ftp)")
    else
        rethrow(e)
    end
end

close(ftp)
ftp_cleanup()

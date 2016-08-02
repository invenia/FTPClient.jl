import Compat: readstring
using FTPClient
using Base.Test

include("server/server.jl")
include("utils.jl")
server = FTPServer()

setup_server()
options = RequestOptions(hostname=hostname(server), username="user", passwd="passwd", ssl=false, active_mode=true)

user = "user"
pswd = "passwd"
host = hostname(server)
upload_file_name = "test_upload.txt"
file_name = "test_download.txt"


# ftp() do ftp_client end
#ftp(ssl=false, user=user, pswd=pswd, host=host) do f
#@test_throws FTPClientError download(f, file_name)
#end


ftp_init()

# make error

buff = IOBuffer()
msg = "This will go into the message"
lib_curl_error = 765
error = FTPClientError(msg, lib_curl_error)
showerror(buff, error)
seekstart(buff)
@test "$msg :: LibCURL error #$lib_curl_error" == readstring(buff)



# connect error
options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname="not a host")
@test_throws FTPClientError ftp_connect(options)

# FTP object error when connecting
@test_throws FTPClientError FTP(ssl=false, user=user, pswd=pswd, host="not a host")


# ftp_put error
# options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
# open(upload_file_name) do file
# @test_throws FTPClientError ftp_put(upload_file_name, file, options)

# ftp_get error
# @test_throws FTPClientError ftp_get(file_name, options)

# ftp_command error
# @test_throws FTPClientError ftp_command("NLST", options)


# FTP object error when downloading, blocking
# ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
# @test_throws FTPClientError download(ftp, file_name)
# close(ftp)

# FTP object error when uploading, blocking
# ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
# @test_throws FTPClientError upload(ftp, upload_file_name)
# close(ftp)

# FTP object error when changing working directory
# ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
# @test_throws FTPClientError cd(ftp, "test_directory")
# Base.close(ftp)

# FTP object error when getting path of working directory
# ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
# @test_throws FTPClientError pwd(ftp)
# close(ftp)

# FTP object error when removing a file that doesn't exist
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
@test_throws FTPClientError rm(ftp, "not_a_file")
Base.close(ftp)


# FTP object error when removing a directory that doesn't exist
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
@test_throws FTPClientError rmdir(ftp, "not_a_directory")
Base.close(ftp)

# FTP object error when creating a bad directory
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
@test_throws FTPClientError mkdir(ftp, "")
Base.close(ftp)


# FTP object error when moving bad directories
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
@test_throws FTPClientError mv(ftp, "", "")
Base.close(ftp)


# FTP object error when moving bad directories 2
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
@test_throws FTPClientError mv(ftp, file_name, "")
Base.close(ftp)

# FTP object error with LIST command
# undo_errors()
# ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
# set_list_error()
# @test_throws FTPClientError readdir(ftp)
# close(ftp)

ftp_cleanup()

close(server)

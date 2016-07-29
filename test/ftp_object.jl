
import Compat: readstring
using FTPClient
using Base.Test


include("server/server.jl")
include("utils.jl")
server = FTPServer()

setup_server()
ftp_init()

user = "user"
pswd = "passwd"
host = hostname(server)
download_file = "test_download.txt"
upload_file = "test_upload.txt"
testdir = "testdir"
mv_file = "test_mv.txt"


function no_unexpected_changes(ftp::FTP, hostname::AbstractString=host)
    other = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @test ftp.ctxt.options == other.ctxt.options
    @test ftp.ctxt.url == "ftp://$hostname/"
end

function cleanup_file(filename::AbstractString)
    if (isfile(filename))
        rm(filename)
    end
    @test !isfile(filename)
end

function cleanup_dir(dirname::AbstractString, recursive = true)
    if (isdir(dirname))
        rm(dirname)
    end
    @test !isdir(dirname)
end

getFTPObj()= FTP(ssl=false, user=user, pswd=pswd, host=host)

# check object
ftp = getFTPObj()
no_unexpected_changes(ftp)
Base.close(ftp)

# check readdir
ftp = getFTPObj()
server_dir = readdir(ftp)
contains(string(server_dir), "test_directory")
contains(string(server_dir), "test_byte_file")
contains(string(server_dir), "test_upload.txt")
contains(string(server_dir), "test_download.txt")
no_unexpected_changes(ftp)
Base.close(ftp)

# check download to buffer
ftp = getFTPObj()
buffer = download(ftp, download_file)
@test readstring(buffer) == readstring(joinpath(ROOT,download_file))
no_unexpected_changes(ftp)
Base.close(ftp)

# check upload
ftp = getFTPObj()
local_file = upload_file
server_file = joinpath(ROOT, local_file)
tempfile(local_file)
@test isfile(local_file)
resp = upload(ftp, local_file)
@test isfile(server_file)
@test readstring(server_file) == readstring(local_file)

no_unexpected_changes(ftp)
Base.close(ftp)
cleanup_file(server_file)

# check mkdir
ftp = getFTPObj()
server_dir = joinpath(ROOT, testdir)
cleanup_dir(server_dir)
@test !isdir(server_dir)

resp = mkdir(ftp, testdir)
@test isdir(server_dir)
no_unexpected_changes(ftp)
cleanup_dir(server_dir)
Base.close(ftp)

# check mkdir error
ftp = getFTPObj()
@test !isdir(server_dir)
mkdir(server_dir)
@test isdir(server_dir)
@test_throws FTPClientError mkdir(ftp, testdir)
@test isdir(server_dir)
no_unexpected_changes(ftp)
cleanup_dir(server_dir)
Base.close(ftp)

# check cd
ftp = getFTPObj()
mkdir(server_dir)
cd(ftp, testdir)
no_unexpected_changes(ftp, "$host/$testdir")
cleanup_dir(server_dir)
Base.close(ftp)

# check cd error
ftp = getFTPObj()
@test !isdir(server_dir)
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
@test_throws FTPClientError cd(ftp, testdir)
no_unexpected_changes(ftp)
@test !isdir(server_dir)
Base.close(ftp)

# check cd path
ftp = getFTPObj()
mkdir(server_dir)
@test isdir(server_dir)
cd(ftp, testdir)
cd(ftp, "..")
no_unexpected_changes(ftp, "$host/$testdir/..")
cleanup_dir(server_dir)
Base.close(ftp)

# check rmdir
ftp = getFTPObj()
mkdir(server_dir)
@test isdir(server_dir)
rmdir(ftp, testdir)
@test !isdir(server_dir)
no_unexpected_changes(ftp)
Base.close(ftp)

# check rmdir error
ftp = getFTPObj()
@test !isdir(server_dir)
@test_throws FTPClientError rmdir(ftp, testdir)
@test !isdir(server_dir)
no_unexpected_changes(ftp)
Base.close(ftp)

# check pwd
ftp = getFTPObj()
@test pwd(ftp) == "/"
no_unexpected_changes(ftp)
Base.close(ftp)

# check mv
ftp = getFTPObj()
new_file = "test_mv2.txt"
server_file = joinpath(ROOT, mv_file)
tempfile(mv_file)
cp(mv_file, server_file)

server_new_file = joinpath(ROOT, new_file)
@test !isfile(server_new_file)
@test isfile(server_file)

mv(ftp, mv_file, new_file)
@test !isfile(server_file)
@test isfile(server_new_file)
@test readstring(server_new_file) == readstring(mv_file)
no_unexpected_changes(ftp)
cleanup_file(server_new_file)

Base.close(ftp)

# check rm
ftp = getFTPObj()
cp(mv_file, server_file)
@test isfile(server_file)
rm(ftp, mv_file)
@test !isfile(server_file)
no_unexpected_changes(ftp)
Base.close(ftp)

# check rm error
ftp = getFTPObj()
@test !isfile(server_file)
@test_throws FTPClientError rm(ftp, mv_file)
@test !isfile(server_file)
no_unexpected_changes(ftp)
Base.close(ftp)

# check upload
ftp = getFTPObj()
server_file = joinpath(ROOT, upload_file)
@test isfile(upload_file)
@test !isfile(server_file)
resp = upload(ftp, upload_file)

@test isfile(server_file)
@test readstring(server_file) == readstring(upload_file)
no_unexpected_changes(ftp)
cleanup_file(server_file)
Base.close(ftp)

# check upload to named file
ftp = getFTPObj()
server_file= joinpath(ROOT, "some name")
@test !isfile(server_file)
resp = upload(ftp, upload_file, "some name")

@test isfile(server_file)
@test readstring(server_file) == readstring(upload_file)
no_unexpected_changes(ftp)
cleanup_file(server_file)
Base.close(ftp)

# check write to file
ftp = getFTPObj()
server_file= joinpath(ROOT, "some other name")
@test !isfile(server_file)
open(upload_file) do fp
    resp = upload(ftp, fp, "some other name")
end
@test isfile(server_file)
@test readstring(server_file) == readstring(upload_file)
no_unexpected_changes(ftp)
cleanup_file(server_file)
Base.close(ftp)


#check for expected output
expected = "Host:      ftp://" * string(host) * "/\nUser:      $(user)\nTransfer:  active mode\nSecurity:  None\n\n"
buff = IOBuffer()
ftp = FTP(ssl=false, active=true, user=user, pswd=pswd, host=host)
println(buff, ftp)
seekstart(buff)
@test readstring(buff) == expected
Base.close(ftp)


expected = "Host:      ftp://" * string(host) * "/\nUser:      $(user)\nTransfer:  passive mode\nSecurity:  None\n\n"
buff = IOBuffer()
ftp = FTP(ssl=false, active=false, user=user, pswd=pswd, host=host)
println(buff, ftp)
seekstart(buff)
@test readstring(buff) == expected
Base.close(ftp)


# ftp_cleanup()

    # check do (doesn't work)
 # ftp(ssl=false, user=user, pswd=pswd, host=host) do f
 # buff = download(f, file_name)
 # @test readstring(buff) == file_contents
 # no_unexpected_changes(f)
 # end
ftp_cleanup()
close(server)

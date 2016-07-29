
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
file_name = "test_download.txt"
testdir = "testdir"


expected_header_port = r"229 Entering Extended Passive Mode \(\|\|\|\d*\|\)"


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

getFTP()= FTP(ssl=false, user=user, pswd=pswd, host=host)

ftp = getFTP()
no_unexpected_changes(ftp)
Base.close(ftp)



ftp = getFTP()
dir = readdir(ftp)
contains(string(dir), "test_directory")
contains(string(dir), "test_byte_file")
contains(string(dir), "test_upload.txt")
contains(string(dir), "test_download.txt")
no_unexpected_changes(ftp)
Base.close(ftp)


ftp = getFTP()
buff = download(ftp, file_name)
@test readstring(buff) == readstring(joinpath(ROOT,file_name))
no_unexpected_changes(ftp)
Base.close(ftp)

ftp = getFTP()
local_file = "test_upload.txt"
server_file = joinpath(ROOT, "test_upload.txt")
tempfile(local_file)
@test isfile(local_file)
resp = upload(ftp, local_file)
@test isfile(server_file)
@test readstring(server_file) == readstring(local_file)

no_unexpected_changes(ftp)
Base.close(ftp)
cleanup_file(server_file)

ftp = getFTP()
server_testdir = joinpath(ROOT, testdir)
cleanup_file(server_testdir)

@test !isdir(server_testdir)
resp = mkdir(ftp, testdir)
@test isdir(server_testdir)
no_unexpected_changes(ftp)
cleanup_dir(server_testdir)
Base.close(ftp)

ftp = getFTP()
@test !isdir(server_testdir)
mkdir(server_testdir)
@test isdir(server_testdir)
@test_throws FTPClientError mkdir(ftp, testdir)
@test isdir(server_testdir)
no_unexpected_changes(ftp)
cleanup_dir(server_testdir)
Base.close(ftp)

ftp = getFTP()
mkdir(server_testdir)
cd(ftp, testdir)
no_unexpected_changes(ftp, "$host/$testdir")
cleanup_dir(server_testdir)
Base.close(ftp)

ftp = getFTP()
@test !isdir(server_testdir)
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
@test_throws FTPClientError cd(ftp, testdir)
no_unexpected_changes(ftp)
@test !isdir(server_testdir)
Base.close(ftp)

ftp = getFTP()
mkdir(server_testdir)
@test isdir(server_testdir)
cd(ftp, testdir)
cd(ftp, "..")
no_unexpected_changes(ftp, "$host/$testdir/..")
cleanup_dir(server_testdir)
Base.close(ftp)

ftp = getFTP()
mkdir(server_testdir)
@test isdir(server_testdir)
rmdir(ftp, testdir)
@test !isdir(server_testdir)
no_unexpected_changes(ftp)
Base.close(ftp)

ftp = getFTP()
@test !isdir(server_testdir)
@test_throws FTPClientError rmdir(ftp, testdir)
@test !isdir(server_testdir)
no_unexpected_changes(ftp)
Base.close(ftp)

ftp = getFTP()
@test pwd(ftp) == "/"
no_unexpected_changes(ftp)
Base.close(ftp)

ftp = getFTP()
mv_file_name = "test_mv.txt"
new_file = joinpath(ROOT, "test_mv2.txt")
@test !isfile(new_file)
server_mv_file_name = joinpath(ROOT, mv_file_name)
cp(joinpath(ROOT,"test_download.txt"), server_mv_file_name)
@test isfile(server_mv_file_name)
mv(ftp, mv_file_name, "test_mv2.txt")
@test !isfile(server_mv_file_name)
@test isfile(new_file)
@test readstring(new_file) == readstring(joinpath(ROOT,"test_download.txt"))
no_unexpected_changes(ftp)
cleanup_file(new_file)
Base.close(ftp)


ftp = getFTP()
cp(joinpath(ROOT,"test_download.txt"), new_file)
@test isfile(new_file)
rm(ftp, "test_mv2.txt")
@test !isfile(new_file)
no_unexpected_changes(ftp)
Base.close(ftp)

ftp = getFTP()
@test !isfile(new_file)
@test_throws FTPClientError rm(ftp, "test_mv2.txt")
@test !isfile(new_file)
no_unexpected_changes(ftp)
Base.close(ftp)

upload_file_name = "test_upload.txt"
ftp = getFTP()
server_file = joinpath(ROOT, upload_file_name)
@test isfile(upload_file_name)
@test !isfile(server_file)
resp = upload(ftp, upload_file_name)

@test isfile(server_file)
@test readstring(server_file) == readstring(upload_file_name)
no_unexpected_changes(ftp)
cleanup_file(server_file)
Base.close(ftp)

ftp = getFTP()
resp = upload(ftp, upload_file_name, "some name")
server_file= joinpath(ROOT, "some name")
@test isfile(server_file)
@test readstring(server_file) == readstring(upload_file_name)
no_unexpected_changes(ftp)
cleanup_file(server_file)
Base.close(ftp)

ftp = getFTP()
server_file= joinpath(ROOT, "some other name")
open(upload_file_name) do fp
    resp = upload(ftp, fp, "some other name")
end
@test isfile(server_file)
@test readstring(server_file) == readstring(upload_file_name)
no_unexpected_changes(ftp)
cleanup_file(server_file)
Base.close(ftp)



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


 # ftp(ssl=false, user=user, pswd=pswd, host=host) do f
 # buff = download(f, file_name)
 # @test readstring(buff) == file_contents
 # no_unexpected_changes(f)
 # end
ftp_cleanup()
close(server)

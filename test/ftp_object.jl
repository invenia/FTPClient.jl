mv_file = "test_mv.txt"
tempfile(mv_file)


function no_unexpected_changes(ftp::FTP, hostname::AbstractString=host)
    other = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @test ftp.ctxt.options == other.ctxt.options
    @test ftp.ctxt.url == "ftp://$hostname/"
    Base.close(other)
end

function expected_output(active::Bool)
    mode = active? "active":"passive"
    expected = "Host:      ftp://" * string(host) * "/\nUser:      $(user)\nTransfer:  $mode mode\nSecurity:  None\n\n"

    buff = IOBuffer()
    ftp = FTP(ssl=false, active=active, user=user, pswd=pswd, host=host)
    println(buff, ftp)
    seekstart(buff)
    @test readstring(buff) == expected
    Base.close(ftp)
end

getFTPObj()= FTP(ssl=false, user=user, pswd=pswd, host=host)

# check connection error
@test_throws FTPClientError FTP(ssl=false, user=user, pswd=pswd, host="not a host")

# check object
ftp = getFTPObj()
no_unexpected_changes(ftp)
Base.close(ftp)

# check readdir
ftp = getFTPObj()
server_dir = readdir(ftp)
contains(string(server_dir), "test_directory")
contains(string(server_dir), "test_byte_file")
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

# check bad directory error
ftp = getFTPObj()
@test_throws FTPClientError mkdir(ftp, "")
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
cp(mv_file, server_file)

server_new_file = joinpath(ROOT, new_file)
@test isfile(server_file)

mv(ftp, mv_file, new_file)
@test !isfile(server_file)
@test isfile(server_new_file)
@test readstring(server_new_file) == readstring(mv_file)
no_unexpected_changes(ftp)
Base.close(ftp)

# check mv error
ftp = getFTPObj()
@test_throws FTPClientError mv(ftp, "", "")
Base.close(ftp)


# check mv error 2
ftp = getFTPObj()
@test_throws FTPClientError mv(ftp, download_file, "")
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
expected_output(true)

expected_output(false)

cleanup_file(mv_file)


 # check do (doesn't work)
  # ftp(ssl=false, user=user, pswd=pswd, host=host) do f
  # buff = download(f, file_name)
  # @test readstring(buff) == file_contents
  # no_unexpected_changes(f)
  # end



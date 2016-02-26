using FTPClient

###############################################################################
# FTPObject
###############################################################################

dir_with_space = "Dir name with space"
file_with_space = "file with space.txt"
space_file_contents = "test file with space.\n"
ftp_init()

println("\nTest FTPObject with persistent connection:\n")

# test 17, establish connection
ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
println("\nTest 17 passed.\n$(ftp)")

# test 18, get a list of directory's contents
dir = readdir(ftp)
# Check if there are any differences
@test setdiff(dir, ["test_directory",byte_file_name,"test_upload.txt","test_download.txt"]) == Array{ASCIIString,1}()
println("\nTest 18 passed.\n$(ftp)")

# test 19, download file from server
buff = download(ftp, file_name)
@compat @test readstring(buff) == file_contents
println("\nTest 19 passed.\n$(ftp)")

# test 20, upload a file
upload(ftp, upload_file)
println("\nTest 20 passed.\n$(ftp)")

# test 21, make a diretory
mkdir(ftp, testdir)
println("\nTest 21 passed.\n$(ftp)")

# test 22, try making a directory that already exists
@test_throws FTPClientError mkdir(ftp, testdir)
println("\nTest 22 passed.\n$(ftp)")

# test 23, change directory
cd(ftp, testdir)
println("\nTest 23 passed.\n$(ftp)")

# test 24, try changing to a directory that doesn't exsit
@test_throws FTPClientError cd(ftp, "not_a_directory")
println("\nTest 24 passed.\n$(ftp)")

# test 25, go to parent directory
cd(ftp, "..")
readdir(ftp)
println("\nTest 25 passed.\n$(ftp)")

# test 26, remove the test directory
rmdir(ftp, testdir)
println("\nTest 26 passed.\n$(ftp)")

# test 27, try removing a directory that doesn't exists
@test_throws FTPClientError rmdir(ftp, testdir)
println("\nTest 27 passed.\n$(ftp)")

# test 28, get current directory path
path = pwd(ftp)
@test path == "/"
println("\nTest 28 passed.\n$(ftp)")

# test 29, rename uploaded file
mv(ftp, upload_file, new_file)
println("\nTest 29 passed.\n$(ftp)")

# test 30, remove the uploaded file
rm(ftp, new_file)
println("\nTest 30 passed.\n$(ftp)")

# test 31, try removing a file that doesn't exists
@test_throws FTPClientError rm(ftp, new_file)
println("\nTest 31 passed.\n$(ftp)")

binary(ftp)
println("\nTest 32 passed.\n$(ftp)")

ascii(ftp)
println("\nTest 33 passed.\n$(ftp)")

println("\nTest FTPObject with non-blocking upload/download:\n")

# test connect with non-blocking call
ftp = FTP(block=false, ssl=false, user=user, pswd=pswd, host=host)
println("\nTest 34 passed.\n$(ftp)")

# test 35, download file from server using blocking function
buff = download(ftp, file_name)
@compat @test readstring(buff) == file_contents
println("\nTest 35 passed.\n$(ftp)")

# test 36, upload a file using blocking function
upload(ftp, upload_file)
println("\nTest 36 passed.\n$(ftp)")

# test 37, download file from server using non-blocking function
ref = non_block_download(ftp, file_name)
buff = get_download_resp(ref)
@compat @test readstring(buff) == file_contents
println("\nTest 37 passed.\n$(ftp)")

# test 38, upload a file using blocking function
open(upload_file) do file
    ref = non_block_upload(ftp, upload_file, file)
    get_upload_resp(ref)
end
println("\nTest 38 passed.\n$(ftp)")

# test 39, make a directory with spaces in name
mkdir(ftp, dir_with_space)
println("\nTest 39 passed.\n$(ftp)")

# test 40, get directory list with space in name
dir = readdir(ftp)
# Check if there are any differences
@test setdiff(dir, [dir_with_space, directory_name, byte_file_name, upload_file, file_name]) == Array{ASCIIString,1}()
println("\nTest 40 passed.\n$(ftp)")

# test 41, change to directory with spaces in name
cd(ftp, dir_with_space)
println("\nTest 41 passed.\n$(ftp)")

# test 42, upload file with space in name
upload(ftp, IOBuffer(space_file_contents), file_with_space)
println("\nTest 42 passed.\n$(ftp)")
dir = readdir(ftp)
@test dir == [file_with_space]

# test 43, download file with space in name
buff = download(ftp, file_with_space)
@compat @test readstring(buff) == space_file_contents
println("\nTest 43 passed.\n$(ftp)")

# test 44, remove file with space in name
rm(ftp, file_with_space)
println("\nTest 44 passed.\n$(ftp)")

# test 45, remove directory with space in name
cd(ftp, "..")
rmdir(ftp, dir_with_space)
println("\nTest 45 passed.\n$(ftp)")

@testset "FTPClient FTPObject tests" begin
    @testset "uploading a file with only the local file name" begin
        ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
        resp = upload(ftp, upload_file)
        @test resp.code == 226
    end
    @testset "uploading a file with remote local file name" begin
        ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
        resp = upload(ftp, upload_file, "some name")
        @test resp.code == 226
    end
    @testset "uploading a file with remote local file name" begin
        ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
        open(upload_file) do local_file
            resp = upload(ftp, local_file, "some other name")
        end
        @test resp.code == 226
    end
end

close(ftp)
ftp_cleanup()

println("FTPObject tests passed.\n\n")


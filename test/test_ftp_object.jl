@testset "FTPObject" begin

    expected_header_port = r"229 Entering Extended Passive Mode \(\|\|\|\d*\|\)"
    dir_with_space = "Dir name with space"
    file_with_space = "file with space.txt"
    space_file_contents = "test file with space.\n"
    ftp_init()

    @testset "with persistent connection" begin

        function no_unexpected_changes(ftp::FTP)
            @test ftp.ctxt.options.ssl == false
            @test ftp.ctxt.options.username == user
            @test ftp.ctxt.options.passwd == pswd
            @test ftp.ctxt.options.hostname == host
            @test ftp.ctxt.options.url == "ftp://"* host * "/"
            @test ftp.ctxt.options.blocking == true
            @test ftp.ctxt.options.implicit == false
            @test ftp.ctxt.options.verify_peer == true
            @test ftp.ctxt.options.active_mode == false
            @test ftp.ctxt.options.binary_mode == true
        end


        @testset "connection" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "readdir" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            dir = readdir(ftp)
            @test setdiff(dir, ["test_directory",byte_file_name,"test_upload.txt","test_download.txt"]) == Array{ASCIIString,1}()
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "download" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            buff = download(ftp, file_name)
            actual_buff = readstring(buff)
            @test actual_buff == file_contents
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "upload" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !file_exists("/" * upload_file)
            resp = upload(ftp, upload_file)
            @test file_exists("/" * upload_file)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            remove("/" * upload_file)
            @test !file_exists("/" * upload_file)
            close(ftp)
        end

        @testset "mkdir" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !directory_exists("/" * testdir)
            resp = mkdir(ftp, testdir)
            @test directory_exists("/" * testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "mkdir a directory that already exists" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !directory_exists("/" * testdir)
            set_directory("/" * testdir)
            @test directory_exists("/" * testdir)
            @test_throws FTPClientError mkdir(ftp, testdir)
            @test directory_exists("/" * testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "cd" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_directory("/" * testdir)
            cd(ftp, testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/" * testdir * "/"
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "cd into a directory that doesn't exists" begin
            @test !directory_exists("/" * testdir)
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError cd(ftp, "not_a_directory")
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "cd into parent directory" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_directory("/" * testdir)
            @test directory_exists("/" * testdir)
            cd(ftp, testdir)
            cd(ftp, "..")
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/" * testdir * "/../"
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "rmdir" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_directory("/" * testdir)
            @test directory_exists("/" * testdir)
            rmdir(ftp, testdir)
            @test !directory_exists("/" * testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "rmdir a directory that doesn't exists" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !directory_exists("/" * testdir)
            @test_throws FTPClientError rmdir(ftp, testdir)
            @test !directory_exists("/" * testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "pwd" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            path = pwd(ftp)
            @test path == "/"
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "mv" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_file("/" * upload_file, file_contents)
            @test file_exists("/" * upload_file)
            mv(ftp, upload_file, new_file)
            @test !file_exists("/" * upload_file)
            @test file_exists("/" * new_file)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            remove("/" * new_file)
            @test !file_exists("/" * new_file)
            close(ftp)
        end

        @testset "rm" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_file("/" * new_file, file_contents)
            @test file_exists("/" * new_file)
            rm(ftp, new_file)
            @test !file_exists("/" * new_file)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "rm a file that doesn't exists" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !file_exists("/" * new_file)
            @test_throws FTPClientError rm(ftp, new_file)
            @test !file_exists("/" * new_file)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://" * host * "/"
            close(ftp)
        end

        @testset "binary" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host, binary_mode=false)
            binary(ftp)
            @test ftp.ctxt.options.binary_mode == true
            close(ftp)
        end

        @testset "binary" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host, binary_mode=true)
            ascii(ftp)
            @test ftp.ctxt.options.binary_mode == false
            close(ftp)
        end

    end

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
    file = open(upload_file)
    ref = non_block_upload(ftp, upload_file, file)
    get_upload_resp(ref)
    close(file)
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
    upload(ftp, file_with_space, IOBuffer(space_file_contents))
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

    close(ftp)
    ftp_cleanup()

end

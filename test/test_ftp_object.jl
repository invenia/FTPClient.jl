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
            @test ftp.ctxt.options.url == "ftp://$host/"
            @test ftp.ctxt.options.implicit == false
            @test ftp.ctxt.options.verify_peer == true
            @test ftp.ctxt.options.active_mode == false
            @test ftp.ctxt.options.binary_mode == true
        end

        @testset "connection" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "readdir" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            dir = readdir(ftp)
            @test setdiff(dir, ["test_directory",byte_file_name,"test_upload.txt","test_download.txt"]) == ASCIIString[]
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "download" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            buff = download(ftp, file_name)
            actual_buff = readstring(buff)
            @test actual_buff == file_contents
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "upload" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !file_exists("/" * upload_file_name)
            resp = upload(ftp, upload_file_name)
            @test file_exists("/" * upload_file_name)
            @test get_file_contents("/" * upload_file_name) == upload_file_contents
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            remove("/" * upload_file_name)
            @test !file_exists("/" * upload_file_name)
            close(ftp)
        end

        @testset "mkdir" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !directory_exists("/" * testdir)
            resp = mkdir(ftp, testdir)
            @test directory_exists("/" * testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
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
            @test ftp.ctxt.url == "ftp://$host/"
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "cd" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_directory("/" * testdir)
            cd(ftp, testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/" * testdir * "/"
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "cd into a directory that doesn't exists" begin
            @test !directory_exists("/" * testdir)
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError cd(ftp, "not_a_directory")
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
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
            @test ftp.ctxt.url == "ftp://$host/" * testdir * "/../"
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
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "rmdir a directory that doesn't exists" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !directory_exists("/" * testdir)
            @test_throws FTPClientError rmdir(ftp, testdir)
            @test !directory_exists("/" * testdir)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "pwd" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            path = pwd(ftp)
            @test path == "/"
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "mv" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_file("/" * upload_file_name, upload_file_contents)
            @test file_exists("/" * upload_file_name)
            mv(ftp, upload_file_name, new_file)
            @test !file_exists("/" * upload_file_name)
            @test file_exists("/" * new_file)
            @test get_file_contents("/" * new_file) == upload_file_contents
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            remove("/" * new_file)
            @test !file_exists("/" * new_file)
            close(ftp)
        end

        @testset "rm" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_file("/" * new_file, upload_file_contents)
            @test file_exists("/" * new_file)
            rm(ftp, new_file)
            @test !file_exists("/" * new_file)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "rm a file that doesn't exists" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !file_exists("/" * new_file)
            @test_throws FTPClientError rm(ftp, new_file)
            @test !file_exists("/" * new_file)
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
            close(ftp)
        end

        @testset "binary" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host, binary_mode=false)
            binary(ftp)
            @test ftp.ctxt.options.binary_mode == true
            close(ftp)
        end

        @testset "ascii" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host, binary_mode=true)
            ascii(ftp)
            @test ftp.ctxt.options.binary_mode == false
            close(ftp)
        end

        @testset "upload" begin
            @testset "uploading a file with only the local file name" begin
                ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
                resp = upload(ftp, upload_file_name)
                @test file_exists("/" * upload_file_name)
                @test get_file_contents("/" * upload_file_name) == upload_file_contents
                no_unexpected_changes(ftp)
                @test ftp.ctxt.url == "ftp://$host/"
                remove("/" * upload_file_name)
                @test !file_exists("/" * upload_file_name)
                close(ftp)
            end
            @testset "uploading a file with remote local file name" begin
                ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
                resp = upload(ftp, upload_file_name, "some name")
                @test file_exists("/" * "some name")
                @test get_file_contents("/" * "some name") == upload_file_contents
                no_unexpected_changes(ftp)
                @test ftp.ctxt.url == "ftp://$host/"
                remove("/" * "some name")
                @test !file_exists("/" * "some name")
                close(ftp)
            end
            @testset "uploading a file with remote local file name" begin
                ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
                resp = nothing
                open(upload_file_name) do local_file
                    resp = upload(ftp, local_file, "some other name")
                end
                @test file_exists("/" * "some other name")
                @test get_file_contents("/" * "some other name") == upload_file_contents
                no_unexpected_changes(ftp)
                @test ftp.ctxt.url == "ftp://$host/"
                remove("/" * "some other name")
                @test !file_exists("/" * "some other name")
                close(ftp)
            end
        end

        @testset "show" begin
            @testset "active" begin
                expected = "Host:      ftp://" * string(host) * "/\nUser:      $(user)\nTransfer:  active mode\nSecurity:  None\n\n"
                buff = IOBuffer()
                ftp = FTP(ssl=false, active=true, user=user, pswd=pswd, host=host)
                println(buff, ftp)
                seekstart(buff)
                @test readstring(buff) == expected
                close(ftp)
            end
            @testset "passive" begin
                expected = "Host:      ftp://" * string(host) * "/\nUser:      $(user)\nTransfer:  passive mode\nSecurity:  None\n\n"
                buff = IOBuffer()
                ftp = FTP(ssl=false, active=false, user=user, pswd=pswd, host=host)
                println(buff, ftp)
                seekstart(buff)
                @test readstring(buff) == expected
                close(ftp)
            end
        end

    end
    ftp_cleanup()

    @testset "ftp() do ftp_client end" begin
        ftp(ssl=false, user=user, pswd=pswd, host=host) do ftp
            buff = download(ftp, file_name)
            actual_buff = readstring(buff)
            @test actual_buff == file_contents
            no_unexpected_changes(ftp)
            @test ftp.ctxt.url == "ftp://$host/"
        end
    end
end

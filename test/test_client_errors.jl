@testset "Client Errors" begin

    ftp_init()

    @testset "ftp_connect error" begin

        buff = IOBuffer()
        msg = "This will go into the message"
        lib_curl_error = 765
        error = FTPClientError(msg, lib_curl_error)
        showerror(buff, error)
        seekstart(buff)
        @test "$msg :: LibCURL error #$lib_curl_error" == readstring(buff)

    end

    @testset "Testing for client failure in FTPC.jl" begin

        @testset "ftp_connect error" begin
            options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname="not a host")
            @test_throws FTPClientError ftp_connect(options)
        end

        @testset "ftp_put error" begin
            options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
            open(upload_file) do file
                @test_throws FTPClientError ftp_put(upload_file, file, options)
            end
        end

        @testset "ftp_get error" begin
            options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
            @test_throws FTPClientError ftp_get(file_name, options)
        end

        @testset "ftp_command error" begin
            options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
            @test_throws FTPClientError ftp_command("NLST", options)
        end

    end

    @testset "Testing for client failure in FTPObject.jl" begin

        @testset "FTP object error when connecting" begin
            @test_throws FTPClientError FTP(ssl=false, user=user, pswd=pswd, host="not a host")
        end

        @testset "FTP object error when downloading, blocking" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError download(ftp, file_name)
            close(ftp)
        end

        @testset "FTP object error when uploading, blocking" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError upload(ftp, upload_file)
            close(ftp)
        end

        @testset "FTP object error when changing working directory" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError cd(ftp, testdir)
            close(ftp)
        end

        @testset "FTP object error when getting path of working directory" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError pwd(ftp)
            close(ftp)
        end

        @testset "FTP object error when removing a file that doesn't exist" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError rm(ftp, "not_a_file")
            close(ftp)
        end

        @testset "FTP object error when removing a directory that doesn't exist" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError rmdir(ftp, "not_a_directory")
            close(ftp)
        end

        @testset "FTP object error when creating a bad directory" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError mkdir(ftp, "")
            close(ftp)
        end

        @testset "FTP object error when moving bad directories" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError mv(ftp, "", "")
            close(ftp)
        end

        @testset "FTP object error when moving bad directories 2" begin
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test_throws FTPClientError mv(ftp, file_name, "")
            close(ftp)
        end

        @testset "FTP object error when switching to binary" begin
            undo_errors()
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_type_error()
            @test_throws FTPClientError binary(ftp)
            close(ftp)
        end

        @testset "FTP object error when switching to ascii" begin
            undo_errors()
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_type_error()
            @test_throws FTPClientError ascii(ftp)
            close(ftp)
        end

        @testset "FTP object error with LIST command" begin
            undo_errors()
            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_list_error()
            @test_throws FTPClientError readdir(ftp)
            close(ftp)
        end

    end

    ftp_cleanup()

end

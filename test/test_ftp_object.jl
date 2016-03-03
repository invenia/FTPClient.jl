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

    @testset "verbose" begin

        function test_captured_ouput(test::Function, expected::Regex)
            original_stderr = STDOUT
            out_read, out_write = redirect_stderr()

            test()

            close(out_write)
            data = readavailable(out_read)
            close(out_read)
            redirect_stdout(original_stderr)

            @test ismatch(expected, ASCIIString(data))
        end

        expected = r""

        @testset "FTP" begin

            expected = r"\*   Trying ::1...
\* Connected to localhost \(::1\) port \d* \(#0\)
< 220 Service ready for new user. \(MockFtpServer 2.6; see http://mockftpserver.sourceforge.net\)\r
> USER test\r
< 331 User name okay, need password.\r
> PASS test\r
< 230 User logged in, proceed.\r
> PWD\r
< 257 \"/\" is current directory.\r
\* Entry path is '/'
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> TYPE A\r
< 200 TYPE completed.\r
> LIST\r
< 150 File status okay; about to open data connection.\r
\* Maxdownload = -1
\* Remembering we are in dir \"\"
< 226 Closing data connection. Requested file action successful.\r
\* Connection #0 to host localhost left intact
"
            test_captured_ouput(expected) do
                FTP(ssl=false, user=user, pswd=pswd, host=host; verbose=true)
            end
        end

        @testset "readdir" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> LIST\r
< 150 File status okay; about to open data connection.\r
\* Maxdownload = -1
\* Remembering we are in dir \"\"
< 226 Closing data connection. Requested file action successful.\r
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            test_captured_ouput(expected) do
                readdir(ftp; verbose=true)
            end
            close(ftp)
        end

        @testset "download" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> TYPE I\r
< 200 TYPE completed.\r
> SIZE test_download.txt\r
< 502 Command not implemented: SIZE.\r
> RETR test_download.txt\r
< 150 File status okay; about to open data connection.\r
\* Maxdownload = -1
\* Getting file with size: -1
\* Remembering we are in dir \"\"
< 226 Closing data connection. Requested file action successful.\r
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            buff = nothing
            test_captured_ouput(expected) do
                buff = download(ftp, file_name; verbose=true)
            end
            actual_buff = readstring(buff)
            @test actual_buff == file_contents
            close(ftp)
        end

        @testset "upload" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> TYPE I\r
< 200 TYPE completed.\r
> STOR test_upload.txt\r
< 150 File status okay; about to open data connection.\r
\* We are completely uploaded and fine
\* Remembering we are in dir \"\"
< 226 Created file test_upload.txt.\r
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !file_exists("/" * upload_file_name)
            test_captured_ouput(expected) do
                upload(ftp, upload_file_name; verbose=true)
            end
            @test file_exists("/" * upload_file_name)
            @test get_file_contents("/" * upload_file_name) == upload_file_contents
            remove("/" * upload_file_name)
            @test !file_exists("/" * upload_file_name)
            close(ftp)
        end

        @testset "mkdir" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> MKD testdir\r
< 257 \"/testdir\" created.\r
\* RETR response: 257
\* Remembering we are in dir \"\"
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            @test !directory_exists("/" * testdir)
            test_captured_ouput(expected) do
                mkdir(ftp, testdir; verbose=true)
            end
            @test directory_exists("/" * testdir)
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "cd" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> CWD testdir/\r
< 250 CWD completed. New directory is /testdir.\r
\* RETR response: 250
\* Remembering we are in dir \"\"
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_directory("/" * testdir)
            test_captured_ouput(expected) do
                cd(ftp, testdir; verbose=true)
            end
            remove("/" * testdir)
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "rmdir" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> RMD testdir\r
< 250 \"/testdir\" removed.\r
\* RETR response: 250
\* Remembering we are in dir \"\"
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_directory("/" * testdir)
            @test directory_exists("/" * testdir)
            test_captured_ouput(expected) do
                rmdir(ftp, testdir; verbose=true)
            end
            @test !directory_exists("/" * testdir)
            close(ftp)
        end

        @testset "pwd" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> PWD\r
< 257 \"/\" is current directory.\r
\* RETR response: 257
\* Remembering we are in dir \"\"
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            path = nothing
            test_captured_ouput(expected) do
                path = pwd(ftp; verbose=true)
            end
            @test path == "/"
            close(ftp)
        end

        @testset "mv" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> RNFR test_upload.txt\r
< 350 Requested file action pending further information.\r
\* RETR response: 350
\* Remembering we are in dir \"\"
\* Connection #0 to host localhost left intact
\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> RNTO new_name.txt\r
< 250 Rename from /test_upload.txt to /new_name.txt completed.\r
\* RETR response: 250
\* Remembering we are in dir \"\"
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_file("/" * upload_file_name, upload_file_contents)
            @test file_exists("/" * upload_file_name)
            test_captured_ouput(expected) do
                mv(ftp, upload_file_name, new_file; verbose=true)
            end
            @test !file_exists("/" * upload_file_name)
            @test file_exists("/" * new_file)
            @test get_file_contents("/" * new_file) == upload_file_contents
            remove("/" * new_file)
            @test !file_exists("/" * new_file)
            close(ftp)
        end

        @testset "rm" begin

            expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> DELE new_name.txt\r
< 250 \"/new_name.txt\" deleted.\r
\* RETR response: 250
\* Remembering we are in dir \"\"
\* Connection #0 to host localhost left intact
"

            ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
            set_file("/" * new_file, upload_file_contents)
            @test file_exists("/" * new_file)
            test_captured_ouput(expected) do
                rm(ftp, new_file; verbose=true)
            end
            @test !file_exists("/" * new_file)
            close(ftp)
        end

        @testset "upload" begin
            @testset "uploading a file with only the local file name" begin

                expected = r"\* Found bundle for host localhost: 0x[0-9a-f]{12}
\* Re-using existing connection! \(#0\) with host localhost
\* Connected to localhost \(::1\) port \d* \(#0\)
\* Request has same path as previous transfer
> EPSV\r
\* Connect data stream passively
\* ftp_perform ends with SECONDARY: 0
< 229 Entering Extended Passive Mode \(\|\|\|\d*\|\)\r
\*   Trying ::1...
\* Connecting to ::1 \(::1\) port \d*
\* Connected to localhost \(::1\) port \d* \(#0\)
> TYPE I\r
< 200 TYPE completed.\r
> STOR test_upload.txt\r
< 150 File status okay; about to open data connection.\r
\* We are completely uploaded and fine
\* Remembering we are in dir \"\"
< 226 Created file test_upload.txt.\r
\* Connection #0 to host localhost left intact
"

                ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
                test_captured_ouput(expected) do
                    upload(ftp, upload_file_name; verbose=true)
                end
                @test file_exists("/" * upload_file_name)
                @test get_file_contents("/" * upload_file_name) == upload_file_contents
                remove("/" * upload_file_name)
                @test !file_exists("/" * upload_file_name)
                close(ftp)
            end
            @testset "uploading a file with remote local file name" begin
                ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
                test_captured_ouput(expected) do
                    upload(ftp, upload_file_name, upload_file_name; verbose=true)
                end
                @test file_exists("/" * upload_file_name)
                @test get_file_contents("/" * upload_file_name) == upload_file_contents
                remove("/" * upload_file_name)
                @test !file_exists("/" * upload_file_name)
                close(ftp)
            end
            @testset "uploading a file with remote local file name" begin
                ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
                resp = nothing
                open(upload_file_name) do local_file
                    test_captured_ouput(expected) do
                        upload(ftp, local_file, upload_file_name; verbose=true)
                    end
                end
                @test file_exists("/" * upload_file_name)
                @test get_file_contents("/" * upload_file_name) == upload_file_contents
                remove("/" * upload_file_name)
                @test !file_exists("/" * upload_file_name)
                close(ftp)
            end
        end

    end

    ftp_cleanup()
end

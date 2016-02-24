@testset "FTPClient test non ssl" begin
    ftp_init()

    non_ssl_test_upload = "test_upload.txt"

    @testset "Non-persistent connection tests, passive mode" begin

        options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
        expected_header_first_part = AbstractString["220 Service ready for new user. (MockFtpServer 2.6; see http://mockftpserver.sourceforge.net)","331 User name okay, need password.","230 User logged in, proceed.","257 \"/\" is current directory."]
        expected_header_port = r"229 Entering Extended Passive Mode \(\|\|\|\d*\|\)"

        # The CI builds add this string to the end of the headers to non
        # persistent connections.
        possible_end_to_headers = "221 Service closing control connection."
        @test options.url == "ftp://" * string(host) * "/"

        @testset "ftp_get" begin
            resp = ftp_get(file_name, options)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == file_size == length(actual_body)
            @test actual_body == file_contents
            expected_header_last_part = AbstractString["200 TYPE completed.","502 Command not implemented: SIZE.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
            @test resp.headers[1:4] == expected_header_first_part
            @test ismatch(expected_header_port, resp.headers[5])
            @test resp.headers[6:end] == expected_header_last_part ||
                resp.headers[6:end] == [expected_header_last_part..., possible_end_to_headers]
        end

        @testset "ftp_put" begin
            @test !file_exists("/" * non_ssl_test_upload)
            resp = nothing
            open(upload_file) do file
                resp = ftp_put(non_ssl_test_upload, file, options)
            end
            @test file_exists("/" * non_ssl_test_upload)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == 0
            expected_header_last_part = AbstractString["200 TYPE completed.","150 File status okay; about to open data connection.","226 Created file test_upload.txt."]
            @test resp.headers[1:4] == expected_header_first_part
            @test ismatch(expected_header_port, resp.headers[5])
            @test resp.headers[6:end] == expected_header_last_part ||
                resp.headers[6:end] == [expected_header_last_part..., possible_end_to_headers]
            remove("/" * non_ssl_test_upload)
            @test !file_exists("/" * non_ssl_test_upload)
        end

        @testset "ftp_command" begin
            resp = ftp_command("PWD", options)
            @test resp.code == 257
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == 0
            expected_header_last_part = AbstractString["200 TYPE completed.","257 \"/\" is current directory."]
            @test resp.headers[1:4] == expected_header_first_part
            @test ismatch(expected_header_port, resp.headers[5])
            @test resp.headers[6:end] == expected_header_last_part ||
                resp.headers[6:end] == [expected_header_last_part..., possible_end_to_headers]
        end
    end

    @testset "Non-persistent connection tests, active mode" begin

        options = RequestOptions(ssl=false, active_mode=true, username=user, passwd=pswd, hostname=host)
        expected_header_first_part = AbstractString["220 Service ready for new user. (MockFtpServer 2.6; see http://mockftpserver.sourceforge.net)","331 User name okay, need password.","230 User logged in, proceed.","257 \"/\" is current directory.","200 EPRT completed.","200 TYPE completed."]
        @test options.url == "ftp://" * string(host) * "/"

        # The CI builds add this string to the end of the headers to non
        # persistent connections.
        possible_end_to_headers = "221 Service closing control connection."

        @testset "ftp_get" begin
            resp = ftp_get(file_name, options)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == file_size == length(actual_body)
            @test actual_body == file_contents
            expected_header_last_part = AbstractString["502 Command not implemented: SIZE.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
            @test resp.headers == [expected_header_first_part..., expected_header_last_part...] ||
                resp.headers == [expected_header_first_part...,expected_header_last_part..., possible_end_to_headers]
        end

        @testset "ftp_put" begin
            @test !file_exists("/" * non_ssl_test_upload)
            resp = nothing
            open(upload_file) do file
                resp = ftp_put(non_ssl_test_upload, file, options)
            end
            @test file_exists("/" * non_ssl_test_upload)
            @test resp.code ==226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == 0
            expected_header_last_part = AbstractString["150 File status okay; about to open data connection.","226 Created file test_upload.txt."]
            @test resp.headers == [expected_header_first_part..., expected_header_last_part...] ||
                resp.headers == [expected_header_first_part...,expected_header_last_part..., possible_end_to_headers]
            remove("/" * non_ssl_test_upload)
            @test !file_exists("/" * non_ssl_test_upload)
        end

        @testset "ftp_command" begin
            resp = ftp_command("PWD", options)
            @test resp.code == 257
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == 0
            expected_header_last_part = AbstractString["257 \"/\" is current directory."]
            @test resp.headers == [expected_header_first_part..., expected_header_last_part...] ||
                resp.headers == [expected_header_first_part...,expected_header_last_part..., possible_end_to_headers]
        end
    end

    @testset "Persistent connection tests, passive mode" begin

        options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
        @test options.url == "ftp://" * string(host) * "/"

        expected_header_port = r"229 Entering Extended Passive Mode \(\|\|\|\d*\|\)"

        @testset "ftp_connect" begin
            ctxt, resp = ftp_connect(options)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == length(actual_body)
            @test contains(actual_body, file_name)
            @test contains(actual_body, directory_name)
            @test contains(actual_body, byte_file_name)
            expected_header_first_part = AbstractString["220 Service ready for new user. (MockFtpServer 2.6; see http://mockftpserver.sourceforge.net)","331 User name okay, need password.","230 User logged in, proceed.","257 \"/\" is current directory."]
            expected_header_last_part = AbstractString["200 TYPE completed.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
            @test resp.headers[1:4] == expected_header_first_part
            @test ismatch(expected_header_port, resp.headers[5])
            @test resp.headers[6:end] == expected_header_last_part
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
        end

        @testset "ftp_command" begin
            ctxt, resp = ftp_connect(options)
            resp = ftp_command(ctxt, "PWD")
            actual_body = readstring(resp.body)
            @test resp.code == 257
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == length(actual_body) == 0
            @test actual_body == ""
            @test ismatch(expected_header_port, resp.headers[1])
            @test resp.headers[2:end] == AbstractString["257 \"/\" is current directory."]
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
        end

        @testset "ftp_get" begin
            ctxt, resp = ftp_connect(options)
            resp = ftp_get(ctxt, file_name)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == file_size == length(actual_body)
            @test actual_body == file_contents
            @test ismatch(expected_header_port, resp.headers[1])
            @test resp.headers[2:end] == AbstractString["200 TYPE completed.","502 Command not implemented: SIZE.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
        end

        @testset "ftp_put" begin
            @test !file_exists("/" * non_ssl_test_upload)
            ctxt, resp = ftp_connect(options)
            open(upload_file) do file
                resp = ftp_put(ctxt, non_ssl_test_upload, file)
            end
            @test file_exists("/" * non_ssl_test_upload)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == length(actual_body) == 0
            @test actual_body == ""
            @test ismatch(expected_header_port, resp.headers[1])
            @test resp.headers[2:end] == AbstractString["200 TYPE completed.","150 File status okay; about to open data connection.","226 Created file test_upload.txt."]
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
            remove("/" * non_ssl_test_upload)
            @test !file_exists("/" * non_ssl_test_upload)
        end

    end

    @testset "Persistent connection tests, active mode" begin

        options = RequestOptions(ssl=false, active_mode=true, username=user, passwd=pswd, hostname=host)
        @test options.url == "ftp://" * string(host) * "/"

        @testset "ftp_connect" begin
            ctxt, resp = ftp_connect(options)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == length(actual_body)
            @test contains(actual_body, file_name)
            @test contains(actual_body, directory_name)
            @test contains(actual_body, byte_file_name)
            @test resp.headers == AbstractString["220 Service ready for new user. (MockFtpServer 2.6; see http://mockftpserver.sourceforge.net)","331 User name okay, need password.","230 User logged in, proceed.","257 \"/\" is current directory.","200 EPRT completed.","200 TYPE completed.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
        end

        @testset "ftp_command" begin
            ctxt, resp = ftp_connect(options)
            resp = ftp_command(ctxt, "PWD")
            actual_body = readstring(resp.body)
            @test resp.code == 257
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == length(actual_body) == 0
            @test actual_body == ""
            @test resp.headers == AbstractString["200 EPRT completed.","257 \"/\" is current directory."]
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
        end

        @testset "ftp_get" begin
            ctxt, resp = ftp_connect(options)
            resp = ftp_get(ctxt, file_name)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == file_size == length(actual_body)
            @test actual_body == file_contents
            @test resp.headers == AbstractString["200 EPRT completed.","200 TYPE completed.","502 Command not implemented: SIZE.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
        end

        @testset "ftp_put" begin
            @test !file_exists("/" * non_ssl_test_upload)
            ctxt, resp = ftp_connect(options)
            open(upload_file) do file
                resp = ftp_put(ctxt, non_ssl_test_upload, file)
            end
            @test file_exists("/" * non_ssl_test_upload)
            actual_body = readstring(resp.body)
            @test resp.code == 226
            @test typeof(resp.total_time) == Float64
            @test resp.bytes_recd == length(actual_body) == 0
            @test actual_body == ""
            @test resp.headers == AbstractString["200 EPRT completed.","200 TYPE completed.","150 File status okay; about to open data connection.","226 Created file test_upload.txt."]
            @test typeof(ctxt.curl) == Ptr{CURL}
            @test ctxt.url == options.url == "ftp://" * string(host) * "/"
            @test ctxt.options == options
            ftp_close_connection(ctxt)
            remove("/" * non_ssl_test_upload)
            @test !file_exists("/" * non_ssl_test_upload)
        end

    end

    @testset "download a file to a specific path" begin

        options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
        save_file = "test_file_save_path.txt"
        save_path = pwd() * "/" * save_file
        resp = ftp_get(file_name, options, save_path)
        @test resp.code == 226
        @test isfile(save_file) == true
        open(save_file) do file
            @compat @fact readstring(file) --> file_contents
        end
        rm(save_file)

    end

    @testset "binary file download using options" begin
        @testset "it is not the same file when downloading in ascii mode" begin
            ftp_options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host, binary_mode=false)
            resp = ftp_get(byte_file_name, ftp_options)
            bytes = read(resp.body)
            @unix_only @test bytes != hex2bytes(byte_file_contents)
        end
        @testset "it is the same file when downloading in binary mode" begin
            ftp_options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host, binary_mode=true)
            resp = ftp_get(byte_file_name, ftp_options)
            bytes = read(resp.body)
            @test bytes == hex2bytes(byte_file_contents)
        end
    end
    @testset "binary file download using ctxt" begin
        @testset "it is not the same file when downloading in ascii mode" begin
            ftp_options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host, binary_mode=false)
            ctxt, resp = ftp_connect(ftp_options)
            resp = ftp_get(ctxt, byte_file_name)
            bytes = read(resp.body)
            @unix_only @test bytes != hex2bytes(byte_file_contents)
        end
        @testset "it is the same file when downloading in binary mode" begin
            ftp_options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host, binary_mode=true)
            ctxt, resp = ftp_connect(ftp_options)
            resp = ftp_get(ctxt, byte_file_name)
            bytes = read(resp.body)
            @test bytes == hex2bytes(byte_file_contents)
        end
    end
    @testset "binary file download using ftp object" begin
        @testset "it is not the same file when downloading in ascii mode" begin
            ftp = FTP(user=user, pswd=pswd, host=host, binary_mode=false)
            buff = download(ftp, byte_file_name)
            bytes = read(buff)
            @unix_only @test bytes != hex2bytes(byte_file_contents)
        end
        @testset "it is the same file when downloading in binary mode" begin
            ftp = FTP(user=user, pswd=pswd, host=host, binary_mode=true)
            buff = download(ftp, byte_file_name)
            bytes = read(buff)
            @test bytes == hex2bytes(byte_file_contents)
        end
    end
    @testset "binary file download using ftp object, start in ascii, and switch to binary, then back" begin
        ftp = FTP(user=user, pswd=pswd, host=host, binary_mode=false)
        buff = download(ftp, byte_file_name)
        bytes = read(buff)
        @unix_only @test bytes != hex2bytes(byte_file_contents)
        binary(ftp)
        buff = download(ftp, byte_file_name)
        bytes = read(buff)
        @test bytes == hex2bytes(byte_file_contents)
        ascii(ftp)
        buff = download(ftp, byte_file_name)
        bytes = read(buff)
        @unix_only @test bytes != hex2bytes(byte_file_contents)
    end

    @testset "Non-blocking mode" begin

        # The CI builds add this string to the end of the headers to non
        # persistent connections.
        possible_end_to_headers = "221 Service closing control connection."

        @testset "Non-persistent connection tests, passive mode" begin
            expected_header_first_part = AbstractString["220 Service ready for new user. (MockFtpServer 2.6; see http://mockftpserver.sourceforge.net)","331 User name okay, need password.","230 User logged in, proceed.","257 \"/\" is current directory."]
            expected_header_port = r"229 Entering Extended Passive Mode \(\|\|\|\d*\|\)"

            options = RequestOptions(blocking=false, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)

            @testset "ftp_get" begin
                rcall = ftp_get(file_name, options)
                @test typeof(rcall) <: Future
                resp = fetch(rcall)
                actual_body = readstring(resp.body)
                @test resp.code == 226
                @test typeof(resp.total_time) == Float64
                @test resp.bytes_recd == file_size == length(actual_body)
                @test actual_body == file_contents
                expected_header_last_part = AbstractString["200 TYPE completed.","502 Command not implemented: SIZE.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
                @test resp.headers[1:4] == expected_header_first_part
                @test ismatch(expected_header_port, resp.headers[5])
                @test resp.headers[6:end] == expected_header_last_part ||
                    resp.headers[6:end] == [expected_header_last_part..., possible_end_to_headers]
            end

            @testset "ftp_put" begin
                @test !file_exists("/" * non_ssl_test_upload)
                resp = nothing
                open(upload_file) do file
                    rcall = ftp_put(non_ssl_test_upload, file, options)
                    @test typeof(rcall) <: Future
                    resp = fetch(rcall)
                end
                @test file_exists("/" * non_ssl_test_upload)
                @test resp.code == 226
                @test typeof(resp.total_time) == Float64
                @test resp.bytes_recd == 0
                expected_header_last_part = AbstractString["200 TYPE completed.","150 File status okay; about to open data connection.","226 Created file test_upload.txt."]
                @test resp.headers[1:4] == expected_header_first_part
                @test ismatch(expected_header_port, resp.headers[5])
                @test resp.headers[6:end] == expected_header_last_part ||
                    resp.headers[6:end] == [expected_header_last_part..., possible_end_to_headers]
                remove("/" * non_ssl_test_upload)
                @test !file_exists("/" * non_ssl_test_upload)
            end

        end

        @testset "Persistent connection tests, active mode" begin
            options = RequestOptions(blocking=false, ssl=false, active_mode=true, username=user, passwd=pswd, hostname=host)

            @testset "ftp_connect" begin
                rcall = ftp_connect(options)
                @test typeof(rcall) <: Future
                ctxt, resp = fetch(rcall)
                actual_body = readstring(resp.body)
                @test resp.code == 226
                @test typeof(resp.total_time) == Float64
                @test resp.bytes_recd == length(actual_body)
                @test contains(actual_body, file_name)
                @test contains(actual_body, directory_name)
                @test contains(actual_body, byte_file_name)
                @test resp.headers == AbstractString["220 Service ready for new user. (MockFtpServer 2.6; see http://mockftpserver.sourceforge.net)","331 User name okay, need password.","230 User logged in, proceed.","257 \"/\" is current directory.","200 EPRT completed.","200 TYPE completed.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
                @test typeof(ctxt.curl) == Ptr{CURL}
                @test ctxt.url == options.url == "ftp://" * string(host) * "/"
                @test ctxt.options.blocking == options.blocking == false
                ftp_close_connection(ctxt)
            end

            @testset "ftp_get" begin
                rcall = ftp_connect(options)
                ctxt, resp = fetch(rcall)
                rcall = ftp_get(ctxt, file_name)
                @test typeof(rcall) <: Future
                resp = fetch(rcall)
                actual_body = readstring(resp.body)
                @test resp.code == 226
                @test typeof(resp.total_time) == Float64
                @test resp.bytes_recd == file_size == length(actual_body)
                @test actual_body == file_contents
                @test resp.headers == AbstractString["200 EPRT completed.","200 TYPE completed.","502 Command not implemented: SIZE.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
                @test typeof(ctxt.curl) == Ptr{CURL}
                @test ctxt.url == options.url == "ftp://" * string(host) * "/"
                @test ctxt.options.blocking == options.blocking == false
                ftp_close_connection(ctxt)
            end

            @testset "ftp_put" begin
                @test !file_exists("/" * non_ssl_test_upload)
                rcall = ftp_connect(options)
                ctxt, resp = fetch(rcall)
                open(upload_file) do file
                    rcall = ftp_put(ctxt, non_ssl_test_upload, file)
                    @test typeof(rcall) <: Future
                    resp = fetch(rcall)
                end
                @test file_exists("/" * non_ssl_test_upload)
                actual_body = readstring(resp.body)
                @test resp.code == 226
                @test typeof(resp.total_time) == Float64
                @test resp.bytes_recd == length(actual_body) == 0
                @test actual_body == ""
                @test resp.headers == AbstractString["200 EPRT completed.","200 TYPE completed.","150 File status okay; about to open data connection.","226 Created file test_upload.txt."]
                @test typeof(ctxt.curl) == Ptr{CURL}
                @test ctxt.url == options.url == "ftp://" * string(host) * "/"
                @test ctxt.options.blocking == options.blocking == false
                ftp_close_connection(ctxt)
                remove("/" * non_ssl_test_upload)
                @test !file_exists("/" * non_ssl_test_upload)
            end

        end

    end

    @testset "Changed directory and get file" begin

        options = RequestOptions(blocking=false, ssl=false, username=user, passwd=pswd, hostname=host)
        expected_header_port = r"229 Entering Extended Passive Mode \(\|\|\|\d*\|\)"

        rcall = ftp_connect(options)
        @test typeof(rcall) <: Future
        ctxt, resp = fetch(rcall)
        @test resp.code == 226
        actual_body = readstring(resp.body)
        for expected in [directory_name, file_name]
            @test contains(actual_body, expected)
        end

        resp = ftp_command(ctxt, "CWD $directory_name/")
        actual_body = readstring(resp.body)
        @test resp.code == 250
        @test typeof(resp.total_time) == Float64
        @test resp.bytes_recd == length(actual_body) == 0
        @test actual_body == ""
        @test ismatch(expected_header_port, resp.headers[1])
        @test resp.headers[2:end] == AbstractString["250 CWD completed. New directory is /test_directory."]
        @test typeof(ctxt.curl) == Ptr{CURL}
        @test ctxt.url == "ftp://" * string(host) * "/" * directory_name * "/"
        @test ctxt.options.blocking == options.blocking

        rcall = ftp_get(ctxt, file_name2)
        @test typeof(rcall) <: Future
        resp = fetch(rcall)
        actual_body = readstring(resp.body)
        @test resp.code == 226
        @test typeof(resp.total_time) == Float64
        @test resp.bytes_recd == file_size == length(actual_body)
        @test actual_body == file_contents
        @test resp.headers[1:2] == AbstractString["250 CWD completed. New directory is /.","250 CWD completed. New directory is /test_directory."]
        @test ismatch(expected_header_port, resp.headers[3])
        @test resp.headers[4:end] == AbstractString["200 TYPE completed.","502 Command not implemented: SIZE.","150 File status okay; about to open data connection.","226 Closing data connection. Requested file action successful."]
        @test typeof(ctxt.curl) == Ptr{CURL}
        @test ctxt.url == "ftp://" * string(host) * "/" * directory_name * "/"
        @test ctxt.options.blocking == options.blocking

        ftp_close_connection(ctxt)

    end

    ftp_cleanup()
end

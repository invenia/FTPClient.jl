tempfile(upload_file)
tempfile(joinpath(HOMEDIR,download_file))

opts = (
    :hostname => hostname(server),
    :port => port(server),
    :username => username(server),
    :password => password(server),
)

# options = RequestOptions(hostname="127.0.0.1:8000", username="user", passwd="passwd", ssl=false, active_mode=true)
function test_response(resp, body, code, headers)
    @test typeof(resp.total_time) == Float64
    @test resp.code == code
    @test read(resp.body, String) == body
    @test is_headers_equal(resp.headers, headers)
    @test resp.bytes_recd == length(body)
end

function test_response(resp, code, headers, save_path, file_body)
    @test isfile(save_path) == true

    @test typeof(resp.total_time) == Float64
    @test resp.code == code
    @test read(resp.body, String) == ""
    @test read(save_path, String) == file_body
    @test is_headers_equal(resp.headers, headers)
    @test resp.bytes_recd == length(file_body)
end

function test_get(headers, opt)
    local_file = download_file
    server_file = joinpath(HOMEDIR, local_file)
    @test !isfile(local_file)
    resp = ftp_get(opt, local_file)
    @test !isfile(local_file)
    body = read(server_file, String)
    test_response(resp, body, complete_transfer_code, headers)
end

function test_put(headers, opt)
    local_file = upload_file
    server_file = joinpath(HOMEDIR, local_file)

    @test !isfile(server_file)
    resp = copy_and_wait(server_file) do
        r = open(local_file) do fp
            ftp_put(opt, local_file, fp)
        end

        if isa(opt, ConnContext)
            ftp_close_connection(opt) # close the connection so that the server file closes
        end

        return r
    end

    @test isfile(server_file)
    @test read(server_file, String) == read(local_file, String)
    cleanup_file(server_file)

    test_response(resp, "", complete_transfer_code, headers)
end

function test_command(headers, opt)
    resp = ftp_command(opt, "PWD")
    test_response(resp, "", 257, headers)
end

function tests_by_mode(active::Bool)

    options = RequestOptions(; opts..., ssl=false, active_mode=active)
    mode_header = active ? "200 Active data connection established." : "229 Entering extended passive mode (...)."

    headers = [
        "220 pyftpdlib ... ready.",
        "331 Username ok, send password.",
        "230 Login successful.",
        "257 \"/\" is the current directory.",
        mode_header,
        "200 Type set to: Binary.",
        "125 Data connection already open. Transfer starting.||150 File status okay. About to open data connection.",
        "226 Transfer complete.",
    ]
    test_put(headers, options)

    headers = [
        "220 pyftpdlib ... ready.",
        "331 Username ok, send password.",
        "230 Login successful.",
        "257 \"/\" is the current directory.",
        mode_header,
        "200 Type set to: ASCII.",
        "257 \"/\" is the current directory."
    ]
    test_command(headers, options)


    headers = [
        "220 pyftpdlib ... ready.",
        "331 Username ok, send password.",
        "230 Login successful.",
        "257 \"/\" is the current directory.",
        mode_header,
        "200 Type set to: Binary.",
        "213 ...",
        "125 Data connection already open. Transfer starting.||150 File status okay. About to open data connection.",
        "226 Transfer complete.",
    ]
    test_get(headers, options)

    # download a file to a specific path
    headers = [
        "220 pyftpdlib ... ready.",
        "331 Username ok, send password.",
        "230 Login successful.",
        "257 \"/\" is the current directory.",
        mode_header,
        "200 Type set to: Binary.",
        "213 ...",
        "125 Data connection already open. Transfer starting.||150 File status okay. About to open data connection.",
        "226 Transfer complete."
        ]

    save_path = joinpath(pwd(), "test_path.txt")
    @test !isfile(save_path)

    local_file = download_file

    resp = ftp_get(options, local_file, save_path)
    server_file = joinpath(HOMEDIR, local_file)
    body = read(server_file, String)

    test_response(resp, complete_transfer_code, headers, save_path, body)

    rm(save_path)

    # ftp connect
    headers = [
        "220 pyftpdlib ... ready.",
        "331 Username ok, send password.",
        "230 Login successful.",
        "257 \"/\" is the current directory.",
        mode_header,
        "200 Type set to: ASCII.",
        "125 Data connection already open. Transfer starting.||150 File status okay. About to open data connection.",
        "226 Transfer complete.",
    ]

    ctxt, resp = ftp_connect(options)
    directory_name = "test_directory"
    body = read(resp.body, String)
    @test occursin(download_file, body)
    @test occursin(directory_name, body)
    @test resp.bytes_recd == length(body)
    @test resp.code == complete_transfer_code
    @test is_headers_equal(resp.headers, headers)
    @test rstrip(ctxt.url, '/') == string(options.uri) == prefix
    @test ctxt.options == options
    ftp_close_connection(ctxt)


    headers = [
        mode_header,
        "257 \"/\" is the current directory."
    ]
    ctxt, resp = ftp_connect(options)
    test_command(headers, ctxt)

    @test rstrip(ctxt.url, '/') == string(options.uri) == prefix
    @test ctxt.options == options
    ftp_close_connection(ctxt)

    headers = [
        mode_header,
        "200 Type set to: Binary.",
        "213 ...",
        "125 Data connection already open. Transfer starting.||150 File status okay. About to open data connection.",
        "226 Transfer complete.",
    ]
    ctxt, resp = ftp_connect(options)
    test_get(headers, ctxt)

    @test rstrip(ctxt.url, '/') == string(options.uri) == prefix
    @test ctxt.options == options
    ftp_close_connection(ctxt)

    headers = [
        mode_header,
        "200 Type set to: Binary.",
        "125 Data connection already open. Transfer starting.||150 File status okay. About to open data connection.",
        "226 Transfer complete."
        ]

    ctxt, resp = ftp_connect(options)
    test_put(headers, ctxt)

end

@testset "active_mode" begin
    tests_by_mode(true)
    tests_by_mode(false)
end

@testset "binary_ascii" begin
    # test binary vs ascii
    Sys.isunix() && (upload_bytes = string("466F6F426172", "0A", "466F6F426172"))
    Sys.iswindows() && (upload_bytes = string("466F6F426172", "0D0A", "466F6F426172"))

    Sys.isunix() && (download_bytes = string("466F6F426172", "0D0A", "466F6F426172"))
    Sys.isunix() && (download_bytes_ascii = string("466F6F426172", "0A", "0A", "466f6f426172"))
    Sys.iswindows() && (download_bytes = string("466F6F426172", "0A", "466F6F426172", "1A1A1A"))

    byte_upload_file = "test_upload_byte_file"
    byte_file = "test_byte_file"

    open(joinpath(HOMEDIR, byte_file), "w") do fp
        write(fp, hex2bytes(download_bytes))
    end

    # it is not the same file when downloading in ascii mode
    options = RequestOptions(; opts..., ssl=false, active_mode=false)
    resp = ftp_get(options, byte_file; mode=ascii_mode)
    bytes = read(resp.body)
    Sys.isunix() && @test bytes != hex2bytes(download_bytes)
    Sys.isunix() && @test bytes == hex2bytes(download_bytes_ascii)

    # it is the same file when downloading in binary mode
    resp = ftp_get(options, byte_file)
    bytes = read(resp.body)
    @test bytes == hex2bytes(download_bytes)

    # it is not the same file when downloading in ascii mode
    ctxt, resp = ftp_connect(options)
    resp = ftp_get(ctxt, byte_file, mode=ascii_mode)
    bytes = read(resp.body)
    Sys.isunix() && @test bytes != hex2bytes(download_bytes)
    Sys.isunix() && @test bytes == hex2bytes(download_bytes_ascii)
    ftp_close_connection(ctxt)

    # it is the same file when downloading in binary mode
    ctxt, resp = ftp_connect(options)
    resp = ftp_get(ctxt, byte_file)
    bytes = read(resp.body)
    @test bytes == hex2bytes(download_bytes)
    ftp_close_connection(ctxt)

    # it is not the same file when downloading in ascii mode
    ftp = FTP(; opts...)
    buff = download(ftp, byte_file, mode=ascii_mode)
    bytes = read(buff)
    Sys.isunix() && @test bytes != hex2bytes(download_bytes)
    Sys.isunix() && @test bytes == hex2bytes(download_bytes_ascii)
    Base.close(ftp)

    # it is the same file when downloading in binary mode
    ftp = FTP(; opts...)
    buff = download(ftp, byte_file)
    bytes = read(buff)
    @test bytes == hex2bytes(download_bytes)
    Base.close(ftp)

    # binary file download using ftp object, start in ascii, and switch to binary, then back
    ftp = FTP(; opts...)
    buff = download(ftp, byte_file, mode=ascii_mode)
    bytes = read(buff)
    Sys.isunix() && @test bytes != hex2bytes(download_bytes)
    Sys.isunix() && @test bytes == hex2bytes(download_bytes_ascii)
    buff = download(ftp, byte_file)
    bytes = read(buff)
    @test bytes == hex2bytes(download_bytes)
    buff = download(ftp, byte_file, mode=ascii_mode)
    bytes = read(buff)
    Sys.isunix() && @test bytes != hex2bytes(download_bytes)
    Sys.isunix() && @test bytes == hex2bytes(download_bytes_ascii)
    Base.close(ftp)

    # upload
    server_byte_file = joinpath(HOMEDIR, byte_upload_file)
    bin_file = IOBuffer(hex2bytes(upload_bytes))
    copy_and_wait(server_byte_file) do
        ftp_put(options, byte_upload_file, bin_file; mode=binary_mode)
    end
    @test isfile(server_byte_file)
    @test hex2bytes(upload_bytes) == read(server_byte_file)
    cleanup_file(server_byte_file)

    # upload with ctxt
    ctxt, resp = ftp_connect(options)
    bin_file = IOBuffer(hex2bytes(upload_bytes))
    copy_and_wait(server_byte_file) do
        ftp_put(ctxt, byte_upload_file, bin_file)
    end
    @test isfile(server_byte_file)
    @test hex2bytes(upload_bytes) == read(server_byte_file)
    cleanup_file(server_byte_file)
    ftp_close_connection(ctxt)

    # ftpObject upload
    ftp = FTP(; opts...)
    bin_file = IOBuffer(hex2bytes(upload_bytes))
    copy_and_wait(server_byte_file) do
        upload(ftp, bin_file, byte_upload_file)
    end
    @test isfile(server_byte_file)
    @test hex2bytes(upload_bytes) == read(server_byte_file)
    cleanup_file(server_byte_file)
    Base.close(ftp)
end

@testset "ftp errors" begin
    # check ftp errors
    buff = IOBuffer()
    msg = "This will go into the message"
    lib_curl_error = 765
    error = FTPClientError(msg, lib_curl_error)
    showerror(buff, error)
    seekstart(buff)
    @test "$msg :: LibCURL error #$lib_curl_error" == read(buff, String)

    options = RequestOptions(ssl=false, active_mode=false, hostname="not a host", username=username(server), password=password(server))
    @test_throws FTPClientError ftp_connect(options)
end

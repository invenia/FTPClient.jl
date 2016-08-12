function ssl_tests(implicit::Bool = true)
    mode = implicit ? :implicit : :explicit

    setup_server()

    server = FTPServer(security=mode)

    opts = (
        :hostname => hostname(server),
        :username => username(server),
        :password => password(server),
        :ssl => true,
        :implicit => implicit,
        :verify_peer => false,
    )
    try
        options = RequestOptions(; opts..., active_mode=false)
        test_download(options)
        test_upload(options)
        test_cmd(options)

        options = RequestOptions(; opts..., active_mode=true)
        test_download(options)
        test_upload(options)
        test_cmd(options)

        options = RequestOptions(; opts..., active_mode=false)
        ctxt, resp = ftp_connect(options)
        @test resp.code == 226


        test_cmd(ctxt)
        test_download(ctxt)
        test_upload(ctxt)

        options = RequestOptions(; opts..., active_mode=true)
        ctxt, resp = ftp_connect(options)
        @test resp.code == 226

        test_cmd(ctxt)
        test_download(ctxt)
        test_upload(ctxt)

        # the connection has to be closed during test_upload(ctxt) to get the server file to write out
        # ftp_close_connection(ctxt)

    finally
        close(server)
    end
end

function test_download(options::RequestOptions)
    server_path = "test_download.txt"
    resp = ftp_get(options, server_path)
    @test resp.code == 226
    @test readstring(resp.body) == readstring(joinpath(ROOT, server_path))
end

function test_upload(options::RequestOptions)
    client_path = "test_upload.txt"
    local_server_path = joinpath(ROOT, client_path)
    cleanup_file(local_server_path)
    resp = open(client_path) do fp
        ftp_put(options, client_path, fp)
    end
    @test resp.code == 226
    @test readstring(local_server_path) == readstring(client_path)
    rm(local_server_path)
end

function test_cmd(options::RequestOptions)
    resp = ftp_command(options, "PWD")
    @test resp.code == 257
    @test readstring(resp.body) == ""
end

function test_download(ctxt::ConnContext)
    server_path = "test_download.txt"
    resp = ftp_get(ctxt, server_path)
    @test resp.code == 226
    @test readstring(resp.body) == readstring(joinpath(ROOT, server_path))
end

function test_upload(ctxt::ConnContext)
    client_path = "test_upload.txt"
    local_server_path = joinpath(ROOT, client_path)
    resp = open(client_path) do file
        ftp_put(ctxt, client_path, file)
    end
    ftp_close_connection(ctxt)
    @test resp.code ==226
    @test readstring(client_path) == readstring(local_server_path)
    rm(local_server_path)
end

function test_cmd(ctxt::ConnContext)
    resp = ftp_command(ctxt, "PWD")
    @test resp.code == 257
    @test readstring(resp.body) == ""
end

ssl_tests(true)
ssl_tests(false)

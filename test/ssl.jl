

function ssl_tests(implicit::Bool = true)
    mode = implicit ? :implicit : :explicit

    setup_server()

    server = FTPServer(security=mode)
    opts = (
        :hostname => hostname(server),
        :username => username(server),
        :passwd => password(server),
        :ssl => true,
        :implicit => implicit,
        :verify_peer => false,
    )

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

    test_persistent_cmd(ctxt)
    test_persistent_download(ctxt)
    test_persistent_upload(ctxt)

    ftp_close_connection(ctxt)

    options = RequestOptions(; opts..., active_mode=true)
    ctxt, resp = ftp_connect(options)
    @test resp.code == 226

    test_persistent_cmd(ctxt)
    test_persistent_download(ctxt)
    test_persistent_upload(ctxt)

    ftp_close_connection(ctxt)

    close(server)
end

function test_download(options)
    download_file = "test_download.txt"
    resp = ftp_get(download_file, options)
    @test resp.code == 226
    @test readstring(resp.body) == readstring(joinpath(ROOT, download_file))
end

function test_upload(options)
    local_file = "test_upload.txt"
    server_file = joinpath(ROOT, local_file)
    if (isfile(server_file))
        rm(server_file)
    end
    resp = open(local_file) do fp
        ftp_put(local_file, fp, options)
    end
    @test resp.code ==226
    @test readstring(server_file) == readstring(local_file)
    rm(server_file)
end

function test_cmd(options)
    resp = ftp_command("PWD", options)
    @test resp.code == 257
    @test readstring(resp.body) == ""
end

function test_persistent_download(ctxt)
    resp = ftp_command(ctxt, "PWD")
    @test resp.code == 257
    @test readstring(resp.body) == ""
end

function test_persistent_upload(ctxt)
    upload_file = "test_upload.txt"
    resp = open(upload_file) do file
        ftp_put(ctxt, upload_file, file)
    end
    @test resp.code ==226
    @test readstring(upload_file) == readstring(joinpath(ROOT, upload_file))
    rm(joinpath(ROOT, upload_file))
end

function test_persistent_cmd(ctxt)
    resp = ftp_command(ctxt, "PWD")
    @test resp.code == 257
    @test readstring(resp.body) == ""
end

ssl_tests(true)
ssl_tests(false)




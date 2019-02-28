function ssl_tests(implicit::Bool = true)
    mode = implicit ? :implicit : :explicit

    FTPServer.init()

    FTPServer.serve(; security=mode) do server
        opts = (
            :hostname => hostname(server),
            :port => port(server),
            :username => username(server),
            :password => password(server),
            :ssl => true,
            :implicit => implicit,
            :verify_peer => false,
        )

        options = RequestOptions(; opts..., active_mode=false)
        # Test implicit/exlicit ftp ssl scheme is set correctly
        @test options.uri.scheme == (implicit ? "ftps" : "ftpes")
        test_download(options)
        test_upload(options)
        test_cmd(options)

        options = RequestOptions(; opts..., active_mode=true)
        test_download(options)
        test_upload(options)
        test_cmd(options)

        options = RequestOptions(; opts..., active_mode=false)
        ctxt, resp = ftp_connect(options)
        @test resp.code == complete_transfer_code

        test_cmd(ctxt)
        test_download(ctxt)
        test_upload(ctxt)

        options = RequestOptions(; opts..., active_mode=true)
        ctxt, resp = ftp_connect(options)
        @test resp.code == complete_transfer_code

        test_cmd(ctxt)
        test_download(ctxt)
        test_upload(ctxt)
    end
end

function test_download(options::RequestOptions)
    server_path = "test_download.txt"
    resp = ftp_get(options, server_path)
    @test resp.code == complete_transfer_code
    @test read(resp.body, String) == read(joinpath(HOMEDIR, server_path), String)
end

function test_upload(options::RequestOptions)
    client_path = "test_upload.txt"
    local_server_path = joinpath(HOMEDIR, client_path)
    cleanup_file(local_server_path)
    resp = copy_and_wait(local_server_path) do
        open(client_path) do fp
            ftp_put(options, client_path, fp)
        end
    end
    @test resp.code == complete_transfer_code
    @test read(local_server_path, String) == read(client_path, String)
    rm(local_server_path)
end

function test_cmd(options::RequestOptions)
    resp = ftp_command(options, "PWD")
    @test resp.code == 257
    @test read(resp.body, String) == ""
end

function test_download(ctxt::ConnContext)
    server_path = "test_download.txt"
    resp = ftp_get(ctxt, server_path)
    @test resp.code == complete_transfer_code
    @test read(resp.body, String) == read(joinpath(HOMEDIR, server_path), String)
end

function test_upload(ctxt::ConnContext)
    client_path = "test_upload.txt"
    local_server_path = joinpath(HOMEDIR, client_path)
    resp = copy_and_wait(local_server_path) do
        open(client_path) do file
            ftp_put(ctxt, client_path, file)
        end
    end
    ftp_close_connection(ctxt)
    @test resp.code == complete_transfer_code
    @test read(client_path, String) == read(local_server_path, String)
    rm(local_server_path)
end

function test_cmd(ctxt::ConnContext)
    resp = ftp_command(ctxt, "PWD")
    @test resp.code == 257
    @test read(resp.body, String) == ""
end

@testset "ssl" begin
    ssl_tests(true)
    ssl_tests(false)
end

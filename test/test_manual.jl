ftp_init()

@testset "Non-persistent connection tests using ssl=$test_ssl, implicit=$test_implicit, active_mode=$test_active_mode" begin
    options = RequestOptions(ssl=test_ssl, implicit=test_implicit, active_mode=test_active_mode, verify_peer=false, username=user, passwd=pswd, hostname=host)

    resp = ftp_get(file_name, options)
    @test resp.code == 226

    open(upload_file_name) do file
        resp = ftp_put("test_upload.txt", file, options)
        @test resp.code == 226
    end

    resp = ftp_command("PWD", options)
    @test resp.code == 257
end

@testset "Persistent connection tests using ssl=$test_ssl, implicit=$test_implicit, active_mode=$test_active_mode" begin
    options = RequestOptions(ssl=test_ssl, implicit=test_implicit, active_mode=test_active_mode, verify_peer=false, username=user, passwd=pswd, hostname=host)

    ctxt, resp = ftp_connect(options)
    @test resp.code == 226

    resp = ftp_command(ctxt, "PWD")
    @test resp.code == 257

    resp = ftp_get(ctxt, file_name)
    @test resp.code == 226


    open(upload_file_name) do file
        resp = ftp_put(ctxt, "test_upload.txt", file)
        @test resp.code == 226
    end

    ftp_close_connection(ctxt)
end

ftp_cleanup()

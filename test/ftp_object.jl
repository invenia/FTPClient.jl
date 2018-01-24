mv_file = "test_mv.txt"
tempfile(mv_file)

global retry_server = nothing

opts = (
    :hostname => hostname(server),
    :username => username(server),
    :password => password(server),
    :ssl => false,
)

function no_unexpected_changes(ftp::FTP, hostname::AbstractString=hostname(server))
    other = FTP(; opts...)
    @test ftp.ctxt.options == other.ctxt.options
    @test ftp.ctxt.url == "ftp://$hostname/"
    close(other)
end

function expected_output(active::Bool)
    mode = active ? "active" : "passive"
    expected = """
        Host:      ftp://$(hostname(server))/
        User:      $(username(server))
        Transfer:  $mode mode
        Security:  None

        """

    buff = IOBuffer()
    ftp = FTP(; opts..., active_mode=active)
    println(buff, ftp)
    seekstart(buff)
    @test readstring(buff) == expected
    close(ftp)
end

# Function that will bring up the server after a few retries, and returns
# connection details that over ride the previously defined wrong connection.
# Used for testing upload with retries.
function retry_test(count, options)

    # Fail on the first attempt
    if count == 1
        return (true, options)
    # Bring up the FTP and return connection options to it on the second attempt
    # So the second attempt should succeed.
    elseif count == 2
        global retry_server = FTP(; opts...)
        return (true, retry_server.ctxt)
    else
        # Try and prevent infinite loops with this, but should never be an issue.
        return (false, options)
    end
end

@testset "conn error" begin
    # check connection error
    @test_throws FTPClientError FTP(hostname="not a host", username=username(server), password=password(server), ssl=false)
end

@testset "object" begin
    # check object
    ftp = FTP(; opts...)
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "connection with url" begin
    host = hostname(server)
    ftp = FTP(; url="ftp://$host/", opts...)
    @test ftp.ctxt.url == "ftp://$host/"
    close(ftp)
end

@testset "readdir" begin
    # check readdir
    ftp = FTP(; opts...)
    server_dir = readdir(ftp)
    @test contains(string(server_dir), "test_directory")
    @test contains(string(server_dir), "test_download.txt")
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "download" begin
    # check download to buffer
    ftp = FTP(; opts...)
    buffer = download(ftp, download_file)
    @test readstring(buffer) == readstring(joinpath(ROOT,download_file))
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "upload" begin
    # check upload
    ftp = FTP(; opts...)
    local_file = upload_file
    server_file = joinpath(ROOT, local_file)
    tempfile(local_file)
    @test isfile(local_file)
    resp = upload(ftp, local_file)
    @test isfile(server_file)
    @test readstring(server_file) == readstring(local_file)

    no_unexpected_changes(ftp)
    close(ftp)
    cleanup_file(server_file)
end

@testset "mkdir" begin
    # check mkdir
    ftp = FTP(; opts...)
    server_dir = joinpath(ROOT, testdir)
    cleanup_dir(server_dir)
    @test !isdir(server_dir)

    resp = mkdir(ftp, testdir)
    @test isdir(server_dir)
    no_unexpected_changes(ftp)
    cleanup_dir(server_dir)
    close(ftp)

    # check mkdir error
    ftp = FTP(; opts...)
    @test !isdir(server_dir)
    mkdir(server_dir)
    @test isdir(server_dir)
    @test_throws FTPClientError mkdir(ftp, testdir)
    @test isdir(server_dir)
    no_unexpected_changes(ftp)
    cleanup_dir(server_dir)
    close(ftp)

    # check bad directory error
    ftp = FTP(; opts...)
    @test_throws FTPClientError mkdir(ftp, "")
    close(ftp)
end

@testset "cd" begin
    server_dir = joinpath(ROOT, testdir)

    host = hostname(server)
    # check cd
    ftp = FTP(; opts...)
    mkdir(server_dir)
    cd(ftp, testdir)
    no_unexpected_changes(ftp, "$host/$testdir")
    cleanup_dir(server_dir)
    close(ftp)

    # check cd error
    ftp = FTP(; opts...)
    @test !isdir(server_dir)
    ftp = FTP(; opts...)
    @test_throws FTPClientError cd(ftp, testdir)
    no_unexpected_changes(ftp)
    @test !isdir(server_dir)
    close(ftp)

    # check cd path
    ftp = FTP(; opts...)
    mkdir(server_dir)
    @test isdir(server_dir)
    cd(ftp, testdir)
    cd(ftp, "..")
    no_unexpected_changes(ftp, "$host/$testdir/..")
    cleanup_dir(server_dir)
    close(ftp)
end

@testset "rmdir" begin
    server_dir = joinpath(ROOT, testdir)

    # check rmdir
    ftp = FTP(; opts...)
    mkdir(server_dir)
    @test isdir(server_dir)
    rmdir(ftp, testdir)
    @test !isdir(server_dir)
    no_unexpected_changes(ftp)
    close(ftp)

    # check rmdir error
    ftp = FTP(; opts...)
    @test !isdir(server_dir)
    @test_throws FTPClientError rmdir(ftp, testdir)
    @test !isdir(server_dir)
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "pwd" begin
    # check pwd
    ftp = FTP(; opts...)
    @test pwd(ftp) == "/"
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "mv" begin
    # check mv
    ftp = FTP(; opts...)
    new_file = "test_mv2.txt"
    server_file = joinpath(ROOT, mv_file)
    cp(mv_file, server_file)

    server_new_file = joinpath(ROOT, new_file)
    @test isfile(server_file)

    mv(ftp, mv_file, new_file)
    @test !isfile(server_file)
    @test isfile(server_new_file)
    @test readstring(server_new_file) == readstring(mv_file)
    no_unexpected_changes(ftp)
    close(ftp)

    # check mv error
    ftp = FTP(; opts...)
    @test_throws FTPClientError mv(ftp, "", "")
    close(ftp)


    # check mv error 2
    ftp = FTP(; opts...)
    @test_throws FTPClientError mv(ftp, download_file, "")
    close(ftp)
end

@testset "rm" begin
    server_file = joinpath(ROOT, mv_file)

    # check rm
    ftp = FTP(; opts...)
    cp(mv_file, server_file)
    @test isfile(server_file)
    rm(ftp, mv_file)
    @test !isfile(server_file)
    no_unexpected_changes(ftp)
    close(ftp)

    # check rm error
    ftp = FTP(; opts...)
    @test !isfile(server_file)
    @test_throws FTPClientError rm(ftp, mv_file)
    @test !isfile(server_file)
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "upload" begin
    # check upload
    ftp = FTP(; opts...)
    server_file = joinpath(ROOT, upload_file)
    @test isfile(upload_file)
    @test !isfile(server_file)
    resp = upload(ftp, upload_file)

    @test isfile(server_file)
    @test readstring(server_file) == readstring(upload_file)
    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    # check upload to named file
    ftp = FTP(; opts...)
    server_file= joinpath(ROOT, "some name")
    @test !isfile(server_file)
    resp = upload(ftp, upload_file, "some name")
    @test isfile(server_file)
    @test readstring(server_file) == readstring(upload_file)
    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    # Check upload with retry, single file
    ftp = FTP(; opts...)
    server_file= joinpath(ROOT, "test_upload.txt")
    @test !isfile(server_file)
    resp = upload(ftp, [upload_file], "/")
    @test resp == [true]
    @test isfile(server_file)
    @test readstring(server_file) == readstring(upload_file)
    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    # Check upload with retry, multiple files
    ftp = FTP(; opts...)
    upload_list = [upload_file, upload_file_2, upload_file_3, upload_file_4]

    server_file = joinpath(ROOT, "test_upload.txt")
    @test !isfile(server_file)
    server_file_2 = joinpath(ROOT, "test_upload_2.txt")
    @test !isfile(server_file_2)
    server_file_3 = joinpath(ROOT, "test_upload_3.txt")
    @test !isfile(server_file_3)
    server_file_4 = joinpath(ROOT, "test_upload_4.txt")
    @test !isfile(server_file_4)

    resp = upload(ftp, upload_list, "/")
    @test resp == [true, true, true, true]

    @test isfile(server_file)
    @test readstring(server_file) == readstring(upload_file)

    @test isfile(server_file_2)
    @test readstring(server_file_2) == readstring(upload_file_2)

    @test isfile(server_file_3)
    @test readstring(server_file_3) == readstring(upload_file_3)

    @test isfile(server_file_4)
    @test readstring(server_file_4) == readstring(upload_file_4)

    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    cleanup_file(server_file_2)
    cleanup_file(server_file_3)
    cleanup_file(server_file_4)

    close(ftp)

    # Check upload with retry, multiple files, where it will fail the first time
    # Get the FTP object
    ftp = FTP(; opts...)
    # Close the FTP so we can't connect to it
    close(ftp)

    upload_list = [upload_file, upload_file_2, upload_file_3, upload_file_4]

    server_file = joinpath(ROOT, "test_upload.txt")
    @test !isfile(server_file)
    server_file_2 = joinpath(ROOT, "test_upload_2.txt")
    @test !isfile(server_file_2)
    server_file_3 = joinpath(ROOT, "test_upload_3.txt")
    @test !isfile(server_file_3)
    server_file_4 = joinpath(ROOT, "test_upload_4.txt")
    @test !isfile(server_file_4)

    # When this function is first called, ftp should not be functioning
    # It should wait for 1 retry, then create a server and put the details in the
    # retry_server variable, and use that to transfer the files.
    resp = upload(ftp, upload_list, "/", retry_callback=retry_test, retry_wait_seconds=1)
    @test resp == [true, true, true, true]

    @test isfile(server_file)
    @test readstring(server_file) == readstring(upload_file)

    @test isfile(server_file_2)
    @test readstring(server_file_2) == readstring(upload_file_2)

    @test isfile(server_file_3)
    @test readstring(server_file_3) == readstring(upload_file_3)

    @test isfile(server_file_4)
    @test readstring(server_file_4) == readstring(upload_file_4)


    no_unexpected_changes(retry_server)
    cleanup_file(server_file)
    cleanup_file(server_file_2)
    cleanup_file(server_file_3)
    cleanup_file(server_file_4)

    close(retry_server)
end

@testset "write" begin
    # check write to file
    ftp = FTP(; opts...)
    server_file= joinpath(ROOT, "some other name")
    @test !isfile(server_file)
    open(upload_file) do fp
        resp = upload(ftp, fp, "some other name")
    end
    @test isfile(server_file)
    @test readstring(server_file) == readstring(upload_file)
    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    #check for expected output
    expected_output(true)

    expected_output(false)

    cleanup_file(mv_file)
end


@testset "verbose" begin

    function test_captured_ouput(test::Function)
        file_name = tempname()
        ftp_init()
        try
            open(file_name, "w") do verbose_file
                test(verbose_file)
            end
            @test length(read(file_name)) > 0
        finally
            rm(file_name)
            ftp_cleanup()
        end
    end

    @testset "FTP" begin
        test_captured_ouput() do verbose_file
            FTP(; opts..., verbose=verbose_file)
        end
    end

    @testset "readdir" begin
        ftp = FTP(; opts...)
        test_captured_ouput() do verbose_file
            readdir(ftp; verbose=verbose_file)
        end
        close(ftp)
    end

    @testset "download" begin
        ftp = FTP(; opts...)
        buffer = nothing
        test_captured_ouput() do verbose_file
            buffer = download(ftp, download_file; verbose=verbose_file)
        end
        @test readstring(buffer) == readstring(joinpath(ROOT,download_file))
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "upload" begin
        ftp = FTP(; opts...)
        local_file = upload_file
        server_file = joinpath(ROOT, local_file)
        tempfile(local_file)
        @test isfile(local_file)
        @test !isfile(server_file)
        test_captured_ouput() do verbose_file
            upload(ftp, upload_file; verbose=verbose_file)
        end
        @test isfile(server_file)
        @test readstring(server_file) == readstring(local_file)

        no_unexpected_changes(ftp)
        close(ftp)
        cleanup_file(server_file)
    end

    @testset "mkdir" begin
        ftp = FTP(; opts...)
        server_dir = joinpath(ROOT, testdir)
        cleanup_dir(server_dir)
        @test !isdir(server_dir)

        test_captured_ouput() do verbose_file
            resp = mkdir(ftp, testdir; verbose=verbose_file)
        end
        @test isdir(server_dir)
        no_unexpected_changes(ftp)
        cleanup_dir(server_dir)
        close(ftp)
    end

    @testset "cd" begin
        server_dir = joinpath(ROOT, testdir)
        host = hostname(server)

        ftp = FTP(; opts...)
        mkdir(server_dir)
        test_captured_ouput() do verbose_file
            cd(ftp, testdir; verbose=verbose_file)
        end
        no_unexpected_changes(ftp, "$host/$testdir")
        cleanup_dir(server_dir)
        close(ftp)
    end

    @testset "rmdir" begin
        server_dir = joinpath(ROOT, testdir)

        ftp = FTP(; opts...)
        mkdir(server_dir)
        @test isdir(server_dir)
        test_captured_ouput() do verbose_file
            rmdir(ftp, testdir; verbose=verbose_file)
        end
        @test !isdir(server_dir)
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "pwd" begin
        ftp = FTP(; opts...)
        path = nothing
        test_captured_ouput() do verbose_file
            path = pwd(ftp; verbose=verbose_file)
        end
        @test path == "/"
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "mv" begin
        ftp = FTP(; opts...)
        new_file = "test_mv2.txt"
        tempfile(mv_file)
        @test isfile(mv_file)
        server_file = joinpath(ROOT, mv_file)
        cp(mv_file, server_file)

        server_new_file = joinpath(ROOT, new_file)
        @test isfile(server_file)

        test_captured_ouput() do verbose_file
            mv(ftp, mv_file, new_file; verbose=verbose_file)
        end
        @test !isfile(server_file)
        @test isfile(server_new_file)
        @test readstring(server_new_file) == readstring(mv_file)
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "rm" begin
        server_file = joinpath(ROOT, mv_file)

        ftp = FTP(; opts...)
        @test isfile(mv_file)
        cp(mv_file, server_file)
        @test isfile(server_file)
        test_captured_ouput() do verbose_file
            rm(ftp, mv_file; verbose=verbose_file)
        end
        @test !isfile(server_file)
        no_unexpected_changes(ftp)
        close(ftp)

        cleanup_file(mv_file)
    end

    @testset "upload" begin
        @testset "uploading a file with only the local file name" begin
            ftp = FTP(; opts...)
            server_file = joinpath(ROOT, upload_file)
            @test isfile(upload_file)
            @test !isfile(server_file)
            test_captured_ouput() do verbose_file
                resp = upload(ftp, upload_file; verbose=verbose_file)
            end

            @test isfile(server_file)
            @test readstring(server_file) == readstring(upload_file)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
        @testset "uploading a file with remote local file name" begin
            ftp = FTP(; opts...)
            server_file= joinpath(ROOT, "some name")
            @test !isfile(server_file)
            test_captured_ouput() do verbose_file
                resp = upload(ftp, upload_file, "some name"; verbose=verbose_file)
            end
            @test isfile(server_file)
            @test readstring(server_file) == readstring(upload_file)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
        @testset "upload with retry single file" begin
            ftp = FTP(; opts...)
            server_file= joinpath(ROOT, "test_upload.txt")
            @test !isfile(server_file)
            test_captured_ouput() do verbose_file
                resp = upload(ftp, [upload_file], "/"; verbose=verbose_file)
                @test resp == [true]
            end
            @test isfile(server_file)
            @test readstring(server_file) == readstring(upload_file)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
    end


    @testset "verbose twice" begin
        ftp = FTP(; opts...)
        test_captured_ouput() do verbose_file
            buff = download(ftp, download_file; verbose=verbose_file)
            first_length = length(read(verbose_file.name[7:end-1]))
            @test first_length > 0
            path = pwd(ftp; verbose=verbose_file)
            second_length = length(read(verbose_file.name[7:end-1]))
            @test second_length > first_length
        end
        test_captured_ouput() do verbose_file
            path = pwd(ftp; verbose=verbose_file)
            first_length = length(read(verbose_file.name[7:end-1]))
            @test first_length > 0
            buff = download(ftp, download_file; verbose=verbose_file)
            path = pwd(ftp; verbose=verbose_file)
            second_length = length(read(verbose_file.name[7:end-1]))
            @test second_length > first_length
        end
    end

    @testset "ftp open do end" begin
        test_captured_ouput() do verbose_file
            ftp(; opts..., verbose=verbose_file) do ftp
            end
        end
    end

end
 # check do (doesn't work)
  # ftp(ssl=false, user=user, pswd=pswd, host=host) do f
  # buff = download(f, file_name)
  # @test readstring(buff) == file_contents
  # no_unexpected_changes(f)
  # end


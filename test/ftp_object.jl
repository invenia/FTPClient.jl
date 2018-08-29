mv_file = "test_mv.txt"
tempfile(mv_file)

global retry_server = nothing

opts = (
    :hostname => hostname(server),
    :port => port(server),
    :username => username(server),
    :password => password(server),
    :ssl => false,
)


function no_unexpected_changes(ftp::FTP, url::AbstractString=FTPClient.trailing(prefix, '/'))
    other = FTP(; opts...)
    @test ftp.ctxt.options == other.ctxt.options
    @test ftp.ctxt.url == url
    close(other)
end

function expected_output(active::Bool)
    mode = active ? "active" : "passive"
    expected = """
        URL:       $(FTPClient.safe_uri(prefix))
        Transfer:  $mode mode
        Security:  none
        """

    buff = IOBuffer()
    ftp = FTP(; opts..., active_mode=active)
    println(buff, ftp)
    seekstart(buff)
    @test read(buff, String) == expected
    close(ftp)
end

function copy_and_wait(f::Function, files...; timeout=30)
    # Writing/uploading FTP files can have concurrency issues so we repeatedly
    # try and read the destination file until we have data.
    resp = f()

    for f in files
        file_data = ""
        attempts = 1

        while attempts < timeout
            if isfile(f) && !isempty(read(f, String))
                break
            end

            sleep(1)
            attempts += 1
        end
    end

    return resp
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
    url = string(
        "ftp://",
        username(server),
        ":",
        password(server),
        "@",
        hostname(server),
        ":",
        port(server),
        "/",
    )

    ftp = FTP(url)
    @test ftp.ctxt.url == url
    close(ftp)
end

@testset "readdir" begin
    # check readdir
    ftp = FTP(; opts...)
    server_dir = readdir(ftp)
    @test occursin("test_directory", string(server_dir))
    @test occursin("test_download.txt", string(server_dir))
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "download" begin
    # check download to buffer
    ftp = FTP(; opts...)
    buffer = download(ftp, download_file)
    @test read(buffer, String) == read(joinpath(ROOT, download_file), String)
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

    resp = copy_and_wait(server_file) do
        upload(ftp, local_file)
    end
    @test isfile(server_file)
    @test read(local_file, String) == read(server_file, String)

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

    # check cd
    ftp = FTP(; opts...)
    mkdir(server_dir)
    cd(ftp, testdir)
    no_unexpected_changes(ftp, "$prefix/$testdir/")
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
    no_unexpected_changes(ftp, "$prefix/$testdir/../")
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
    @test read(server_new_file, String) == read(mv_file, String)
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

    resp = copy_and_wait(server_file) do
        upload(ftp, upload_file)
    end
    @test isfile(server_file)
    @test read(upload_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    # check upload to named file
    ftp = FTP(; opts...)
    server_file= joinpath(ROOT, "some name")
    @test !isfile(server_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, upload_file, "some name")
    end
    @test isfile(server_file)
    @test read(upload_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    # Check upload with retry, single file
    ftp = FTP(; opts...)
    server_file= joinpath(ROOT, "test_upload.txt")
    @test !isfile(server_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, [upload_file], "/")
    end

    @test resp == [true]
    @test isfile(server_file)
    @test read(upload_file, String) == read(server_file, String)

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

    server_list = [server_file, server_file_2, server_file_3, server_file_4]

    resp = copy_and_wait(server_list...) do
        upload(ftp, upload_list, "/")
    end

    @test resp == [true, true, true, true]

    for (ufile, sfile) in zip(upload_list, server_list)
        @test isfile(sfile)
        @test read(ufile, String) == read(sfile, String)
    end

    no_unexpected_changes(ftp)
    map(cleanup_file, server_list)
    close(ftp)

    # Check upload with retry, multiple files, where it will fail the first time
    # Get the FTP object
    ftp = FTP(; opts...)
    # Close the FTP so we can't connect to it
    close(ftp)

    # When this function is first called, ftp should not be functioning
    # It should wait for 1 retry, then create a server and put the details in the
    # retry_server variable, and use that to transfer the files.
    resp = copy_and_wait(server_list...) do
        upload(ftp, upload_list, "/", retry_callback=retry_test, retry_wait_seconds=1)
    end

    @test resp == [true, true, true, true]

    for (ufile, sfile) in zip(upload_list, server_list)
        @test isfile(sfile)
        @test read(ufile, String) == read(sfile, String)
    end

    no_unexpected_changes(retry_server)
    map(cleanup_file, server_list)

    close(retry_server)
end

@testset "write" begin
    # check write to file
    ftp = FTP(; opts...)
    server_file= joinpath(ROOT, "some other name")
    @test !isfile(server_file)
    resp = copy_and_wait(server_file) do
        open(upload_file) do fp
            resp = upload(ftp, fp, "some other name")
        end
    end

    @test isfile(server_file)
    @test read(upload_file, String) == read(server_file, String)
    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    #check for expected output
    expected_output(true)

    expected_output(false)

    cleanup_file(mv_file)
end


@testset "verbose" begin

    function test_captured_ouput(func::Function)
        temp_file_path, io = mktemp()
        ftp_init()
        try
            func(io)
            close(io)
            @test filesize(temp_file_path) > 0
        finally
            close(io)
            isfile(temp_file_path) && rm(temp_file_path)
            ftp_cleanup()
        end
    end

    @testset "FTP" begin
        test_captured_ouput() do io
            FTP(; opts..., verbose=io)
        end
    end

    @testset "readdir" begin
        ftp = FTP(; opts...)
        test_captured_ouput() do io
            readdir(ftp; verbose=io)
        end
        close(ftp)
    end

    @testset "download" begin
        ftp = FTP(; opts...)
        buffer = nothing
        test_captured_ouput() do io
            buffer = download(ftp, download_file; verbose=io)
        end
        @test read(buffer, String) == read(joinpath(ROOT, download_file), String)
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

        copy_and_wait(server_file) do
            test_captured_ouput() do io
                upload(ftp, upload_file; verbose=io)
            end
        end
        @test isfile(server_file)
        @test read(upload_file, String) == read(server_file, String)

        no_unexpected_changes(ftp)
        close(ftp)
        cleanup_file(server_file)
    end

    @testset "mkdir" begin
        ftp = FTP(; opts...)
        server_dir = joinpath(ROOT, testdir)
        cleanup_dir(server_dir)
        @test !isdir(server_dir)

        test_captured_ouput() do io
            resp = mkdir(ftp, testdir; verbose=io)
        end
        @test isdir(server_dir)
        no_unexpected_changes(ftp)
        cleanup_dir(server_dir)
        close(ftp)
    end

    @testset "cd" begin
        server_dir = joinpath(ROOT, testdir)

        ftp = FTP(; opts...)
        mkdir(server_dir)
        test_captured_ouput() do io
            cd(ftp, testdir; verbose=io)
        end
        no_unexpected_changes(ftp, "$prefix/$testdir/")
        cleanup_dir(server_dir)
        close(ftp)
    end

    @testset "rmdir" begin
        server_dir = joinpath(ROOT, testdir)

        ftp = FTP(; opts...)
        mkdir(server_dir)
        @test isdir(server_dir)
        test_captured_ouput() do io
            rmdir(ftp, testdir; verbose=io)
        end
        @test !isdir(server_dir)
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "pwd" begin
        ftp = FTP(; opts...)
        test_captured_ouput() do io
            dir = pwd(ftp; verbose=io)
            @test dir == "/"
        end
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
        @test isfile(server_file)

        server_new_file = joinpath(ROOT, new_file)
        # remove the new file if it already exists
        # on windows trying to overwrite the file will cause an error to be thrown
        isfile(server_new_file) && rm(server_new_file)

        test_captured_ouput() do io
            mv(ftp, mv_file, new_file; verbose=io)
        end

        @test !isfile(server_file)
        @test isfile(server_new_file)
        @test read(server_new_file, String) == read(mv_file, String)
        no_unexpected_changes(ftp)
        close(ftp)

        cleanup_file(server_new_file)
        cleanup_file(mv_file)
    end

    @testset "rm" begin
        ftp = FTP(; opts...)

        tempfile(mv_file)
        @test isfile(mv_file)

        server_file = joinpath(ROOT, mv_file)

        @test isfile(mv_file)

        !isfile(server_file) && cp(mv_file, server_file)
        @test isfile(server_file)

        test_captured_ouput() do io
            rm(ftp, mv_file; verbose=io)
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
            copy_and_wait(server_file) do
                test_captured_ouput() do io
                    resp = upload(ftp, upload_file; verbose=io)
                end
            end

            @test isfile(server_file)
            @test read(upload_file, String) == read(server_file, String)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
        @testset "uploading a file with remote local file name" begin
            ftp = FTP(; opts...)
            server_file= joinpath(ROOT, "some name")
            @test !isfile(server_file)
            copy_and_wait(server_file) do
                test_captured_ouput() do io
                    resp = upload(ftp, upload_file, "some name"; verbose=io)
                end
            end
            @test isfile(server_file)
            @test read(upload_file, String) == read(server_file, String)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
        @testset "upload with retry single file" begin
            ftp = FTP(; opts...)
            server_file= joinpath(ROOT, "test_upload.txt")
            @test !isfile(server_file)
            copy_and_wait(server_file) do
                test_captured_ouput() do io
                    resp = upload(ftp, [upload_file], "/"; verbose=io)
                    @test resp == [true]
                end
            end
            @test isfile(server_file)
            @test read(upload_file, String) == read(server_file, String)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
    end

    @testset "verbose multiple commands" begin
        ftp = FTP(; opts...)
        @testset "two commands" begin
            test_captured_ouput() do io
                path = pwd(ftp; verbose=io)
                first_pos = position(io)
                @test first_pos > 0

                path = pwd(ftp; verbose=io)
                second_pos = position(io)
                @test second_pos == first_pos * 2
            end
        end
        @testset "mix verbose and non-verbose calls" begin
            test_captured_ouput() do io
                path = pwd(ftp; verbose=io)
                first_pos = position(io)
                @test first_pos > 0

                path = pwd(ftp)

                path = pwd(ftp; verbose=io)
                second_pos = position(io)
                @test second_pos == first_pos * 2
            end
        end
        @testset "write to stream between FTP commands" begin
            test_captured_ouput() do io
                path = pwd(ftp; verbose=io)
                first_pos = position(io)
                @test first_pos > 0

                str = "ABC"
                write(io, str)
                @test position(io) == first_pos + length(str)

                path = pwd(ftp; verbose=io)
                second_pos = position(io)
                @test second_pos == first_pos * 2 + length(str)
            end
        end
    end

    @testset "ftp open do end" begin
        test_captured_ouput() do io
            ftp(; opts..., verbose=io) do ftp
            end
        end
    end

end
 # check do (doesn't work)
  # ftp(ssl=false, user=user, pswd=pswd, host=host) do f
  # buff = download(f, file_name)
  # @test read(buff, String) == file_contents
  # no_unexpected_changes(f)
  # end

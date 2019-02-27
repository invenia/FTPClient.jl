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

function copy_and_wait(func::Function, files...; timeout=30)
    # Writing/uploading FTP files can have concurrency issues so we repeatedly
    # try and read the destination file until we have data.
    resp = func()

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


@testset "connection error" begin
    # Note: Creating the FTP instance will not actually establish a connection. A connection
    # will only occur upon the first command executed which requires remote access.
    ftp = FTP(hostname="not a host", username=username(server), password=password(server), ssl=false)
    @test_throws FTPClientError pwd(ftp)
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
    @test "test_directory" in server_dir
    @test "test_download.txt" in server_dir
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "download" begin
    # check download to buffer
    ftp = FTP(; opts...)
    buffer = download(ftp, download_file)
    @test read(buffer, String) == read(joinpath(HOMEDIR, download_file), String)
    no_unexpected_changes(ftp)
    close(ftp)
end

@testset "upload" begin
    # check upload "." dot path
    ftp = FTP(; opts...)
    local_file = upload_file
    server_file = joinpath(HOMEDIR, local_file)
    tempfile(local_file)
    @test isfile(local_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, local_file, ".")
    end
    @test isfile(server_file)
    @test read(local_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    close(ftp)
    cleanup_file(server_file)

    # Check dir + "." dot path
    ftp = FTP(; opts...)
    local_file = upload_file
    server_dir = joinpath(HOMEDIR, testdir)
    mkdir(ftp, testdir)
    server_file = joinpath(server_dir, local_file)
    tempfile(local_file)
    @test isfile(local_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, local_file, "$testdir/.")
    end
    @test isfile(server_file)
    @test read(local_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    close(ftp)
    cleanup_file(server_file)
    cleanup_dir(server_dir)

    # Check dir + ".." dot path
    testdir2 = "double_test"
    ftp = FTP(; opts...)
    local_file = upload_file
    server_dir = joinpath(HOMEDIR, testdir)
    mkdir(ftp, testdir)
    mkdir(ftp, joinpath(testdir, testdir2))
    server_file = joinpath(server_dir, local_file)
    tempfile(local_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, local_file, "$testdir/$testdir2/..")
    end
    @test isfile(server_file)
    @test read(local_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    close(ftp)
    cleanup_file(server_file)
    cleanup_dir(joinpath(server_dir, testdir2))
    cleanup_dir(server_dir)

    # check upload "/" slash path
    ftp = FTP(; opts...)
    local_file = upload_file
    server_dir = joinpath(HOMEDIR, testdir)
    mkdir(ftp, testdir)
    server_file = joinpath(server_dir, local_file)
    tempfile(local_file)
    @test isfile(local_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, local_file, "$testdir/")
    end
    @test isfile(server_file)
    @test read(local_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    close(ftp)
    cleanup_file(server_file)
    cleanup_dir(server_dir)

    # check upload full remote path
    ftp = FTP(; opts...)
    local_file = upload_file
    server_file = joinpath(HOMEDIR, local_file)
    tempfile(local_file)
    @test isfile(local_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, local_file, local_file)
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
    server_dir = joinpath(HOMEDIR, testdir)
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
    server_dir = joinpath(HOMEDIR, testdir)

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
    server_dir = joinpath(HOMEDIR, testdir)

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
    server_file = joinpath(HOMEDIR, mv_file)
    cp(mv_file, server_file)

    server_new_file = joinpath(HOMEDIR, new_file)
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
    server_file = joinpath(HOMEDIR, mv_file)

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
    server_file = joinpath(HOMEDIR, upload_file)
    @test isfile(upload_file)
    @test !isfile(server_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, upload_file, upload_file)
    end
    @test isfile(server_file)
    @test read(upload_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    # check upload to named file
    ftp = FTP(; opts...)
    server_file= joinpath(HOMEDIR, "some name")
    @test !isfile(server_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, upload_file, "some name")
    end
    @test isfile(server_file)
    @test read(upload_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    ftp = FTP(; opts...)
    server_file= joinpath(HOMEDIR, "test_upload.txt")
    @test !isfile(server_file)

    resp = copy_and_wait(server_file) do
        upload(ftp, upload_file, "/")
    end

    @test resp.code == complete_transfer_code
    @test isfile(server_file)
    @test read(upload_file, String) == read(server_file, String)

    no_unexpected_changes(ftp)
    cleanup_file(server_file)
    close(ftp)

    # Check upload with retry, single file
    # Get the FTP object
    ftp = FTP(; opts...)
    # Close the FTP so we can't connect to it
    close(ftp)

    # This will run twice, and fail both times. I currently don't know a good way to test
    # this strategy where the ftp client comes back up between trys.
    retry_ftp = retry(delays=fill(0.1, 2)) do
        upload(ftp, upload_file, "/")
    end
    @test_throws FTPClientError retry_ftp()
end

@testset "write" begin
    # check write to file
    ftp = FTP(; opts...)
    server_file = joinpath(HOMEDIR, "some other name")
    @test !isfile(server_file)
    resp = copy_and_wait(server_file) do
        open(upload_file) do fp
            upload(ftp, fp, "some other name")
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

    function captured_size(func::Function)
        temp_file_path, io = mktemp()
        ftp_init()
        try
            func(io)
            flush(io)
            return filesize(temp_file_path)
        finally
            close(io)
            isfile(temp_file_path) && rm(temp_file_path)
            ftp_cleanup()
        end

        return nothing
    end

    @testset "FTP" begin
        num_bytes = captured_size() do io
            FTP(; opts..., verbose=io)
        end
        @test num_bytes == 0
    end

    @testset "readdir" begin
        local ftp
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            readdir(ftp)
        end
        @test num_bytes > 0
        close(ftp)
    end

    @testset "download" begin
        local ftp, buffer
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            buffer = download(ftp, download_file)
        end
        @test num_bytes > 0
        @test read(buffer, String) == read(joinpath(HOMEDIR, download_file), String)
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "upload" begin
        local_file = upload_file
        server_file = joinpath(HOMEDIR, local_file)
        tempfile(local_file)
        @test isfile(local_file)
        @test !isfile(server_file)

        local ftp
        num_bytes = copy_and_wait(server_file) do
            captured_size() do io
                ftp = FTP(; opts..., verbose=io)
                upload(ftp, local_file, ".")
            end
        end

        @test num_bytes > 0
        @test isfile(server_file)
        @test read(upload_file, String) == read(server_file, String)

        no_unexpected_changes(ftp)
        close(ftp)
        cleanup_file(server_file)
    end

    @testset "mkdir" begin
        server_dir = joinpath(HOMEDIR, testdir)
        cleanup_dir(server_dir)
        @test !isdir(server_dir)

        local ftp
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            mkdir(ftp, testdir)
        end
        @test num_bytes > 0
        @test isdir(server_dir)
        no_unexpected_changes(ftp)
        cleanup_dir(server_dir)
        close(ftp)
    end

    @testset "cd" begin
        server_dir = joinpath(HOMEDIR, testdir)

        mkdir(server_dir)

        local ftp
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            cd(ftp, testdir)
        end

        @test num_bytes > 0
        no_unexpected_changes(ftp, "$prefix/$testdir/")
        cleanup_dir(server_dir)
        close(ftp)
    end

    @testset "rmdir" begin
        server_dir = joinpath(HOMEDIR, testdir)

        mkdir(server_dir)
        @test isdir(server_dir)

        local ftp
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            rmdir(ftp, testdir)
        end

        @test num_bytes > 0
        @test !isdir(server_dir)
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "pwd" begin
        local ftp
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            dir = pwd(ftp)
            @test dir == "/"
        end
        @test num_bytes > 0
        no_unexpected_changes(ftp)
        close(ftp)
    end

    @testset "mv" begin
        new_file = "test_mv2.txt"

        tempfile(mv_file)
        @test isfile(mv_file)

        server_file = joinpath(HOMEDIR, mv_file)
        cp(mv_file, server_file)
        @test isfile(server_file)

        server_new_file = joinpath(HOMEDIR, new_file)
        # remove the new file if it already exists
        # on windows trying to overwrite the file will cause an error to be thrown
        isfile(server_new_file) && rm(server_new_file)

        local ftp
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            mv(ftp, mv_file, new_file)
        end

        @test num_bytes > 0
        @test !isfile(server_file)
        @test isfile(server_new_file)
        @test read(server_new_file, String) == read(mv_file, String)
        no_unexpected_changes(ftp)
        close(ftp)

        cleanup_file(server_new_file)
        cleanup_file(mv_file)
    end

    @testset "rm" begin
        tempfile(mv_file)
        @test isfile(mv_file)

        server_file = joinpath(HOMEDIR, mv_file)

        @test isfile(mv_file)

        !isfile(server_file) && cp(mv_file, server_file)
        @test isfile(server_file)

        local ftp
        num_bytes = captured_size() do io
            ftp = FTP(; opts..., verbose=io)
            rm(ftp, mv_file)
        end

        @test num_bytes > 0
        @test !isfile(server_file)
        no_unexpected_changes(ftp)
        close(ftp)

        cleanup_file(mv_file)
    end

    @testset "upload" begin
        @testset "uploading a file with only the local file name" begin
            server_file = joinpath(HOMEDIR, upload_file)
            @test isfile(upload_file)
            @test !isfile(server_file)

            local ftp
            num_bytes = copy_and_wait(server_file) do
                captured_size() do io
                    ftp = FTP(; opts..., verbose=io)
                    upload(ftp, upload_file, upload_file)
                end
            end

            @test num_bytes > 0
            @test isfile(server_file)
            @test read(upload_file, String) == read(server_file, String)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
        @testset "uploading a file with remote local file name" begin
            server_file= joinpath(HOMEDIR, "some name")
            @test !isfile(server_file)

            local ftp
            num_bytes = copy_and_wait(server_file) do
                captured_size() do io
                    ftp = FTP(; opts..., verbose=io)
                    upload(ftp, upload_file, "some name")
                end
            end

            @test num_bytes > 0
            @test isfile(server_file)
            @test read(upload_file, String) == read(server_file, String)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
        @testset "upload with retry single file" begin
            server_file= joinpath(HOMEDIR, "test_upload.txt")
            @test !isfile(server_file)

            local ftp
            num_bytes = copy_and_wait(server_file) do
                captured_size() do io
                    ftp = FTP(; opts..., verbose=io)
                    resp = upload(ftp, upload_file, "/")
                    @test resp.code == complete_transfer_code
                end
            end

            @test num_bytes > 0
            @test isfile(server_file)
            @test read(upload_file, String) == read(server_file, String)
            no_unexpected_changes(ftp)
            cleanup_file(server_file)
            close(ftp)
        end
    end

    @testset "verbose multiple commands" begin
        @testset "two commands" begin
            captured_size() do io
                # The initial connection will output information which we'll want to ignore
                # for the purposes of this test.
                ftp = FTP(; opts..., verbose=io)
                pwd(ftp)  # trigger connection
                init_pos = position(io)

                path = pwd(ftp)
                first_pos = position(io) - init_pos
                @test first_pos > 0

                path = pwd(ftp)
                second_pos = position(io) - init_pos
                @test second_pos == first_pos * 2
            end
        end

        @testset "write to stream between FTP commands" begin
            captured_size() do io
                ftp = FTP(; opts..., verbose=io)
                pwd(ftp)  # trigger connection
                init_pos = position(io)

                path = pwd(ftp)
                first_pos = position(io) - init_pos
                @test first_pos > 0

                str = "ABC"
                write(io, str)
                @test position(io) - init_pos == first_pos + length(str)

                path = pwd(ftp)
                second_pos = position(io) - init_pos
                @test second_pos == first_pos * 2 + length(str)
            end
        end
    end

    @testset "ftp open do end" begin
        num_bytes = captured_size() do io
            ftp(; opts..., verbose=io) do f
                pwd(f)
            end
        end
        @test num_bytes > 0
    end

end
 # check do (doesn't work)
  # ftp(ssl=false, user=user, pswd=pswd, host=host) do f
  # buff = download(f, file_name)
  # @test read(buff, String) == file_contents
  # no_unexpected_changes(f)
  # end

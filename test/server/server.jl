import Base: Process
import Base: close
using Conda
using Compat

Conda.add("pyopenssl")

Conda.add_channel("invenia")
Conda.add("pyftpdlib")

const ROOT = abspath(dirname(@__FILE__), "root")
const SCRIPT = abspath(dirname(@__FILE__), "server.py")
const CERT = abspath(dirname(@__FILE__), "test.crt")
const KEY = abspath(dirname(@__FILE__), "test.key")

python = joinpath(Conda.PYTHONDIR, is_windows()? "python.exe" : "python")

type FTPServer
    root::AbstractString
    port::Int
    username::AbstractString
    password::AbstractString
    permissions::AbstractString
    security::Symbol
    process::Process
    io::IO

     function FTPServer(
        root::AbstractString=ROOT; username="", password="", permissions="elradfmwM",
        security::Symbol=:none,
    )
        if isempty(username)
            username = string("user", rand(1:9999))
        end
        if isempty(password)
            password = randstring(40)
        end

        cmd = `$python $SCRIPT $username $password $root --permissions $permissions`
        if security != :none
            cmd = `$cmd --tls $security --cert-file $CERT --key-file $KEY --gen-certs TRUE`
        end
        io = Pipe()

        # Note: open(::AbstractCmd, ...) won't work here as it doesn't allow us to capture STDERR.
        process = spawn(pipeline(cmd, stdout=io, stderr=io))

        line = readline(io)
        m = match(r"starting FTP.* server on .*:(?<port>\d+)", line)
        if m != nothing
            port = parse(Int, m[:port])
            new(root, port, username, password, permissions, security, process, io)
        else
            kill(process)
            error(line, bytestring(readavailable(io)))  # Display traceback
        end
    end
end

hostname(server::FTPServer) = "localhost:$(port(server))"
port(server::FTPServer) = server.port
username(server::FTPServer) = server.username
password(server::FTPServer) = server.password
close(server::FTPServer) = kill(server.process)

localpath(server::FTPServer, path::AbstractString) = joinpath(server.root, split(path, '/')...)

function tempfile(path::AbstractString)
    content = randstring(rand(1:100))
    open(path, "w") do fp
        write(fp, content)
    end
    return content
end

function setup_root(dir::AbstractString)
    mkdir(dir)
    tempfile(joinpath(dir, "test_download.txt"))
    tempfile(joinpath(dir, "test_download2.txt"))
    mkdir(joinpath(dir, "test_directory"))
end

function setup_server()
    isdir(joinpath(ROOT, "test_directory")) || setup_root(ROOT)
end

function teardown_server()
    rm(ROOT, recursive=true)
    isfile(CERT) && rm(CERT)
    isfile(KEY) && rm(KEY)
end

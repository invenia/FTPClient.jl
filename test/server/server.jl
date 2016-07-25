import Base: Process

const ROOT = abspath(dirname(@__FILE__), "root")
const SCRIPT = abspath(dirname(@__FILE__), "server.py")

type FTPServer
    process::Process
    io::IO
    port::Int
    root::AbstractString

    function FTPServer(root::AbstractString=ROOT)
        # Note: open(::AbstractCmd, ...) won't work here as it doesn't allow us to capture STDERR.
        io = Pipe()
        process = spawn(pipeline(`python $SCRIPT user:passwd:$root`, stdout=io, stderr=io))
        m = match(r"starting FTP server on .*:(?<port>\d+)", readline(io))
        port = parse(Int, m[:port])
        new(process, io, port, root)
    end
end

port(server::FTPServer) = server.port
hostname(server::FTPServer) = "127.0.0.1:$(port(server))"
close(server::FTPServer) = kill(server.process)

localpath(server::FTPServer, path::AbstractString) = joinpath(server.root, split(path, '/')...)

function generate_self_signed(name::AbstractString, dir::AbstractString="")
    path = !isempty(dir) ? joinpath(dir, name) : name
    run(`openssl req -nodes -new -x509 -newkey rsa:2048 -keyout $path.key -out $path.crt -subj '/'`)
end

function tempfile(path::AbstractString)
    content = randstring(rand(1:100))
    open(path, "w") do fp
        write(fp, content)
    end
    return content
end

function setup_root(dir::AbstractString)
    tempfile(joinpath(dir, "test_download.txt"))
    tempfile(joinpath(dir, "test_download2.txt"))
    mkdir(joinpath(dir, "test_directory"))
end

function setup_server()
    isdir(ROOT) || setup_root(ROOT)
    generate_self_signed("test", ROOT)
end


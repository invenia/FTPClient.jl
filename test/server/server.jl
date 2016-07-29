import Base: Process

const ROOT = abspath(dirname(@__FILE__), "root")
const SCRIPT = abspath(dirname(@__FILE__), "server.py")
const CERT = abspath(dirname(@__FILE__), "test.crt")
const KEY = abspath(dirname(@__FILE__), "test.key")


type FTPServer
    process::Process
    io::IO
    port::Int
    root::AbstractString

     function FTPServer(root::AbstractString=ROOT; ssl::AbstractString="nothing")
        # Note: open(::AbstractCmd, ...) won't work here as it doesn't allow us to capture STDERR.
        io = Pipe()

        process = (isequal(ssl, "nothing"))? spawn(pipeline(`python $SCRIPT user:passwd:$root:elradfmwM`, stdout=io, stderr=io)):
                spawn(pipeline(`python $SCRIPT --tls $ssl --cert-file $CERT --key-file $KEY user:passwd:$root:elradfmwM`, stdout=io, stderr=io))

        line = readline(io)
        println(line)
        m = match(r"starting FTP.* server on .*:(?<port>\d+)", line)
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
    isdir(joinpath(ROOT, "test_directory")) || setup_root(ROOT)
    generate_self_signed("test", dirname(@__FILE__))
end


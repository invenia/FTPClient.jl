import Base: Process

type FTPServer
    process::Process
    io::IO
    port::Int

    function FTPServer()
        # Note: open(::AbstractCmd, ...) won't work here as it doesn't allow us to capture STDERR.
        io = Pipe()
        process = spawn(pipeline(`python server.py`, stdout=io, stderr=io))
        m = match(r"starting FTP server on .*:(?<port>\d+)", readline(io))
        port = parse(Int, m[:port])
        new(process, io, port)
    end
end

port(server::FTPServer) = server.port
hostname(server::FTPServer) = "127.0.0.1:$(port(server))"
close(server::FTPServer) = kill(server.process)

function generate_self_signed(name::AbstractString)
    run(`openssl req -nodes -new -x509 -newkey rsa:2048 -keyout $name.key -out $name.crt -subj '/'`)
end

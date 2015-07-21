push!(LOAD_PATH, "./src")

using FTPClient
using Base.Test
using JavaCall

function start_server()
    result = jcall(MockFTPServerJulia, "setUp", jboolean, ())
    @assert result == 1 "start_server failed"
end

function stop_server()
    result = jcall(MockFTPServerJulia, "tearDown", jboolean, ())
    @assert result == 1 "stop_server failed"
end

function set_user(name::String, password::String, home_dir::String)
    result = jcall(MockFTPServerJulia, "setUser", jboolean, (JString, JString, JString), name, password, home_dir)
    @assert result == 1 "set_user failed"
end

function set_file(name::String, content::String)
    result = jcall(MockFTPServerJulia, "setFile", jboolean, (JString, JString), name, content)
    @assert result == 1 "set_file failed"
end

function set_command_response(request::String, code::Int64, reponse::String)
    result = jcall(MockFTPServerJulia, "setCommandResponse", jboolean, (JString, jint, JString,), request, code, reponse)
    @assert result == 1 "set_command_response failed"
end

url = "localhost"
user = "test"
pswd = "test"
home_dir = "/"
file_name = "test_download.txt"
file_contents = "hello, world"
upload_file = "test_upload.txt"
f =  open(upload_file, "w")
write(f, "Test file to upload.\n")
close(f)


if (length(ARGS) >= 1 && ARGS[1] == "true")
    test_ssl = true
else
    test_ssl = false
end

if (length(ARGS) >= 2 && ARGS[2] == "true")
    test_implicit = true
else
    test_implicit = false
end

if (length(ARGS) == 4)
    user = ARGS[3]
    pswd = ARGS[4]
end

if (test_ssl)
    if (test_implicit)
        fp = joinpath(dirname(@__FILE__), "test_implicit_ssl.jl")
        println("$fp ...\n")
        include(fp)
    else
        fp = joinpath(dirname(@__FILE__), "test_explicit_ssl.jl")
        println("$fp ...\n")
        include(fp)
    end
else
    # Start Java, and point to the class in this directory
    JavaCall.init(["-Djava.class.path=$(joinpath(pwd(), "test"))"])
    MockFTPServerJulia = @jimport MockFTPServerJulia

    set_user(user, pswd, home_dir)
    set_file("/" * file_name, file_contents)
    set_command_response("AUTH", 230, "Login successful.")
    start_server()

    fp = joinpath(dirname(@__FILE__), "test_non_ssl.jl")
    println("$fp ...\n")
    include(fp)

    stop_server()
    JavaCall.destroy()
end

# Done testing
rm(upload_file)


push!(LOAD_PATH, "./src")

using FTPClient
using Base.Test
using JavaCall

# Start Java, use verbose for debug and point to the class in this directory
JavaCall.init(["-verbose:jni", "-verbose:gc","-Djava.class.path=$(joinpath(pwd(), "test"))"])
MockFTPServerJulia = @jimport MockFTPServerJulia

function start_server()
    result = jcall(MockFTPServerJulia, "setUp", jboolean, ())
    @assert result == 1 "start_server failed"
end

function stop_server()
    result = jcall(MockFTPServerJulia, "tearDown", jboolean, ())
    @assert result == 1 "stop_server failed"
end

function set_user(name::String, passowrd::String, home_dir::String)
    result = jcall(MockFTPServerJulia, "setUser", jboolean, (JString, JString, JString), name, passowrd, home_dir)
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


# write your own tests here
@test 1 == 1

# Test mock
set_user("test", "test", "/")
set_file("/test_file.txt", "hello, world")
set_command_response("AUTH", 230, "Login successful.")
start_server()



stop_server()
JavaCall.destroy()
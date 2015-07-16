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

url = "localhost"
user_name = "test"
password = "test"
home_dir = "/"
file_name = "test.txt"
file_contents = "hello, world"

options = RequestOptions(isSSL=false, username=user_name, passwd=password)

# Test mock
set_user(user_name, password, home_dir)
set_file("/" * file_name, file_contents)
set_command_response("AUTH", 230, "Login successful.")
start_server()

# Test ftp_get

response = ftp_get(url, file_name, options)

actual_file = open(file_name)
actual_content = readall(actual_file)
rm(file_name)

@test actual_content == file_contents

# Done testing

stop_server()
JavaCall.destroy()
push!(LOAD_PATH, "./src")

using FTPClient
using Base.Test
using JavaCall

# Start Java, use verbose for debug and point to the class in this directory
JavaCall.init(["-verbose:jni", "-verbose:gc","-Djava.class.path=$(joinpath(pwd(), "test"))"])

function start_server()
    MockFTPServerJulia = @jimport MockFTPServerJulia
    jcall(MockFTPServerJulia, "setUp", jint, ())
end

function stop_server()
    MockFTPServerJulia = @jimport MockFTPServerJulia
    jcall(MockFTPServerJulia, "tearDown", jint, ())
end


# write your own tests here
@test 1 == 1

# Test run
start_server()
stop_server()




JavaCall.destroy()
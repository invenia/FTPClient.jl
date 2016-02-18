# FTPClient
FTP client based on [LibCURL.jl](https://github.com/JuliaWeb/LibCURL.jl).

[![Build Status](https://travis-ci.org/invenia/FTPClient.jl.svg?branch=master)](https://travis-ci.org/invenia/FTPClient.jl) [![Build status](https://ci.appveyor.com/api/projects/status/sqsge28jvto74nhs/branch/master?svg=true)](https://ci.appveyor.com/project/adrienne-pind-invenia/ftpclient-jl/branch/master) [![codecov.io](http://codecov.io/github/invenia/FTPClient.jl/coverage.svg)](http://codecov.io/github/invenia/FTPClient.jl)

### Requirement

Tested with julia `Version 0.4.0-dev+6673`

### Usage

#### FTPC functions
`ftp_init()` and  `ftp_cleanup()` need to be used once per session.

Functions for non-persistent connection:
```julia
ftp_get(file_name::String, options::RequestOptions, save_path::String)
ftp_put(file_name::String, file::IO, options::RequestOptions)
ftp_command(cmd::String, options::RequestOptions)
```
- These functions all establish a connection, perform the desired operation then close the connection and return a `Response` object. Any data retrieved from server is in `Response.body`.

    ```julia
    type Response
        body::IO
        headers::Vector{String}
        code::Int
        total_time::FloatingPoint
        bytes_recd::Int
    end
    ```

Functions for persistent connection:
```julia
ftp_connect(options::RequestOptions)
ftp_get(ctxt::ConnContext, file_name::String, save_path::String)
ftp_put(ctxt::ConnContext, file_name::String, file::IO)
ftp_command(ctxt::ConnContext, cmd::String)
ftp_close_connection(ctxt::ConnContext)
```
- These functions all return a `Response` object, except `ftp_close_connection`, which does not return anything. Any data retrieved from server is in `Response.body`.

    ```julia
    type ConnContext
        curl::Ptr{CURL}
        url::String
        rd::ReadData
        wd::WriteData
        resp::Response
        options::RequestOptions
        close_ostream::Bool
    end
    ```

- `url` is of the form "localhost" or "127.0.0.1"
- `cmd` is of the form "PWD" or "CWD Documents/", and must be a valid FTP command
- `file_name` is both the name of the file that will be retrieved/uploaded and the name it will be saved as
- `options` is a `RequestOptions` object

    ```julia
    type RequestOptions
        blocking::Bool
        implicit::Bool
        ssl::Bool
        verify_peer::Bool
        active_mode::Bool
        headers::Vector{Tuple}
        username::String
        passwd::String
        url::String
        binary_mode::Bool
    end
    ```
    - `blocking`: default is true
    - `implicit`: use implicit security, default is false
    - `ssl`: use FTPS, default is false
    - `verify_peer`: verify authenticity of peer's certificate, default is true
    - `active_mode`: use active mode to establish data connection, default is false
    - `binary_mode`: used to tell the client to download files in binary mode, default is false


#### FTPObject functions
```julia
FTP(;host="", block=true, implt=false, ssl=false, ver_peer=true, act_mode=false, user="", pswd="", binary_mode=false)
close(ftp::FTP)
download(ftp::FTP, file_name::String, save_path::String="")
upload(ftp::FTP, file_name::String, file=nothing)
readdir(ftp::FTP)
cd(ftp::FTP, dir::String)
pwd(ftp::FTP)
rm(ftp::FTP, file_name::String)
rmdir(ftp::FTP, dir_name::String)
mkdir(ftp::FTP, dir::String)
mv(ftp::FTP, file_name::String, new_name::String)
binary(ftp::FTP)
ascii(ftp::FTP)
```
### Examples

Using non-peristent connection and FTPS with implicit security:
```julia
using FTPClient

ftp_init()
options = RequestOptions(ssl=true, implicit=true, username="user1", passwd="1234", url="localhost")

resp = ftp_get("download_file.txt", options)
io_buffer = resp.body

resp = ftp_get("download_file.txt", options, "Documents/downloaded_file.txt")
io_stream = resp.body

file = open("upload_file.txt")
resp = ftp_put("upload_file.txt", file, options)
close(file)

resp = ftp_command("LIST", options)
dir = resp.body

ftp_cleanup()
```

Using persistent connection and FTPS with explicit security:
```julia
using FTPClient

ftp_init()
options = RequestOptions(ssl=true, username="user2", passwd="5678", url="localhost")

ctxt = ftp_connect(options)

resp = ftp_get(ctxt, "download_file.txt")
io_buffer = resp.body

resp = ftp_get(ctxt, "download_file.txt", "Documents/downloaded_file.txt")
io_stream = resp.body

resp = ftp_command(ctxt, "CWD Documents/")

file = open("upload_file.txt")
resp = ftp_put(ctxt, "upload_file.txt", file)
close(file)

ftp_close_connection(ctxt)

ftp_cleanup()
```

Using the FTP object with a persistent connection and FTPS with implicit security:
```julia
ftp_init()
ftp = FTP(host="localhost", implt=true, ssl=true, user="user3", pswd="2468" )

dir_list = readdir(ftp)
cd(ftp, "Documents/School")
pwd(ftp)

# download file contents to buffer
buff = download(ftp, "Assignment1.txt")

# download and save file to specified path
file = download(ftp, "Assignment2.txt", "./A2/Assignment2.txt")

# upload contents of buffer and save to file
buff = IOBuffer("Buffer to upload.")
upload(ftp, "upload_buffer.txt", buff)

# upload local file to server
upload(ftp, "upload_file.txt", file)

mv(ftp, "upload_file.txt", "Assignment3.txt")

rm(ftp, "upload_buffer.txt")

mkdir(ftp, "TEMP_DIR")
rmdir(ftp, "TEMP_DIR")

# set transfer mode to binary or ascii
binary(ftp)
ascii(ftp)

close(ftp)
ftp_cleanup()
```

### Running Tests

`julia --color=yes test/runtests.jl <use_ssl> <use_implicit> <username> <password>`

To set up the mock FTP server
- Add the [JavaCall.jl](https://github.com/aviks/JavaCall.jl) package with `Pkg.add("JavaCall”)`
- Add the [FactCheck.jl](https://github.com/JuliaLang/FactCheck.jl) package with `Pkg.add("FactCheck")`, may need to update the package to get most recent version (v0.3.1).
- Build dependencies via `Pkg.build("FTPClient")`

The mock FTP server does not work with SSL. To run the non-ssl tests and FTPObject tests:
    `julia --color=yes test/runtests.jl`

The ssl tests can be run if you have a local ftp server set up.
- To run the tests using implicit security: `julia --color=yes test/runtests.jl true true <username> <password>`
- To run the tests using explicit security: `julia --color=yes test/runtests.jl true false <username> <password>`

#### 0.5 Issues

[JavaCall.jl is not working in 0.5](https://github.com/aviks/JavaCall.jl/pull/30). If you want to be able to run tests, you need to get JavaCall.jl by running
```julia
Pkg.clone("https://github.com/samuel-massinon-invenia/JavaCall.jl.git")
Pkg.checkout("JavaCall", "pull-request/bf8b4987")
```

### Code Coverage

There are parts of the code that are not executed when running the basic test. This is because the Mock Server does not support ssl and we cannot run effective tests for those lines of code.

There are however separate tests for ssl. That requires setting up a local ftp server and following the steps above.

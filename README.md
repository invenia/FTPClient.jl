FTPClient.jl
============

Provides FTP client functionality based on [libcurl](https://github.com/JuliaWeb/LibCURL.jl).

[![Build Status](https://travis-ci.org/invenia/FTPClient.jl.svg?branch=master)](https://travis-ci.org/invenia/FTPClient.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/ko8ama8fh0fgyjvq/branch/master?svg=true)](https://ci.appveyor.com/project/invenia/ftpclient-jl/branch/master)
[![codecov.io](http://codecov.io/github/invenia/FTPClient.jl/coverage.svg)](http://codecov.io/github/invenia/FTPClient.jl)

### Usage

#### FTPC functions

Note `ftp_init()` and  `ftp_cleanup()` need to be used once per session.

Functions for non-persistent connection:

```julia
ftp_get(options::RequestOptions, file_name::AbstractString, save_path::AbstractString)
ftp_put(options::RequestOptions, file_name::AbstractString, file::IO)
ftp_command(options::RequestOptions, cmd::AbstractString)
```

These functions all establish a connection, perform the desired operation then close the
connection and return a `Response` object. Any data retrieved from server is in
`Response.body`:

```julia
mutable struct Response
    body::IO
    headers::Vector{AbstractString}
    code::Int
    total_time::FloatingPoint
    bytes_recd::Int
end
```

Functions for persistent connections:

```julia
ftp_connect(options::RequestOptions)
ftp_get(ctxt::ConnContext, file_name::AbstractString, save_path::AbstractString)
ftp_put(ctxt::ConnContext, file_name::AbstractString, file::IO)
ftp_command(ctxt::ConnContext, cmd::AbstractString)
ftp_close_connection(ctxt::ConnContext)
```

These functions all return a `Response` object, except `ftp_close_connection`, which does
not return anything. Any data retrieved from server is in `Response.body`.

```julia
mutable struct ConnContext
    curl::Ptr{CURL}
    url::AbstractString
    options::RequestOptions
end
```

- `url` is of the form "localhost" or "127.0.0.1"
- `cmd` is of the form "PWD" or "CWD Documents/", and must be a valid FTP command
- `file_name` is both the name of the file that will be retrieved/uploaded and the name it will be saved as
- `options` is a `RequestOptions` object

```julia
mutable struct RequestOptions
    implicit::Bool
    ssl::Bool
    verify_peer::Bool
    active_mode::Bool
    username::AbstractString
    password::AbstractString
    url::AbstractString
    hostname::AbstractString
end
```

- `implicit`: use implicit security, default is false
- `ssl`: use FTPS or FTPES (if implicit is set to false), default is false
- `verify_peer`: verify authenticity of peer's certificate, default is true
- `active_mode`: use active mode to establish data connection, default is false


#### FTPObject functions

```julia
FTP(;hostname="", implicit=false, ssl=false, verify_peer=true, active_mode=false, username="", password="")
close(ftp::FTP)
download(ftp::FTP, file_name::AbstractString, save_path::AbstractString="")
upload(ftp::FTP, local_name::AbstractString)
upload(ftp::FTP, local_name::AbstractString, remote_name::AbstractString)
upload(ftp::FTP, local_file::IO, remote_name::AbstractString)
readdir(ftp::FTP)
cd(ftp::FTP, dir::AbstractString)
pwd(ftp::FTP)
rm(ftp::FTP, file_name::AbstractString)
rmdir(ftp::FTP, dir_name::AbstractString)
mkdir(ftp::FTP, dir::AbstractString)
mv(ftp::FTP, file_name::AbstractString, new_name::AbstractString)
```

### Examples

Using non-persistent connection and FTPS with implicit security:

```julia
using FTPClient

ftp_init()
options = RequestOptions(ssl=true, implicit=true, username="user1", password="1234", hostname="localhost")

resp = ftp_get(options, "download_file.txt")
io_buffer = resp.body

resp = ftp_get(options, "download_file.txt", "Documents/downloaded_file.txt")
io_stream = resp.body

file = open("upload_file.txt")
resp = ftp_put(options, "upload_file.txt", file)
close(file)

resp = ftp_command(options, "LIST")
dir = resp.body

ftp_cleanup()
```

Using persistent connection and FTPES with explicit security:

```julia
using FTPClient

ftp_init()
options = RequestOptions(ssl=true, username="user2", password="5678", url="localhost")

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
ftp = FTP(hostname="localhost", implicit=true, ssl=true, username="user3", password="2468" )

dir_list = readdir(ftp)
cd(ftp, "Documents/School")
pwd(ftp)

# download file contents to buffer
buff = download(ftp, "Assignment1.txt")

# download and save file to specified path
file = download(ftp, "Assignment2.txt", "./A2/Assignment2.txt")

# upload file upload_file_name
upload(ftp, upload_file_name)

# upload file upload_file_name and change name to "new_name"
upload(ftp, upload_file_name, "new_name")

# upload contents of buffer and save to file
buff = IOBuffer("Buffer to upload.")
upload(ftp, buff, "upload_buffer.txt")

# upload local file to server
upload(ftp, file, "upload_file.txt")

mv(ftp, "upload_file.txt", "Assignment3.txt")

rm(ftp, "upload_buffer.txt")

mkdir(ftp, "TEMP_DIR")
rmdir(ftp, "TEMP_DIR")

close(ftp)
ftp_cleanup()
```

### Running Tests

`julia --color=yes test/runtests.jl <use_ssl> <use_implicit> <username> <password>`

### Code Coverage

There are parts of the code that are not executed when running the basic test. The server is not yet equipped
to check for error situations on command.


## Troubleshoot

### Downloaded files are unusable

Try downloading file in both binary and ASCII mode to see if one of the files is usable.

### Linux and Travis CI

Travis CI currently [does not reliably support FTP connections on sudo-enabled
Linux](https://blog.travis-ci.com/2018-07-23-the-tale-of-ftp-at-travis-ci). This will
usually manifest itself as a `Connection Timeout` error. Disable `sudo` for a workaround.

### Other issues

Please add any other problem or bugs to the issues page.

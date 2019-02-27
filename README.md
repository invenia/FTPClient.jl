FTPClient.jl
============

[![Build Status](https://travis-ci.org/invenia/FTPClient.jl.svg?branch=master)](https://travis-ci.org/invenia/FTPClient.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/github/invenia/FTPClient.jl?svg=true)](https://ci.appveyor.com/project/invenia/ftpclient-jl/branch/master)
[![codecov](http://codecov.io/gh/invenia/FTPClient.jl/branch/master/graph/badge.svg)](http://codecov.io/gh/invenia/FTPClient.jl)

A Julia FTP client using [LibCURL](https://github.com/JuliaWeb/LibCURL.jl) supporting FTP and FTP over SSL.

### Examples

Depending on the settings of the FTP server you are connecting to you may need to deal with
various security settings.

- FTP with no Transport Layer Security (FTP). Typically uses port 21/TCP.

    ```julia
    julia> ftp = FTP(hostname="example.com", username="user", password="1234")
    URL:       ftp://user:*****@example.com/
    Transfer:  passive mode
    Security:  none

    julia> ftp = FTP("ftp://user:1234@example.com")
    URL:       ftp://user:*****@example.com/
    Transfer:  passive mode
    Security:  none
    ```

- FTP with implicit security (FTPS). Typically uses port 990/TCP.

    ```julia
    julia> ftp = FTP(hostname="example.com", username="user", password="1234", ssl=true, implicit=true)
    URL:       ftps://user:*****@example.com/
    Transfer:  passive mode
    Security:  implicit

    julia> ftp = FTP("ftps://user:1234@example.com")
    URL:       ftps://user:*****@example.com/
    Transfer:  passive mode
    Security:  implicit
    ```

- FTP with explicit security (FTPES). Typically uses port 21/TCP.

    ```julia
    julia> ftp = FTP(hostname="example.com", username="user", password="1234", ssl=true, implicit=false)
    URL:       ftpes://user:*****@example.com/
    Transfer:  passive mode
    Security:  explicit

    julia> ftp = FTP("ftpes://user:1234@example.com")
    URL:       ftpes://user:*****@example.com/
    Transfer:  passive mode
    Security:  explicit
    ```

Once you've created your `FTP` instance you can use many of the [filesystem](https://docs.julialang.org/en/v1/base/file/)
functions that Julia provides. A quick example showing some of the functions available:

```julia
julia> cd(ftp, "Documents/School")

julia> pwd(ftp)
"/Documents/School"

julia> readdir(ftp)
1-element Array{String,1}:
 "Assignment1.txt"
 "Assignment2.txt"

julia> io = download(ftp, "Assignment1.txt");  # Download as IO stream

julia> download(ftp, "Assignment2.txt", "./A2/Assignment2.txt");  # Save file to a specified path

julia> upload(ftp, "Assignment3.txt", ".")  # Upload local file "Assignment3.txt" to FTP server home directory

julia> open("Assignment3.txt") do fp
           upload(ftp, fp, "Assignment3-copy.txt")  # Upload IO content as file "Assignment3-copy.txt" on FTP server
       end

julia> mv(ftp, "Assignment3-copy.txt", "Assignment3-dup.txt")

julia> rm(ftp, "Assignment3-dup.txt")

julia> mkdir(ftp, "tmp")

julia> rmdir(ftp, "tmp")

julia> close(ftp)
```

If you want to upload a file but retry on failures you can do the following:

```julia
julia> ftp_retry = retry(delays=fill(5.0, 3)) do
           upload(ftp, "Assignment3.txt", ".")
       end

julia> ftp_retry()
```

## FAQ

### Downloaded files are unusable

Try downloading file in both binary and ASCII mode to see if one of the files is usable.

### Linux and Travis CI

Travis CI currently [does not reliably support FTP connections on sudo-enabled Linux]https://blog.travis-ci.com/2018-07-23-the-tale-of-ftp-at-travis-ci).
This will usually manifest itself as a `Connection Timeout` error. Disable `sudo` for a
workaround.

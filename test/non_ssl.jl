import Compat: readstring
using FTPClient
using Base.Test


include("server/server.jl")
include("utils.jl")
server = FTPServer()

setup_server()

#non-ssl active mode
options = RequestOptions(hostname=hostname(server), username="user", passwd="passwd", ssl=false, active_mode=true)
# options = RequestOptions(hostname="127.0.0.1:8000", username="user", passwd="passwd", ssl=false, active_mode=true)

headers = [
    "220 pyftpdlib ... ready.",
    "331 Username ok, send password.",
    "230 Login successful.",
    "257 \"/\" is the current directory.",
    "200 Active data connection established.",
    "200 Type set to: Binary.",
    "213 ...",
    "125 Data connection already open. Transfer starting.",
    "226 Transfer complete.",
]

local_file = "test_download.txt"
resp = ftp_get(local_file, options)
server_file = joinpath(ROOT, local_file)
body = readstring(server_file)

@test resp.code == 226
@test readstring(resp.body) == body
@test resp.bytes_recd == length(body)
@test is_headers_equal(resp.headers, headers)


# @testset "ftp_put" begin

# options = RequestOptions(hostname="127.0.0.1:8000", username="user", passwd="passwd", ssl=false, active_mode=false)

local_file = "test_upload.txt"
tempfile(local_file)
# server_file = localpath(server, "/$local_file")  # The path to the file on the server
server_file = joinpath(ROOT, local_file)
if (isfile(server_file))
    rm(server_file)
end
@test !isfile(server_file)
try
    resp = open(local_file) do fp
        ftp_put(local_file, fp, options)
    end
    @test isfile(server_file)
    @test readstring(server_file) == readstring(local_file)
    @test readstring(resp.body) == ""
    # @test readstring(server_file) == upload_file_contents***
finally
    rm(server_file)
    @test !isfile(server_file)
end

headers = [
    "220 pyftpdlib ... ready.",
    "331 Username ok, send password.",
    "230 Login successful.",
    "257 \"/\" is the current directory.",
    "200 Active data connection established.",
    "200 Type set to: Binary.",
    "125 Data connection already open. Transfer starting.",
    "226 Transfer complete.",
]

@test resp.code == 226
@test resp.bytes_recd == 0
@test is_headers_equal(resp.headers, headers)


headers = [
    "220 pyftpdlib ... ready.",
    "331 Username ok, send password.",
    "230 Login successful.",
    "257 \"/\" is the current directory.",
    "200 Active data connection established.",
    "200 Type set to: ASCII.",
    "257 \"/\" is the current directory."
]

#@testset "ftp_command" begin
    resp = ftp_command("PWD", options)
    @test resp.code == 257
    @test typeof(resp.total_time) == Float64
    @test resp.bytes_recd == 0
    @test is_headers_equal(resp.headers, headers)
#end

#Persistent connection tests, passive mode
options = RequestOptions(hostname=hostname(server), username="user", passwd="passwd", ssl=false, active_mode=false)
# ftp connect
ctxt, resp = ftp_connect(options)
headers = [
    "220 pyftpdlib ... ready.",
    "331 Username ok, send password.",
    "230 Login successful.",
    "257 \"/\" is the current directory.",
    "229 Entering extended passive mode (...).",
    "200 Type set to: ASCII.",
    "125 Data connection already open. Transfer starting.",
    "226 Transfer complete.",
]
file_name = "test_download.txt"
directory_name = "test_directory"
@test typeof(resp.total_time) == Float64
@test resp.code == 226
actual_body = readstring(resp.body)
@test contains(actual_body, file_name)
@test contains(actual_body, directory_name)
@test resp.bytes_recd == length(actual_body)
@test is_headers_equal(resp.headers, headers)
@test ctxt.url == options.url == "ftp://$(hostname(server))/"
@test ctxt.options == options
ftp_close_connection(ctxt)

# ftp_command
ctxt, resp = ftp_connect(options)
headers = [
    "229 Entering extended passive mode (...).",
    "257 \"/\" is the current directory."
]
resp = ftp_command(ctxt, "PWD")
actual_body = readstring(resp.body)
@test resp.code == 257
@test typeof(resp.total_time) == Float64
@test resp.bytes_recd == length(actual_body)
@test length(actual_body) == 0
@test actual_body == ""
@test is_headers_equal(resp.headers, headers)
@test ctxt.url == options.url == "ftp://$(hostname(server))/"
@test ctxt.options == options
ftp_close_connection(ctxt)

# ftp_get
ctxt, resp = ftp_connect(options)
headers = [
    "200 Active data connection established.",
    "200 Type set to: Binary.",
    "213 ...",
    "125 Data connection already open. Transfer starting.",
    "226 Transfer complete.",
]

local_file = "test_download.txt"
resp = ftp_get(ctxt, local_file)
server_file = joinpath(ROOT, local_file)
body = readstring(server_file)

@test resp.code == 226
@test readstring(resp.body) == body
@test typeof(resp.total_time) == Float64
@test resp.bytes_recd == length(body)
@test is_headers_equal(resp.headers, headers)
@test ctxt.url == options.url == "ftp://$(hostname(server))/"
@test ctxt.options == options
ftp_close_connection(ctxt)

# ftp_put
local_file = "test_upload.txt"
tempfile(local_file)
server_file = joinpath(ROOT, local_file)

@test !isfile(server_file)
try
    ctxt, resp = ftp_connect(options)
    resp = open(local_file) do fp

        ftp_put(ctxt, local_file, fp)
    end
    @test isfile(server_file)

    @test readstring(server_file) == readstring(local_file)
    @test readstring(resp.body) == ""
    # @test readstring(server_file) == upload_file_contents***
finally
    rm(server_file)
    @test !isfile(server_file)
end

headers = [
    "229 Entering extended passive mode (...).",
    "200 Type set to: Binary.",
    "125 Data connection already open. Transfer starting.",
    "226 Transfer complete."
    ]

@test resp.code == 226
@test resp.bytes_recd == 0

@test is_headers_equal(resp.headers, headers)
ftp_close_connection(ctxt)

# download a file to a specific path
options = RequestOptions(hostname=hostname(server), username="user", passwd="passwd", ssl=false, active_mode=false)
save_file = "test_file_save_path.txt"
save_path = pwd() * "/" * save_file

local_file = "test_download.txt"
resp = ftp_get(local_file, options, save_path)
server_file = joinpath(ROOT, local_file)
body = readstring(server_file)

@test resp.code == 226
@test isfile(save_file) == true
open(save_file) do file
    @test readstring(file) == body
end
rm(save_file)

@unix_only upload_local_byte_file_contents = string("466F6F426172", "0A", "466F6F426172")
@unix_only upload_local_byte_file_contents_ascii_transfer = string("466F6F426172", "0D0A", "466F6F426172")
@windows_only upload_local_byte_file_contents = string("466F6F426172", "0D0A", "466F6F426172")
@windows_only upload_local_byte_file_contents_ascii_transfer = string("466F6F426172", "0A", "466F6F426172")
byte_upload_file_name = "test_upload_byte_file"
@unix_only byte_file_contents = string("466F6F426172", "0D0A", "466F6F426172")
@unix_only byte_file_contents_ascii_transfer = string("466F6F426172", "0A", "0A", "466f6f426172")
@windows_only byte_file_contents = string("466F6F426172", "0A", "466F6F426172", "1A1A1A")
byte_file_name = "test_byte_file"
open(joinpath(ROOT, byte_file_name), "w") do fp
    write(fp, hex2bytes(byte_file_contents))
end

# @testset "it is not the same file when downloading in ascii mode" begin
options = RequestOptions(hostname=hostname(server), username="user", passwd="passwd", ssl=false, active_mode=false)
 resp = ftp_get(byte_file_name, options; mode=ascii_mode)
 bytes = read(resp.body)

 @unix_only @test bytes != hex2bytes(byte_file_contents)
 @unix_only @test bytes == hex2bytes(byte_file_contents_ascii_transfer)


# it is the same file when downloading in binary mode" begin
#options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
 resp = ftp_get(byte_file_name, options)
 bytes = read(resp.body)
 @test bytes == hex2bytes(byte_file_contents)

#"it is not the same file when downloading in ascii mode" begin
# options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
 ctxt, resp = ftp_connect(options)
 resp = ftp_get(ctxt, byte_file_name, mode=ascii_mode)
 bytes = read(resp.body)
 @unix_only @test bytes != hex2bytes(byte_file_contents)
 @unix_only @test bytes == hex2bytes(byte_file_contents_ascii_transfer)

#"it is the same file when downloading in binary mode" begin
# options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
 ctxt, resp = ftp_connect(options)
 resp = ftp_get(ctxt, byte_file_name)
 bytes = read(resp.body)
 @test bytes == hex2bytes(byte_file_contents)

#"it is not the same file when downloading in ascii mode" begin
 ftp = FTP(user="user", pswd="passwd", host=hostname(server))
 buff = download(ftp, byte_file_name, mode=ascii_mode)
 bytes = read(buff)
 @unix_only @test bytes != hex2bytes(byte_file_contents)
 @unix_only @test bytes == hex2bytes(byte_file_contents_ascii_transfer)

# "it is the same file when downloading in binary mode" begin
# ftp = FTP(user="user", pswd="passwd", host=hostname(server))
 buff = download(ftp, byte_file_name)
 bytes = read(buff)
 @test bytes == hex2bytes(byte_file_contents)

# "binary file download using ftp object, start in ascii, and switch to binary, then back" begin
# ftp = FTP(user=user, pswd=pswd, host=host)
buff = download(ftp, byte_file_name, mode=ascii_mode)
bytes = read(buff)
@unix_only @test bytes != hex2bytes(byte_file_contents)
@unix_only @test bytes == hex2bytes(byte_file_contents_ascii_transfer)
buff = download(ftp, byte_file_name)
bytes = read(buff)
@test bytes == hex2bytes(byte_file_contents)
buff = download(ftp, byte_file_name, mode=ascii_mode)
bytes = read(buff)
@unix_only @test bytes != hex2bytes(byte_file_contents)
@unix_only @test bytes == hex2bytes(byte_file_contents_ascii_transfer)

#"it is not the same file when downloading in ascii mode" begin
# options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
 upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
 ftp_put(byte_upload_file_name, upload_binary_file, options; mode=ascii_mode)
 server_byte_file = joinpath(ROOT, byte_upload_file_name)
 @test isfile(server_byte_file)
# @unix_only @test upload_local_byte_file_contents != readstring(server_byte_file)
 @unix_only @test hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
 rm(server_byte_file)
 @test !isfile(server_byte_file)

#"it is the same file when downloading in binary mode" begin
# options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
 upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
 server_byte_file = joinpath(ROOT, byte_upload_file_name)
 ftp_put(byte_upload_file_name, upload_binary_file, options; mode=binary_mode)
 @test isfile(server_byte_file)
 @test hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
 rm(server_byte_file)
 @test !isfile(server_byte_file)

# "it is not the same file when downloading in ascii mode" begin
# options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
 ctxt, resp = ftp_connect(options)
 server_byte_file = joinpath(ROOT, byte_upload_file_name)
 upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
 ftp_put(ctxt, byte_upload_file_name, upload_binary_file; mode=ascii_mode)
 @test isfile(server_byte_file)
 @unix_only hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
 rm(server_byte_file)
 @test !isfile(server_byte_file)

# "it is the same file when downloading in binary mode" begin
#options = RequestOptions(ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
 ctxt, resp = ftp_connect(options)
 upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
 ftp_put(ctxt, byte_upload_file_name, upload_binary_file)
 @test isfile(server_byte_file)
 @test hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
 rm(server_byte_file)
 @test !isfile(server_byte_file)

# "it is not the same file when downloading in ascii mode" begin
#  ftp = FTP(user=user, pswd=pswd, host=host)
 upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
 upload(ftp, upload_binary_file, byte_upload_file_name; mode=ascii_mode)
 @test isfile(server_byte_file)
 @unix_only hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
 rm(server_byte_file)
 @test !isfile(server_byte_file)

# "it is the same file when downloading in binary mode" begin
# ftp = FTP(user=user, pswd=pswd, host=host)
 upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
 upload(ftp, upload_binary_file, byte_upload_file_name)
 @test isfile(server_byte_file)
 @test hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
 rm(server_byte_file)
 @test !isfile(server_byte_file)

#"binary file upload using ftp object, start in ascii, and switch to binary, then back" begin
# ftp = FTP(user=user, pswd=pswd, host=host)
upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
upload(ftp, upload_binary_file, byte_upload_file_name; mode=ascii_mode)
@test isfile(server_byte_file)
@unix_only @test hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
rm(server_byte_file)
@test !isfile(server_byte_file)

upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
upload(ftp, upload_binary_file, byte_upload_file_name)
@test isfile(server_byte_file)
@test hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
rm(server_byte_file)
@test !isfile(server_byte_file)

upload_binary_file = IOBuffer(hex2bytes(upload_local_byte_file_contents))
upload(ftp, upload_binary_file, byte_upload_file_name; mode=ascii_mode)
@test isfile(server_byte_file)
@unix_only @test hex2bytes(upload_local_byte_file_contents) == read(server_byte_file)
rm(server_byte_file)
@test !isfile(server_byte_file)

ftp_cleanup()

close(server)

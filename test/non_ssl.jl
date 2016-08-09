tempfile(upload_file)
tempfile(joinpath(ROOT,download_file))

opts = (
    :hostname => hostname(server),
    :username => username(server),
    :password => password(server),
)

#non-ssl active mode
options = RequestOptions(; opts..., ssl=false, active_mode=true)
# options = RequestOptions(hostname="127.0.0.1:8000", username="user", passwd="passwd", ssl=false, active_mode=true)
function check_response(resp, body, code, headers)
    @test typeof(resp.total_time) == Float64
    @test resp.code == code
    @test readstring(resp.body) == body
    @test resp.bytes_recd == length(body)
    @test is_headers_equal(resp.headers, headers)
end


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

local_file = download_file
server_file = joinpath(ROOT, local_file)
@test !isfile(local_file)
resp = ftp_get(options, local_file)
@test !isfile(local_file)
body = readstring(server_file)
check_response(resp, body, 226, headers)


# @testset "ftp_put" begin

# options = RequestOptions(hostname="127.0.0.1:8000", username="user", passwd="passwd", ssl=false, active_mode=false)
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
local_file = upload_file
server_file = joinpath(ROOT, local_file)

@test !isfile(server_file)
try
    resp = open(local_file) do fp
        ftp_put(options, local_file, fp)
    end
    @test isfile(server_file)
    @test readstring(server_file) == readstring(local_file)
finally
    cleanup_file(server_file)
end
check_response(resp, "", 226, headers)


headers = [
    "220 pyftpdlib ... ready.",
    "331 Username ok, send password.",
    "230 Login successful.",
    "257 \"/\" is the current directory.",
    "200 Active data connection established.",
    "200 Type set to: ASCII.",
    "257 \"/\" is the current directory."
]

resp = ftp_command(options, "PWD")
check_response(resp, "", 257, headers)



#Persistent connection tests, passive mode
options = RequestOptions(; opts..., ssl=false, active_mode=false)
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

directory_name = "test_directory"
body = readstring(resp.body)
@test contains(body, download_file)
@test contains(body, directory_name)
@test resp.bytes_recd == length(body)
@test resp.code == 226
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
@test ctxt.url == options.url == "ftp://$(hostname(server))/"
@test ctxt.options == options
check_response(resp, "", 257, headers)

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

local_file = download_file
server_file = joinpath(ROOT, local_file)
@test !isfile(local_file)

resp = ftp_get(ctxt, local_file)
body = readstring(server_file)

@test !isfile(local_file)
@test ctxt.url == options.url == "ftp://$(hostname(server))/"
@test ctxt.options == options

check_response(resp, body, 226, headers)
ftp_close_connection(ctxt)

# ftp_put
headers = [
    "229 Entering extended passive mode (...).",
    "200 Type set to: Binary.",
    "125 Data connection already open. Transfer starting.",
    "226 Transfer complete."
    ]
local_file = upload_file
server_file = joinpath(ROOT, local_file)
@test !isfile(server_file)

ctxt, resp = ftp_connect(options)

try
    resp = open(local_file) do fp

        ftp_put(ctxt, local_file, fp)
    end
    @test isfile(server_file)
    ftp_close_connection(ctxt) # close the connection so that the server file closes
    @test readstring(server_file) == readstring(local_file)
finally
    cleanup_file(server_file)
end
check_response(resp, "", 226, headers)



# download a file to a specific path
headers = [
    "220 pyftpdlib ... ready.",
    "331 Username ok, send password.",
    "230 Login successful.",
    "257 \"/\" is the current directory.",
    "200 Active data connection established.",
    "200 Type set to: Binary.",
    "213 ...",
    "125 Data connection already open. Transfer starting.",
    "226 Transfer complete."
    ]
options = RequestOptions(; opts..., ssl=false, active_mode=false)

save_path = joinpath(pwd(), "test_path.txt")
@test !isfile(save_path)

local_file = download_file

resp = ftp_get(options, local_file, save_path)
server_file = joinpath(ROOT, local_file)
body = readstring(server_file)

@test isfile(save_path) == true

@test readstring(save_path) == body
@test resp.code == 226
@test readstring(resp.body) == ""
@test is_headers_equal(resp.headers, headers)

rm(save_path)


@unix_only upload_bytes = string("466F6F426172", "0A", "466F6F426172")
@windows_only upload_bytes = string("466F6F426172", "0D0A", "466F6F426172")

@unix_only download_bytes = string("466F6F426172", "0D0A", "466F6F426172")
@unix_only download_bytes_ascii = string("466F6F426172", "0A", "0A", "466f6f426172")
@windows_only download_bytes = string("466F6F426172", "0A", "466F6F426172", "1A1A1A")

byte_upload_file = "test_upload_byte_file"
byte_file = "test_byte_file"

open(joinpath(ROOT, byte_file), "w") do fp
    write(fp, hex2bytes(download_bytes))
end

# it is not the same file when downloading in ascii mode
options = RequestOptions(; opts..., ssl=false, active_mode=false)
resp = ftp_get(options, byte_file; mode=ascii_mode)
bytes = read(resp.body)
@unix_only @test bytes != hex2bytes(download_bytes)
@unix_only @test bytes == hex2bytes(download_bytes_ascii)

# it is the same file when downloading in binary mode
resp = ftp_get(options, byte_file)
bytes = read(resp.body)
@test bytes == hex2bytes(download_bytes)

# it is not the same file when downloading in ascii mode
ctxt, resp = ftp_connect(options)
resp = ftp_get(ctxt, byte_file, mode=ascii_mode)
bytes = read(resp.body)
@unix_only @test bytes != hex2bytes(download_bytes)
@unix_only @test bytes == hex2bytes(download_bytes_ascii)
ftp_close_connection(ctxt)

# it is the same file when downloading in binary mode
ctxt, resp = ftp_connect(options)
resp = ftp_get(ctxt, byte_file)
bytes = read(resp.body)
@test bytes == hex2bytes(download_bytes)
ftp_close_connection(ctxt)

# it is not the same file when downloading in ascii mode
ftp = FTP(; opts...)
buff = download(ftp, byte_file, mode=ascii_mode)
bytes = read(buff)
@unix_only @test bytes != hex2bytes(download_bytes)
@unix_only @test bytes == hex2bytes(download_bytes_ascii)
Base.close(ftp)

# it is the same file when downloading in binary mode
ftp = FTP(; opts...)
buff = download(ftp, byte_file)
bytes = read(buff)
@test bytes == hex2bytes(download_bytes)
Base.close(ftp)

# binary file download using ftp object, start in ascii, and switch to binary, then back
ftp = FTP(; opts...)
buff = download(ftp, byte_file, mode=ascii_mode)
bytes = read(buff)
@unix_only @test bytes != hex2bytes(download_bytes)
@unix_only @test bytes == hex2bytes(download_bytes_ascii)
buff = download(ftp, byte_file)
bytes = read(buff)
@test bytes == hex2bytes(download_bytes)
buff = download(ftp, byte_file, mode=ascii_mode)
bytes = read(buff)
@unix_only @test bytes != hex2bytes(download_bytes)
@unix_only @test bytes == hex2bytes(download_bytes_ascii)
Base.close(ftp)

# upload
server_byte_file = joinpath(ROOT, byte_upload_file)
bin_file = IOBuffer(hex2bytes(upload_bytes))
ftp_put(options, byte_upload_file, bin_file; mode=binary_mode)
@test isfile(server_byte_file)
@test hex2bytes(upload_bytes) == read(server_byte_file)
cleanup_file(server_byte_file)

# upload with ctxt
ctxt, resp = ftp_connect(options)
bin_file = IOBuffer(hex2bytes(upload_bytes))
ftp_put(ctxt, byte_upload_file, bin_file)
@test isfile(server_byte_file)
@test hex2bytes(upload_bytes) == read(server_byte_file)
cleanup_file(server_byte_file)
ftp_close_connection(ctxt)

# ftpObject upload
ftp = FTP(; opts...)
bin_file = IOBuffer(hex2bytes(upload_bytes))
upload(ftp, bin_file, byte_upload_file)
@test isfile(server_byte_file)
@test hex2bytes(upload_bytes) == read(server_byte_file)
cleanup_file(server_byte_file)
Base.close(ftp)

# check ftp errors
buff = IOBuffer()
msg = "This will go into the message"
lib_curl_error = 765
error = FTPClientError(msg, lib_curl_error)
showerror(buff, error)
seekstart(buff)
@test "$msg :: LibCURL error #$lib_curl_error" == readstring(buff)

options = RequestOptions(ssl=false, active_mode=false, hostname="not a host", username=username(server), password=password(server))
@test_throws FTPClientError ftp_connect(options)



import Compat: readstring
using FTPClient
using Base.Test

include("server/server.jl")
include("utils.jl")
# server = FTPServer()

setup_server()

# options = RequestOptions(hostname=hostname(server), username="user", passwd="passwd", ssl=false, active_mode=false)
options = RequestOptions(hostname="127.0.0.1:8000", username="user", passwd="passwd", ssl=false, active_mode=false)

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
# server_file = localpath(server, "/$local_file")  # The path to the file on the server
server_file = joinpath(ROOT, local_file)

@test !isfile(server_file)
resp = open(local_file) do fp
    ftp_put(local_file, fp, options)
end
@test isfile(server_file)
# @test readstring(server_file) == upload_file_contents***

headers = [
    "200 TYPE completed.",
    "150 File status okay; about to open data connection.",
    "226 Created file test_upload.txt.",
]

@test resp.code == 226
@test resp.bytes_recd == 0
@test is_headers_equal(resp.headers, headers)

rm(server_file)
@test !isfile(server_file)



# @testset "ftp_command" begin
#     resp = ftp_command("PWD", options)
#     @test resp.code == 257
#     @test typeof(resp.total_time) == Float64
#     @test resp.bytes_recd == 0
#     expected_header_last_part = ["200 TYPE completed.","257 \"/\" is current directory."]
#     @test resp.headers[1:4] == expected_header_first_part
#     @test ismatch(expected_header_port, resp.headers[5])
#     @test resp.headers[6:end] == expected_header_last_part ||
#         resp.headers[6:end] == [expected_header_last_part..., possible_end_to_headers]
# end

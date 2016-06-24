using LibCURL

import Base: ==

##############################
# Type definitions
##############################

type RequestOptions
    implicit::Bool
    ssl::Bool
    verify_peer::Bool
    active_mode::Bool
    username::AbstractString
    passwd::AbstractString
    url::AbstractString
    hostname::AbstractString

    function RequestOptions(;implicit::Bool=false, ssl::Bool=false,
            verify_peer::Bool=true, active_mode::Bool=false, username::AbstractString="",
            passwd::AbstractString="", url::AbstractString="", hostname::AbstractString="localhost")

        if isempty(url)
            if implicit
                url = "ftps://$hostname/"
            else
                url = "ftp://$hostname/"
            end
        end

        new(implicit, ssl, verify_peer, active_mode, username, passwd, url, hostname)
    end
end

type Response
    body::IO
    headers::Array{AbstractString}
    code::UInt
    total_time::Float64
    bytes_recd::Int

    Response() = new(IOBuffer(), AbstractString[], 0, 0.0, 0)
end

function show(io::IO, o::Response)
    println(io, "Response Code :", o.code)
    println(io, "Request Time  :", o.total_time)
    println(io, "Headers       :", o.headers)
    println(io, "Length of body: ", o.bytes_recd)
end

type ReadData
    src::IO
    offset::Csize_t
    sz::Csize_t

    ReadData() = new(IOBuffer(), 0, 0)
end

type WriteData
    buffer::IO
    bytes_recd::Int

    WriteData() = new(IOBuffer(), 0)
end

type ConnContext
    curl::Ptr{CURL}
    url::AbstractString
    options::RequestOptions

    ConnContext(options::RequestOptions) = new(C_NULL, options.url, options)
end


##############################
# Callbacks
##############################

function write_file_cb(buff::Ptr{UInt8}, sz::Csize_t, n::Csize_t, p_wd::Ptr{Void})
    # println("@write_file_cb")
    wd = unsafe_pointer_to_objref(p_wd)
    nbytes = sz * n

    unsafe_write(wd.buffer, buff, nbytes)

    wd.bytes_recd += nbytes

    nbytes::Csize_t
end

c_write_file_cb = cfunction(write_file_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Void}))

function header_command_cb(buff::Ptr{UInt8}, sz::Csize_t, n::Csize_t, p_resp::Ptr{Void})
    # println("@header_cb")
    resp = unsafe_pointer_to_objref(p_resp)
    nbytes = sz * n
    hdrlines = split(bytestring(buff, convert(Int, nbytes)), "\r\n")

    hdrlines = filter(line -> ~isempty(line), hdrlines)
    @assert typeof(resp) == Response
    append!(resp.headers, hdrlines)

    nbytes::Csize_t
end

c_header_command_cb = cfunction(header_command_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Void}))

function curl_read_cb(out::Ptr{Void}, s::Csize_t, n::Csize_t, p_rd::Ptr{Void})
    # println("@curl_read_cb")
    rd = unsafe_pointer_to_objref(p_rd)
    bavail::Csize_t = s * n
    breq::Csize_t = rd.sz - rd.offset
    b2copy = bavail > breq ? breq : bavail

    b_read = read(rd.src, UInt8, b2copy)
    ccall(:memcpy, Ptr{Void}, (Ptr{Void}, Ptr{Void}, UInt), out, b_read, b2copy)

    rd.offset += b2copy

    r = convert(Csize_t, b2copy)
    r::Csize_t
end

c_curl_read_cb = cfunction(curl_read_cb, Csize_t, (Ptr{Void}, Csize_t, Csize_t, Ptr{Void}))


##############################
# Utility functions
##############################

macro ce_curl(f, args...)
    quote
        cc = CURLE_OK
        cc = $(esc(f))(ctxt.curl, $(args...))

        if(cc != CURLE_OK && cc != CURLE_FTP_COULDNT_RETR_FILE)
            throw(FTPClientError("", cc))
        end
    end
end

function setup_easy_handle(options::RequestOptions)
    ctxt = ConnContext(options)

    curl = curl_easy_init()
    if (curl == C_NULL) throw("curl_easy_init() failed") end

    ctxt.curl = curl

    p_ctxt = pointer_from_objref(ctxt)

    ctxt.url = options.url

    @ce_curl curl_easy_setopt CURLOPT_URL options.url
    # @ce_curl curl_easy_setopt CURLOPT_VERBOSE Int64(1)

    if (~isempty(options.username) && ~isempty(options.passwd))
        @ce_curl curl_easy_setopt CURLOPT_USERNAME options.username
        @ce_curl curl_easy_setopt CURLOPT_PASSWORD options.passwd
    end

    if options.ssl
        @ce_curl curl_easy_setopt CURLOPT_USE_SSL CURLUSESSL_ALL
        @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYHOST Int64(2)
        @ce_curl curl_easy_setopt CURLOPT_FTPSSLAUTH CURLFTPAUTH_SSL

        if ~options.verify_peer
            @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYPEER Int64(0)
        else
            @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYPEER Int64(1)
        end
    end

    if options.active_mode
        @ce_curl curl_easy_setopt CURLOPT_FTPPORT "-"
    end

    return ctxt
end

function cleanup_easy_context(ctxt::ConnContext)
    if (ctxt.curl != C_NULL)

        # cleaning up should not write any data
        @ce_curl curl_easy_setopt CURLOPT_WRITEFUNCTION C_NULL
        @ce_curl curl_easy_setopt CURLOPT_WRITEDATA C_NULL

        @ce_curl curl_easy_setopt CURLOPT_HEADERFUNCTION C_NULL
        @ce_curl curl_easy_setopt CURLOPT_HEADERDATA C_NULL

        curl_easy_cleanup(ctxt.curl)
        ctxt.curl = C_NULL
    end
end

function process_response(ctxt::ConnContext, resp::Response)
    resp_code = Array(Int,1)
    @ce_curl curl_easy_getinfo CURLINFO_RESPONSE_CODE resp_code

    total_time = Array(Float64,1)
    @ce_curl curl_easy_getinfo CURLINFO_TOTAL_TIME total_time

    resp.code = resp_code[1]
    resp.total_time = total_time[1]
end


##############################
# Library initializations
##############################

@doc """
Global libcurl initialisation
""" ->
ftp_init() = curl_global_init(CURL_GLOBAL_ALL)

@doc """
Global libcurl cleanup
""" ->
ftp_cleanup() = curl_global_cleanup()


##############################
# GET
##############################

@doc """
Download file with non-persistent connection.

- url: FTP server, ex "localhost"
- file_name: name of file to download
- options: options for connection, ex use ssl, implicit security, etc.
- save_path: location to save file to, if not specified file is written to a buffer

returns resp::Response
""" ->
function ftp_get(file_name::AbstractString, options::RequestOptions=RequestOptions(), save_path::AbstractString=""; mode::FTP_MODE=binary_mode)
    ctxt = setup_easy_handle(options)
    try
        return ftp_get(ctxt, file_name, save_path; mode=mode)
    finally
        cleanup_easy_context(ctxt)
    end
end

@doc """
Download file with persistent connection.

- ctxt: open connection to FTP server
- file_name: name of file to download
- save_path: location to save file to, if not specified file is written to a buffer

returns resp::Response
""" ->
function ftp_get(ctxt::ConnContext, file_name::AbstractString, save_path::AbstractString=""; mode::FTP_MODE=binary_mode)
    resp = Response()
    wd = WriteData()

    if ~isempty(save_path)
        wd.buffer = open(save_path, "w")
    end

    try

        p_wd = pointer_from_objref(wd)
        p_resp = pointer_from_objref(resp)


        @ce_curl curl_easy_setopt CURLOPT_WRITEFUNCTION c_write_file_cb
        @ce_curl curl_easy_setopt CURLOPT_WRITEDATA p_wd

        @ce_curl curl_easy_setopt CURLOPT_HEADERFUNCTION c_header_command_cb
        @ce_curl curl_easy_setopt CURLOPT_HEADERDATA p_resp

        @ce_curl curl_easy_setopt CURLOPT_PROXY_TRANSFER_MODE Int64(1)

        full_url = ctxt.url * file_name
        if mode == binary_mode
            @ce_curl curl_easy_setopt CURLOPT_URL full_url * ";type=i"
        elseif mode == ascii_mode
            @ce_curl curl_easy_setopt CURLOPT_URL full_url * ";type=a"
        end

        @ce_curl curl_easy_perform
        process_response(ctxt, resp)

        if isopen(wd.buffer)
            seekstart(wd.buffer)
        end

        @ce_curl curl_easy_setopt CURLOPT_URL ctxt.url

        # Set it back to default
        @ce_curl curl_easy_setopt CURLOPT_PROXY_TRANSFER_MODE Int64(0)

        resp.bytes_recd = wd.bytes_recd
        resp.body = wd.buffer

        return resp

    finally
        if ~isempty(save_path)
            close(wd.buffer)
        end
    end
end

##############################
# PUT
##############################

@doc """
Upload file with non-persistent connection.

- url: FTP server, ex "localhost"
- ctxt: open connection to FTP server
- file_name: name of file to upload
- file: the file to upload
- options: options for connection, ex use ssl, implicit security, etc.

returns resp::Response
""" ->
function ftp_put(file_name::AbstractString, file::IO, options::RequestOptions=RequestOptions(); mode::FTP_MODE=binary_mode)
    ctxt = setup_easy_handle(options)
    try
        return ftp_put(ctxt, file_name, file; mode=mode)
    finally
        cleanup_easy_context(ctxt)
    end
end

@doc """
Upload file with persistent connection.

- ctxt: open connection to FTP server
- file_name: name of file to upload
- file: the file to upload

returns resp::Response
""" ->
function ftp_put(ctxt::ConnContext, file_name::AbstractString, file::IO; mode::FTP_MODE=binary_mode)
    resp = Response()
    rd = ReadData()

    rd.src = file
    seekend(file)
    rd.sz = position(file)
    seekstart(file)

    p_rd = pointer_from_objref(rd)
    p_resp = pointer_from_objref(resp)

    @ce_curl curl_easy_setopt CURLOPT_UPLOAD Int64(1)
    @ce_curl curl_easy_setopt CURLOPT_READDATA p_rd
    @ce_curl curl_easy_setopt CURLOPT_READFUNCTION c_curl_read_cb

    @ce_curl curl_easy_setopt CURLOPT_HEADERFUNCTION c_header_command_cb
    @ce_curl curl_easy_setopt CURLOPT_HEADERDATA p_resp

    @ce_curl curl_easy_setopt CURLOPT_URL ctxt.url * file_name

    if mode == binary_mode
        @ce_curl curl_easy_setopt CURLOPT_TRANSFERTEXT Int64(0)
    elseif mode == ascii_mode
        @ce_curl curl_easy_setopt CURLOPT_TRANSFERTEXT Int64(1)
    end

    @ce_curl curl_easy_setopt CURLOPT_INFILESIZE Int64(rd.sz)

    @ce_curl curl_easy_perform
    process_response(ctxt, resp)

    # resest handle defaults
    @ce_curl curl_easy_setopt CURLOPT_URL ctxt.url
    @ce_curl curl_easy_setopt CURLOPT_UPLOAD Int64(0)
    @ce_curl curl_easy_setopt CURLOPT_TRANSFERTEXT Int64(0)

    return resp
end


##############################
# COMMAND
##############################

@doc """
Pass FTP command with non-persistent connection.

- url: FTP server, ex "localhost"
- cmd: FTP command to execute
- options: options for connection, ex use ssl, implicit security, etc.

returns resp::Response
""" ->
function ftp_command(cmd::AbstractString, options::RequestOptions=RequestOptions())
    ctxt = setup_easy_handle(options)
    try
        return ftp_command(ctxt, cmd)
    finally
        cleanup_easy_context(ctxt)
    end
end

@doc """
Pass FTP command with persistent connection.

- ctxt: open connection to FTP server
- cmd: FTP command to execute

returns resp::Response
""" ->
function ftp_command(ctxt::ConnContext, cmd::AbstractString)
    resp = Response()
    wd = WriteData()
    p_wd = pointer_from_objref(wd)

    resp = Response()
    p_resp = pointer_from_objref(resp)

    @ce_curl curl_easy_setopt CURLOPT_WRITEFUNCTION c_write_file_cb
    @ce_curl curl_easy_setopt CURLOPT_WRITEDATA p_wd

    @ce_curl curl_easy_setopt CURLOPT_HEADERFUNCTION c_header_command_cb
    @ce_curl curl_easy_setopt CURLOPT_HEADERDATA p_resp

    @ce_curl curl_easy_setopt CURLOPT_CUSTOMREQUEST cmd

    @ce_curl curl_easy_perform
    process_response(ctxt, resp)

    resp.body = seekstart(wd.buffer)
    resp.bytes_recd = wd.bytes_recd

    cmd = split(cmd)
    if (resp.code == 250 && cmd[1] == "CWD")
        ctxt.url *= join(cmd[2:end], ' ')
    end

    return resp
end


##############################
# CONNECT
##############################

@doc """
Establish connection to FTP server.

- url: FTP server, ex "localhost"
- options: options for connection, ex use ssl, implicit security, etc.

returns ctxt::ConnContext
""" ->
function ftp_connect(options::RequestOptions=RequestOptions())
    ctxt = setup_easy_handle(options)
    try
        # ping the server
        resp = ftp_command(ctxt, "LIST")

        return ctxt, resp
    catch
        cleanup_easy_context(ctxt)
        rethrow()
    end
end


##############################
# CLOSE
##############################

@doc """
Close connection FTP server.

- ctxt: connection to clean up
""" ->
function ftp_close_connection(ctxt::ConnContext)
    cleanup_easy_context(ctxt)
end


##############################
# ISEQUAL
##############################

function ==(this::RequestOptions, other::RequestOptions)
    return this.implicit == other.implicit &&
        this.ssl == other.ssl &&
        this.verify_peer == other.verify_peer &&
        this.active_mode == other.active_mode &&
        this.username == other.username &&
        this.passwd == other.passwd &&
        this.url == other.url &&
        this.hostname == other.hostname
end

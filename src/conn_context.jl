"""
    ConnContext

Keeps track of a persistent FTP connection.

# Arguments
- `url::AbstractString`: url of the FTP server.
- `options::RequestOptions`: the options used for the connection.

# Keywords
- `verbose::Union{IOStream,Bool}=false`: an `IOStream` to capture LibCURL's output or a
  `Bool`, if true output is written to STDERR.
"""
mutable struct ConnContext{T <: Union{IOStream,Bool}}
    curl::Ptr{CURL}
    url::String  # Avoid using an abstract type when interacting with C libraries
    options::RequestOptions
    verbose::T

    function ConnContext(options::RequestOptions; verbose::T=false) where T <: Union{IOStream,Bool}
        new{T}(C_NULL, trailing(string(options.uri), '/'), options, verbose)
    end
end

mutable struct ReadData
    src::IO
    offset::Csize_t
    sz::Csize_t

    ReadData() = new(IOBuffer(), 0, 0)
end

mutable struct WriteData
    buffer::IO
    bytes_recd::Int

    WriteData() = new(IOBuffer(), 0)
end


function url(ctxt::ConnContext)
    # Set ftpes protocol to ftp in the url so that libcurl can understand it
    url = ctxt.options.ssl ? replace(ctxt.url, "ftpes://" => "ftp://") : ctxt.url
end

function setup_easy_handle(ctxt::ConnContext)
    curl = curl_easy_init()
    curl == C_NULL && error("curl_easy_init() failed")

    ctxt.curl = curl

    p_ctxt = pointer_from_objref(ctxt)

    @ce_curl curl_easy_setopt CURLOPT_URL url(ctxt)
    # @ce_curl curl_easy_setopt CURLOPT_VERBOSE Int64(1)

    if ctxt.options.ssl
        @ce_curl curl_easy_setopt CURLOPT_USE_SSL CURLUSESSL_ALL
        @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYHOST Int64(2)
        @ce_curl curl_easy_setopt CURLOPT_FTPSSLAUTH CURLFTPAUTH_SSL
        @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYPEER Int64(ctxt.options.verify_peer)
    end

    if ctxt.options.active_mode
        @ce_curl curl_easy_setopt CURLOPT_FTPPORT "-"
    end

    return ctxt
end

function cleanup_easy_context(ctxt::ConnContext)
    ctxt.curl == C_NULL && return nothing

    # cleaning up should not write any data
    @ce_curl curl_easy_setopt CURLOPT_WRITEFUNCTION C_NULL
    @ce_curl curl_easy_setopt CURLOPT_WRITEDATA C_NULL

    @ce_curl curl_easy_setopt CURLOPT_HEADERFUNCTION C_NULL
    @ce_curl curl_easy_setopt CURLOPT_HEADERDATA C_NULL

    @ce_curl curl_easy_setopt CURLOPT_READDATA C_NULL
    @ce_curl curl_easy_setopt CURLOPT_READFUNCTION C_NULL

    curl_easy_cleanup(ctxt.curl)
    ctxt.curl = C_NULL
end

function process_response(ctxt::ConnContext, resp::Response)
    resp_code = Int[1]
    @ce_curl curl_easy_getinfo CURLINFO_RESPONSE_CODE resp_code

    total_time = Float64[1.0]
    @ce_curl curl_easy_getinfo CURLINFO_TOTAL_TIME total_time

    resp.code = resp_code[1]
    resp.total_time = total_time[1]
end

"""
    ftp_get(
        ctxt::ConnContext,
        file_name::AbstractString,
        save_path::AbstractString="";
        mode::FTP_MODE=binary_mode,
    )

Download a file with a persistent connection. Returns a `Response`.

# Arguments
* `ctxt::ConnContext`: encompasses the connection options defined via ftp_connect. See
    `RequestOptions` for details.
* `file_name::AbstractString`: the path to the file on the server.
* `save_path::AbstractString=""`: if not specified the file is written to the `Response`
    body.
* `mode::FTP_MODE=binary_mode`: defines whether the file is transferred in binary or
    ASCII format.
"""
function ftp_get(
    ctxt::ConnContext,
    file_name::AbstractString,
    save_path::AbstractString="";
    mode::FTP_MODE=binary_mode,
)
    wd = WriteData()

    if !isempty(save_path)
        wd.buffer = open(save_path, "w")
    end

    try
        p_wd = pointer_from_objref(wd)

        # Force active mode
        #@ce_curl curl_easy_setopt CURLOPT_FTP_USE_EPSV 0
        #@ce_curl curl_easy_setopt CURLOPT_FTP_USE_EPRT 0
        #@ce_curl curl_easy_setopt CURLOPT_FTPPORT "-"

        @ce_curl curl_easy_setopt CURLOPT_WRITEFUNCTION C_WRITE_FILE_CB[]
        @ce_curl curl_easy_setopt CURLOPT_WRITEDATA p_wd

        @ce_curl curl_easy_setopt CURLOPT_PROXY_TRANSFER_MODE Int64(1)

        ftp_url = url(ctxt)
        full_url = ftp_url * file_name
        if mode == binary_mode
            @ce_curl curl_easy_setopt CURLOPT_URL full_url * ";type=i"
        elseif mode == ascii_mode
            @ce_curl curl_easy_setopt CURLOPT_URL full_url * ";type=a"
        end

        resp = ftp_perform(ctxt)

        if isopen(wd.buffer)
            seekstart(wd.buffer)
        end

        @ce_curl curl_easy_setopt CURLOPT_URL ftp_url

        # Set it back to default
        @ce_curl curl_easy_setopt CURLOPT_PROXY_TRANSFER_MODE Int64(0)

        resp.bytes_recd = wd.bytes_recd
        resp.body = wd.buffer

        return resp
    finally
        if !isempty(save_path)
            close(wd.buffer)
        end
    end
end


"""
    ftp_put(
        ctxt::ConnContext,
        file_name::AbstractString,
        file::IO;
        mode::FTP_MODE=binary_mode,
    )

Upload file with persistent connection. Returns a `Response`.

# Arguments
* `ctxt::ConnContext`: encompases the connection options defined via ftp_connect. See
    `RequestOptions` for details.
* `file_name::AbstractString`: the path to the file on the server.
* `file::IO`: what is being written to the server.
* `mode::FTP_MODE=binary_mode`: defines whether the file is transferred in binary or
    ASCII format.
"""
function ftp_put(
    ctxt::ConnContext,
    file_name::AbstractString,
    file::IO;
    mode::FTP_MODE=binary_mode,
)
    rd = ReadData()

    rd.src = file
    seekend(file)
    rd.sz = position(file)
    seekstart(file)

    p_rd = pointer_from_objref(rd)

    @ce_curl curl_easy_setopt CURLOPT_UPLOAD Int64(1)
    @ce_curl curl_easy_setopt CURLOPT_READDATA p_rd
    @ce_curl curl_easy_setopt CURLOPT_READFUNCTION C_CURL_READ_CB[]

    ftp_url = url(ctxt)
    @ce_curl curl_easy_setopt CURLOPT_URL ftp_url * file_name

    if mode == binary_mode
        @ce_curl curl_easy_setopt CURLOPT_TRANSFERTEXT Int64(0)
    elseif mode == ascii_mode
        @ce_curl curl_easy_setopt CURLOPT_TRANSFERTEXT Int64(1)
    end

    @ce_curl curl_easy_setopt CURLOPT_INFILESIZE Int64(rd.sz)

    resp = ftp_perform(ctxt)

    # resest handle defaults
    @ce_curl curl_easy_setopt CURLOPT_URL ftp_url
    @ce_curl curl_easy_setopt CURLOPT_UPLOAD Int64(0)
    @ce_curl curl_easy_setopt CURLOPT_TRANSFERTEXT Int64(0)

    return resp
end

"""
    ftp_command(
        ctxt::ConnContext,
        cmd::AbstractString
    )

Pass FTP command with persistent connection. Returns a `Response`.
"""
function ftp_command(ctxt::ConnContext, cmd::AbstractString)
    wd = WriteData()
    p_wd = pointer_from_objref(wd)

    @ce_curl curl_easy_setopt CURLOPT_CUSTOMREQUEST cmd

    @ce_curl curl_easy_setopt CURLOPT_WRITEFUNCTION C_WRITE_FILE_CB[]
    @ce_curl curl_easy_setopt CURLOPT_WRITEDATA p_wd

    resp = ftp_perform(ctxt)

    resp.body = seekstart(wd.buffer)
    resp.bytes_recd = wd.bytes_recd

    parts = split(cmd, ' ', limit=2)
    if resp.code == 250 && parts[1] == "CWD"
        ctxt.url *= trailing(parts[2], '/')
    end

    return resp
end

"""
    ftp_close_connection(ctxt::ConnContext)

Close the connection to the FTP server.
"""
function ftp_close_connection(ctxt::ConnContext)
    cleanup_easy_context(ctxt)
    nothing
end


function ftp_perform(ctxt::ConnContext)
    resp = Response()
    p_resp = pointer_from_objref(resp)

    @ce_curl curl_easy_setopt CURLOPT_HEADERFUNCTION C_HEADER_COMMAND_CB[]
    @ce_curl curl_easy_setopt CURLOPT_HEADERDATA p_resp

    libc_file = nothing
    if ctxt.verbose != false
        @ce_curl curl_easy_setopt CURLOPT_VERBOSE Int64(1)
        if isa(ctxt.verbose, IOStream)

            # flush the IOStream before making a duplicate Libc.FILE that will
            # capture the verbose
            flush(ctxt.verbose)
            libc_file = Libc.FILE(ctxt.verbose)

            @ce_curl curl_easy_setopt CURLOPT_STDERR libc_file.ptr
        end
    else
        @ce_curl curl_easy_setopt CURLOPT_VERBOSE Int64(0)
    end

    try
        @ce_curl curl_easy_perform
        process_response(ctxt, resp)
    finally
        if isa(libc_file, Libc.FILE)
            # Need to flush the Libc.FILE to make sure content is written, closing the
            # Libc.FILE does not reliably do this. Then update the IOStream pointer to
            # point to the same position so that data can be appended to the stream.
            ccall(:fflush, Cvoid, (Ptr{Cvoid},), libc_file.ptr)
            seek(ctxt.verbose, position(libc_file))
            close(libc_file)

            @ce_curl curl_easy_setopt CURLOPT_STDERR Libc.FILE(RawFD(2), "w").ptr
        end
    end

    return resp
end

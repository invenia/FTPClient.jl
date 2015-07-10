module FTPClient

using LibCURL
using Debug

import Base.convert, Base.show

export RequestOptions, Response
export init, cleanup, open, get, put

##############################
# Type definitions
##############################

type RequestOptions
    blocking::Bool
    isImplicit::Bool
    isSSL::Bool
    verify_peer::Bool
    headers::Vector{Tuple}
    username::String
    passwd::String

    RequestOptions(; blocking=true, isImplicit=false, isSSL=false, verify_peer=true, headers=Array(Tuple, 0), username="", passwd="") = new(blocking, isImplicit, isSSL, verify_peer, headers, username, passwd)
end

type Response
    body
    headers::Dict{String, Vector{Tuple}}
    code::Int
    total_time
    bytes_recd::Int

    Response() = new(nothing, Dict{String, Vector{String}}(), 0, 0.0, 0)
end

function show(io::IO, o::Response)
    println(io, "Response Code :", o.code)
    println(io, "Request Time  :", o.total_time)
    println(io, "Headers       :")
    for (k,vs) in o.headers
        for v in vs
            println(io, "    $k : $v")
        end
    end

    println(io, "Length of body: ", o.bytes_recd)
end

type ReadData
    typ::Symbol
    src::Any
    str::String
    offset::Csize_t
    sz::Csize_t

    ReadData() = new(:undefined, false, "", 0, 0)
end

type ConnContext
    curl::Ptr{CURL}
    url::String
    rd::ReadData
    resp::Response
    options::RequestOptions
    close_ostream::Bool

    ConnContext(options::RequestOptions) = new(C_NULL, "", ReadData(), Response(), options, false)
end

immutable CURLMsg2
  msg::CURLMSG
  easy_handle::Ptr{CURL}
  data::Ptr{Any}
end


##############################
# Callbacks
##############################

@debug function write_cb(buff::Ptr{Uint8}, sz::Csize_t, n::Csize_t, p_ctxt::Ptr{Void})
    println("@write_cb")
    ctxt = unsafe_pointer_to_objref(p_ctxt)
    nbytes = sz * n
    @bp
    if (ctxt.resp.bytes_recd !=0 )
        write(ctxt.resp.body, buff, nbytes)
        ctxt.resp.bytes_recd = ctxt.resp.bytes_recd + nbytes
    end

    nbytes::Csize_t
end

c_write_cb = cfunction(write_cb, Csize_t, (Ptr{Uint8}, Csize_t, Csize_t, Ptr{Void}))

function header_cb(buff::Ptr{Uint8}, sz::Csize_t, n::Csize_t, p_ctxt::Ptr{Void})
    println("@header_cb")
    ctxt = unsafe_pointer_to_objref(p_ctxt)
    hdrlines = split(bytestring(buff, convert(Int, sz * n)), "\r\n")

   println(hdrlines)
    for e in hdrlines
        m = match(r"^\s*([\w\-\_]+)\s*\:(.+)", e)
        if (m != nothing)
            k = strip(m.captures[1])
            v = strip(m.captures[2])
            if haskey(ctxt.resp.headers, k)
                push!(ctxt.resp.headers[k], v)
            else
                ctxt.resp.headers[k] = (String)[v]
            end
        end
    end
    (sz*n)::Csize_t
end

c_header_cb = cfunction(header_cb, Csize_t, (Ptr{Uint8}, Csize_t, Csize_t, Ptr{Void}))

function curl_read_cb(out::Ptr{Void}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Void})
   println("@curl_read_cb")

    ctxt = unsafe_pointer_to_objref(p_ctxt)
    bavail::Csize_t = s * n
    breq::Csize_t = ctxt.rd.sz - ctxt.rd.offset
    b2copy = bavail > breq ? breq : bavail

    if (ctxt.rd.typ == :buffer)
        ccall(:memcpy, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Uint),
                out, convert(Ptr{Uint8}, pointer(ctxt.rd.str)) + ctxt.rd.offset, b2copy)
    elseif (ctxt.rd.typ == :io)
        b_read = read(ctxt.rd.src, Uint8, b2copy)
        ccall(:memcpy, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Uint), out, b_read, b2copy)
    end
    ctxt.rd.offset = ctxt.rd.offset + b2copy

    r = convert(Csize_t, b2copy)
    r::Csize_t
end

c_curl_read_cb = cfunction(curl_read_cb, Csize_t, (Ptr{Void}, Csize_t, Csize_t, Ptr{Void}))

function curl_multi_timer_cb(curlm::Ptr{Void}, timeout_ms::Clong, p_muctxt::Ptr{Void})
    muctxt = unsafe_pointer_to_objref(p_muctxt)
    muctxt.timeout = timeout_ms / 1000.0

    println("Requested timeout value : " * string(muctxt.timeout))

    ret = convert(Cint, 0)
    ret::Cint
end

c_curl_multi_timer_cb = cfunction(curl_multi_timer_cb, Cint, (Ptr{Void}, Clong, Ptr{Void}))


##############################
# Utility functions
##############################

macro ce_curl (f, args...)
    quote
        cc = CURLE_OK
        cc = $(esc(f))(ctxt.curl, $(args...))

        if(cc != CURLE_OK)
            error (string($f) * "() failed: error $cc, " * bytestring(curl_easy_strerror(cc)))
        end
    end
end

# macro ce_curlm (f, args...)
#     quote
#         cc = CURLM_OK
#         cc = $(esc(f))(curlm, $(args...))

#         if(cc != CURLM_OK)
#             error (string($f) * "() failed: error $cc, " * bytestring(curl_multi_strerror(cc)))
#         end
#     end
# end

null_cb(curl) = return nothing

function set_opt_blocking(options::RequestOptions)
        o2 = deepcopy(options)
        o2.blocking = true
        return o2
end

function setup_easy_handle(url, options::RequestOptions)
    ctxt = ConnContext(options)

    curl = curl_easy_init()
    if (curl == C_NULL) throw("curl_easy_init() failed") end

    ctxt.curl = curl

    ctxt.url = url

    p_ctxt = pointer_from_objref(ctxt)


    @ce_curl curl_easy_setopt CURLOPT_URL url
    # @ce_curl curl_easy_setopt CURLOPT_WRITEFUNCTION c_write_cb
    # @ce_curl curl_easy_setopt CURLOPT_WRITEDATA p_ctxt
    @ce_curl curl_easy_setopt CURLOPT_VERBOSE Int64(1)

    if options.isSSL
        @ce_curl curl_easy_setopt CURLOPT_USE_SSL CURLUSESSL_ALL
        @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYPEER Int64(0)
        @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYHOST Int64(2)
        @ce_curl curl_easy_setopt CURLOPT_SSLVERSION Int64(0)
        @ce_curl curl_easy_setopt CURLOPT_FTPSSLAUTH CURLFTPAUTH_SSL

        if ~options.verify_peer
            @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYPEER Int64(0)
        else
            @ce_curl curl_easy_setopt CURLOPT_SSL_VERIFYPEER Int64(1)
        end
    end

    return ctxt
end

function cleanup_easy_context(ctxt::Union(ConnContext,Bool))
    if isa(ctxt, ConnContext)

        if (ctxt.curl != C_NULL)
            curl_easy_cleanup(ctxt.curl)
        end

        if ctxt.close_ostream
            close(ctxt.resp.body)
            ctxt.resp.body = nothing
            ctxt.close_ostream = false
        end
    end
end

function process_response(ctxt)
    resp_code = Array(Int,1)
    @ce_curl curl_easy_getinfo CURLINFO_RESPONSE_CODE resp_code

    total_time = Array(Float64,1)
    @ce_curl curl_easy_getinfo CURLINFO_TOTAL_TIME total_time

    ctxt.resp.code = resp_code[1]
    ctxt.resp.total_time = total_time[1]
end


##############################
# Library initializations
##############################

init() = curl_global_init(CURL_GLOBAL_ALL)
cleanup() = curl_global_cleanup()


##############################
# GET
##############################

function get(url::String, options::RequestOptions=RequestOptions())
    if (options.blocking)
        ctxt = false
        try
            ctxt = setup_easy_handle(url, options)

            @ce_curl curl_easy_setopt CURLOPT_HTTPGET 1

            return exec_as_multi(ctxt)
        finally
            cleanup_easy_context(ctxt)
        end
    else
        return remotecall(myid(), get, url, set_opt_blocking(options))
    end
end


##############################
# OPEN
##############################

@debug function open(url::String, options::RequestOptions=RequestOptions())
    if (options.blocking)
        ctxt = false
        try
            @bp
            ctxt = setup_easy_handle(url, options)

            if (~isempty(options.username) && ~isempty(options.passwd))
                @ce_curl curl_easy_setopt  CURLOPT_USERNAME options.username
                @ce_curl curl_easy_setopt  CURLOPT_PASSWORD options.passwd
            end

            @ce_curl curl_easy_perform

            return ctxt.resp
        finally
            cleanup_easy_context(ctxt)
        end
    else
        # Todo: figure out non-blocking
    end
end


##############################
# COMMAND
##############################

@debug function command(url::String, options::RequestOptions=RequestOptions(), command::AbstractString = "LIST")
    if (options.blocking)
        ctxt = false
        try
            ctxt = setup_easy_handle(url, options)

            if (~isempty(options.username) && ~isempty(options.passwd))
                @ce_curl curl_easy_setopt  CURLOPT_USERNAME options.username
                @ce_curl curl_easy_setopt  CURLOPT_PASSWORD options.passwd
            end

            @bp
            @ce_curl curl_easy_setopt CURLOPT_CUSTOMREQUEST command

            @ce_curl curl_easy_perform

            return ctxt.resp
        finally
            cleanup_easy_context(ctxt)
        end
    else
        # Todo: figure out non-blocking
    end
end

end #module



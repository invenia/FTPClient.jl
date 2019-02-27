using LibCURL


##############################
# Callbacks
##############################

function write_file_cb(buff::Ptr{UInt8}, sz::Csize_t, n::Csize_t, p_wd::Ptr{Cvoid})
    # println("@write_file_cb")
    wd = unsafe_pointer_to_objref(p_wd)
    nbytes = sz * n

    unsafe_write(wd.buffer, buff, nbytes)

    wd.bytes_recd += nbytes

    nbytes::Csize_t
end

function header_command_cb(buff::Ptr{UInt8}, sz::Csize_t, n::Csize_t, p_resp::Ptr{Cvoid})
    # println("@header_cb")
    resp = unsafe_pointer_to_objref(p_resp)
    nbytes = sz * n
    hdrlines = split(unsafe_string(buff, convert(Int, nbytes)), "\r\n")

    hdrlines = filter(line -> !isempty(line), hdrlines)
    @assert typeof(resp) == Response
    append!(resp.headers, hdrlines)

    nbytes::Csize_t
end

function curl_read_cb(out::Ptr{Cvoid}, s::Csize_t, n::Csize_t, p_rd::Ptr{Cvoid})
    # println("@curl_read_cb")
    rd = unsafe_pointer_to_objref(p_rd)
    bavail::Csize_t = s * n
    breq::Csize_t = rd.sz - rd.offset
    b2copy = bavail > breq ? breq : bavail

    b_read = Array{UInt8}(undef, b2copy)
    read!(rd.src, b_read)

    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt), out, b_read, b2copy)

    rd.offset += b2copy

    r = convert(Csize_t, b2copy)
    r::Csize_t
end


##############################
# Utility functions
##############################

macro ce_curl(f, args...)
    quote
        cc = CURLE_OK
        cc = $(esc(f))($(esc(:(ctxt.curl))), $(map(esc, args)...))

        if cc != CURLE_OK && cc != CURLE_FTP_COULDNT_RETR_FILE
            throw(FTPClientError("", cc))
        end
    end
end

##############################
# Library initializations
##############################

"""
    ftp_init()

Initialise global libcurl
"""
ftp_init() = curl_global_init(CURL_GLOBAL_ALL)

"""
    ftp_cleanup()

Cleanup global libcurl.
"""
ftp_cleanup() = curl_global_cleanup()

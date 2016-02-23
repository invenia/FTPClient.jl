facts("Non-blocking tests") do

ftp_init()

expected_list = [directory_name, file_name]

context("Non-persistent connection tests, passive mode") do

    options = RequestOptions(blocking=false, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)

    rcall = ftp_get(file_name, options)
    resp = fetch(rcall)
    @fact resp.code --> 226

    file = open(upload_file)
    rcall = ftp_put("test_upload.txt", file, options)
    resp = fetch(rcall)
    @fact resp.code --> 226
    close(file)

end

context("Persistent connection tests, active mode") do

    options = RequestOptions(blocking=false, ssl=false, active_mode=true, username=user, passwd=pswd, hostname=host)

    rcall = ftp_connect(options)
    ctxt, resp = fetch(rcall)
    @fact resp.code --> 226

    rcall = ftp_get(ctxt, file_name)
    resp = fetch(rcall)
    @fact resp.code --> 226

    file = open(upload_file)
    rcall = ftp_put(ctxt, "test_upload.txt", file)
    resp = fetch(rcall)
    @fact resp.code --> 226

    ftp_close_connection(ctxt)
    close(file)

end

context("Changed directory and get file") do

    options = RequestOptions(blocking=false, ssl=false, username=user, passwd=pswd, hostname=host)

    rcall = ftp_connect(options)
    ctxt, resp = fetch(rcall)
    @fact resp.code --> 226
    @compat text = readstring(resp.body)
    for expected in expected_list
        @fact contains(text, expected) --> true "$expected is not in text\n$text"
    end

    resp = ftp_command(ctxt, "CWD $directory_name/")
    @fact resp.code --> 250

    rcall = ftp_get(ctxt, file_name2)
    resp = fetch(rcall)
    @fact resp.code --> 226

    ftp_close_connection(ctxt)

end

ftp_cleanup()

println("\nNon-blocking tests passed.\n")

end

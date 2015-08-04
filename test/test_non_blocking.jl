using FTPClient
using Base.Test
using FactCheck

facts("Non-blocking tests") do

ftp_init()

expected_list = "drwxrwxrwx  1 none     none                   0 Jul 31  2015 test_directory\n" *
                "-rw-rw-rw-  1 none     none                  21 Jul 31  2015 test_upload.txt\n" *
                "-rwxrwxrwx  1 none     none                  12 Jul 31  2015 test_download.txt\n"

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
    # @fact expected_list.data --> readall(resp.body).data

    resp = ftp_command(ctxt, "CWD $directory_name/")
    @fact resp.code --> 250

    rcall = ftp_get(ctxt, file_name2)
    resp = fetch(rcall)
    @fact resp.code --> 226

end

ftp_cleanup()

println("\nNon-blocking tests passed.\n")

end

ftp_init()

facts("Test FTPClientError") do

context("ftp_connect error") do

    buff = IOBuffer()
    msg = "This will go into the message"
    lib_curl_error = 765
    error = FTPClientError(msg, lib_curl_error)
    showerror(buff, error)
    seekstart(buff)
    @compat @fact "$msg :: LibCURL error #$lib_curl_error" --> readstring(buff)

end

end

facts("Testing for client failure in FTPC.jl") do

context("ftp_connect error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname="not a host")
    @fact_throws FTPClientError ftp_connect(options)
end

context("ftp_put error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
    file = open(upload_file)
    @fact_throws FTPClientError ftp_put(upload_file, file, options)
    close(file)
end

context("ftp_get error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
    @fact_throws FTPClientError ftp_get(file_name, options)
end

context("ftp_command error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
    @fact_throws FTPClientError ftp_command("NLST", options)
end

end

facts("Testing for client failure in FTPObject.jl") do

context("FTP object error when connecting") do
    @fact_throws FTPClientError FTP(ssl=false, user=user, pswd=pswd, host="not a host")
end

context("FTP object error when downloading, blocking") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError download(ftp, file_name)
    close(ftp)
end

context("FTP object error when downloading, non-blocking") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    ref = non_block_download(ftp, file_name)
    @fact_throws RemoteException get_download_resp(ref)
    close(ftp)
end

context("FTP object error when uploading, blocking") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError upload(ftp, upload_file)
    close(ftp)
end

context("FTP object error when uploading, non-blocking") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    ref = non_block_upload(ftp, upload_file)
    @fact_throws RemoteException get_upload_resp(ref)
    close(ftp)
end

context("FTP object error when changing working directory") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError cd(ftp, testdir)
    close(ftp)
end

context("FTP object error when getting path of working directory") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError pwd(ftp)
    close(ftp)
end

context("FTP object error when removing a file that doesn't exist") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError rm(ftp, "not_a_file")
    close(ftp)
end

context("FTP object error when removing a directory that doesn't exist") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError rmdir(ftp, "not_a_directory")
    close(ftp)
end

context("FTP object error when creating a bad directory") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError mkdir(ftp, "")
    close(ftp)
end

context("FTP object error when moving bad directories") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError mv(ftp, "", "")
    close(ftp)
end

context("FTP object error when moving bad directories 2") do
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    @fact_throws FTPClientError mv(ftp, file_name, "")
    close(ftp)
end

context("FTP object error when switching to binary") do
    undo_errors()
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    set_type_error()
    @fact_throws FTPClientError binary(ftp)
    close(ftp)
end

context("FTP object error when switching to ascii") do
    undo_errors()
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    set_type_error()
    @fact_throws FTPClientError ascii(ftp)
    close(ftp)
end

context("FTP object error with LIST command") do
    undo_errors()
    ftp = FTP(ssl=false, user=user, pswd=pswd, host=host)
    set_list_error()
    @fact_throws FTPClientError readdir(ftp)
    close(ftp)
end

end

ftp_cleanup()

println("FTPClientError tests passed.\n\n")

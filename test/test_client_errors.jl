facts("Testing for client failure") do

ftp_init()

context("ftp_connect error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname="not a host")
    @fact_throws ErrorException ftp_connect(options)
end

context("ftp_put error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
    file = open(upload_file)
    @fact_throws ErrorException ftp_put(upload_file, file, options)
    close(file)
end

context("ftp_get error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
    @fact_throws ErrorException ftp_get(file_name, options)
end

context("ftp_command error") do
    options = RequestOptions(blocking=true, ssl=false, active_mode=false, username=user, passwd=pswd, hostname=host)
    @fact_throws ErrorException ftp_command("LIST", options)
end

end

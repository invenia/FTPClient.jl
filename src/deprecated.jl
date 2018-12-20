using Base: @deprecate, depwarn

function _dep_verbose_kw(verbose, preferred::Type, func::Symbol)
    if verbose !== nothing
        depwarn(
            "The `verbose` keyword is deprecated and now needs to be supplied " *
            "during the initialization of `$(nameof(preferred))`.",
            func,
        )
    end
end

@deprecate(
    upload(ftp::FTP, local_name::AbstractString; kwargs...),
    upload(ftp, local_name, local_name; kwargs...)
)

function upload(
    ftp::FTP,
    local_file_paths::Vector{<:AbstractString},
    ftp_dir::AbstractString;
    retry_callback::Function=(count, options) -> (count < 4, options),
    retry_wait_seconds::Integer=5,
    verbose=nothing,
)
    depwarn(
        string(
            "Uploading multiple files to an ftp_dir with a retry callback is deprecated. ",
            "Use retry(upload, delays=fill(5, 4))",
            "(ftp, local_path, remote_path; kwargs... ) ",
            "in a loop of file_paths in the future."
        ),
        :upload
    )
    _dep_verbose_kw(verbose, typeof(ftp), :upload)

    successful_delivery = Bool[]
    ftp_options = ftp.ctxt

    for single_file in local_file_paths
        # The location we are going to drop the file in the FTP server
        server_location = joinpath(ftp_dir, basename(single_file))
        open(single_file) do single_file_io
            # Whether or not the current file was successfully delivered to the FTP
            success = false
            # Count the number of time we have tried to upload the file
            attempts = 1
            # The loops should break after an appropriate amount of retries.
            # This way of doing retries makes testing easier.
            # Defaults to 4 attempts, waiting 5 seconds between each retry.
            while true
                try
                    resp = upload(
                        ftp, single_file_io, server_location;
                        ftp_options=ftp_options, verbose=verbose
                    )
                    success = resp.code == complete_transfer_code

                    if success
                        break
                    end
                catch e
                    @warn(e)
                end
                sleep(retry_wait_seconds)
                # It returns ftp_options for testing purposes, where the ftp_server
                # starts not existing then comes into existance during retries.
                do_retry, ftp_options = retry_callback(attempts, ftp_options)
                if !do_retry
                    break
                end
                attempts += 1
            end
            push!(successful_delivery, success)
        end
    end

    return successful_delivery
end

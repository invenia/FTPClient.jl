function _dep_verbose_kw(verbose, preferred::Type, func::Symbol)
    if verbose !== nothing
        Base.depwarn(
            "The `verbose` keyword is deprecated and now needs to be supplied " *
            "during the initialization of `$(nameof(preferred))`.",
            func,
        )
    end
end

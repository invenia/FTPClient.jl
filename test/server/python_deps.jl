# this script uses the default Conda settings to get python, pyopenssl, and pyftpdlib
# if you already have an acceptable version of python and pip installed it will attempt to use those instead

using Conda
using Compat

py_version(python::AbstractString) = chomp(readstring(`$python -c "import platform; print(platform.python_version())"`))
const python = try
    py = get(ENV, "PYTHON", isfile("PYTHON") ? readchomp("PYTHON") : "python")
    version = VersionNumber(py_version(py))
    if version < v"2.7.11"
        error("Python version $version < 2.7.11 is not supported")
    elseif version >= v"3.0"
        error("Python version $version >= 3 is not supported")
    else
        run(`pip install pyopenssl`)
    end
    py
catch error
    info( "No system-wide Python was found; got the following error:\n",
          "$error\nusing the Python distribution in the Conda package")
    Conda.add("pyopenssl")
    abspath(Conda.PYTHONDIR, "python" * ( is_windows() ? ".exe" : ""))
end

pip = (dirname(python) == abspath(Conda.PYTHONDIR))? abspath(Conda.SCRIPTDIR, "pip" * ( is_windows() ? ".exe" : "")): "pip"
run(`$pip install pyftpdlib`)

open("PYTHON", "w") do f
    println(f, python)
end


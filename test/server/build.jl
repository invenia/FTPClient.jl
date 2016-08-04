using Conda
using Compat

pyconfigvar(python::AbstractString) = chomp(readstring(`$python -c "import platform; print(platform.python_version())"`))
const python = try
    py = get(ENV, "PYTHON", isfile("PYTHON") ? readchomp("PYTHON") : "python")
    vers = convert(VersionNumber, pyconfigvar(py))
    if vers < v"2.7.11"
        error("Python version $vers < 2.7.11 is not supported")
    elseif vers >= v"3.0"
        error("Python version $vers >= 3 is not supported")
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


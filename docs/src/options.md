```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")
empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, "set term unknown")
empty!(Gnuplot.options.reset)
push!( Gnuplot.options.reset, linetypes(:Set1_5, lw=2))
saveas(file) = save(term="pngcairo size 550,350 fontscale 0.8", output="assets/$(file).png")
```

# Package options and initialization

## Options
The package options are stored in a global structure available in Julia as `Gnuplot.option` (the type of the structure is [`Gnuplot.Options`](@ref)).  The most important settings are as follows:

- `dry::Bool`: if true all new sessions will be started as [Dry sessions](@ref).  Default is `false`, but if the package is not able to start a gnuplot it will automatically switch to `true`;

- `init::Vector{String}`: initialization commands to be executed when a new session is created.  Default is an empty vector.  It can be used to, e.g., set a custom terminal:
```@repl abc
push!(Gnuplot.options.init, "set term sixelgd");
```
Note that this is option affect all the newly created sessions, not the older ones.  Also note that the commands in `Gnuplot.options.init` **are not** saved in [Gnuplot scripts](@ref);

- `reset::Vector{String}`: initialization commands to be executed when a session is reset.  Default is an empty vector.  It can be used to, e.g., set custom linetypes or palette:
```@repl abc
push!(Gnuplot.options.reset, linetypes(:Set1_5, lw=2));
```
Note that this is option affect all the sessions.  Also note that the commands in `Gnuplot.options.reset` **are** saved in [Gnuplot scripts](@ref);

- `verbose::Bool`: a flag to set verbosity of the package.  In particular if it is `true` all communication with the underlying process will be printed on stdout. E.g.:
```@repl abc
empty!(Gnuplot.options.reset); # hide
gpexec("set term wxt");        # hide
Gnuplot.options.verbose = true;
x = 1.:10;
@gp x x.^2 "w l t 'Parabola'"
save(term="pngcairo size 480,360 fontscale 0.8", output="output.png")
Gnuplot.options.verbose = false # hide
push!( Gnuplot.options.reset, linetypes(:Set1_5, lw=2));  # hide
gpexec("set term unknown");                               # hide
```
Each line reports the package name (`GNUPLOT`), the session name (`default`), the command or string being sent to gnuplot process, and the returned response (line starting with `->`).  Default value is `false`;

- `cmd::String`: command to start the gnuplot process, default value is `"gnuplot"`.  If you need to specify a custom path to the gnuplot executable you may change this value;

- `default::Symbol`: default session name, i.e. the session that will be used when no session name is provided;

- `preferred_format::Symbol`: preferred format to send data to gnuplot.  Value must be one of:
   - `bin`: provides best performances for large datasets, but uses temporary files;
   - `text`: may be slow for large datasets, but no temporary file is involved;
   - `auto` (default) automatically choose the best strategy.



## Package initialization

If you use **Gnuplot.jl** frequently you may find convenient to collect all the package settings (see [Options](@ref)) in a single place, to quickly recall them in a Julia session.  I suggest to put the following code in the `.julia/config/startup.jl` initialization file (further info [here](https://docs.julialang.org/en/v1/stdlib/REPL/)):
```julia
macro gnuplotrc()
    return :(
        using Gnuplot

        # Uncomment the following if you don't have the gnuplot
        # executable installed on your platform
        #Gnuplot.options.dry = true

        # Uncomment the following and set the proper path if the
        # gnuplot executable is not in your $PATH
        #Gnuplot.options.cmd = "/path/to/gnuplot"

        # Set the default terminal for interacitve use
        push!(Gnuplot.options.init, "set term wxt size 700,400");

        # Set the default linetypes
        push!(Gnuplot.options.reset, linetypes(:Set1_5, lw=2));

        # Initialize the gnuplot REPL using the provided `start_key`.
        # Comment the following to disable the REPL.
        Gnuplot.repl_init(start_key='>')
    )
end
```
At the Julia prompt you may load the package and the associated settings by typing:
```julia
julia> @gnuplotrc
```
and you're ready to go.



## The gnuplot REPL
The **Gnuplot.jl** package comes with a built-in REPL mode to directly send commands to the underlying gnuplot process.  In order to avoid conflcts with other REPL modes, you need to explicitly activate such mode with:
```julia
Gnuplot.repl_init(start_key='>')
```
The customizable `start_key` character is the key which triggers activation of the REPL mode.  To quit the gnuplot REPL mode hit the `backspace` key.

If you wish to activate the REPL at Julia startup insert th following code in `.julia/config/startup.jl`:
```julia
using Gnuplot

atreplinit() do repl
    Gnuplot.repl_init(start_key='>')
end
```

```@setup abc
include("setup.jl")
```

# Display options

The display behaviour of **Gnuplot.jl** depends on the value of the `Gnuplot.options.gpviewer` flag:

- if `true` the plot is displayed in a gnuplot window, using one of the interactive terminals such as `wxt`, `qt` or `aqua`.  This is the default setting when running a Julia REPL session; The terminal options can be customized using `Gnuplot.options.term`;

- if `false` the plot is displayed through the Julia [multimedia interface](https://docs.julialang.org/en/v1/base/io-network/#Multimedia-I/O-1), i.e. it is exported as either a `png`, `svg` or `html` file, and displayed in an external viewer.  This is the default setting when running a Jupyter, VSCode or Juno session.

The `Gnuplot.options.gpviewer` flag is automatically set when the package is first loaded according to the runtime environment, however the user can change its value at any time to fit specific needs.  Further informations and examples for both options are available in this Jupyter [notebook](https://github.com/gcalderone/Gnuplot.jl/blob/master/docs/display.ipynb).


# Package options and initialization

## Options
The package options are stored in a global structure available in Julia as `Gnuplot.option` (the type of the structure is [`Gnuplot.Options`](@ref)).  The most important settings are as follows:

- `dry::Bool`: if true all new sessions will be started as [Dry sessions](@ref).  Default is `false`, but if the package is not able to start a gnuplot process it will automatically switch to `true`;

- `cmd::String`: command to start the gnuplot process, default value is `"gnuplot"`.  Use this field to specify a custom path to the gnuplot executable;

- `gpviewer::Bool`: use a gnuplot terminal as main plotting device (if `true`) or an external viewer (if `false`);

- `term::String`: default terminal for interactive use (default is an empty string, i.e. use gnuplot settings).  A custom terminal can be set with, e.g.:
```@repl abc
Gnuplot.options.term = "wxt size 700,400";
```

- `init::Vector{String}`: commands to initialize the session when it is created or reset.  It can be used to, e.g., set a custom linetypes or palette:
```@repl abc
push!(Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5));
```
Note that this option affect all the sessions, and that all inserted commands are saved in [Gnuplot scripts](@ref);

- `verbose::Bool`: a flag to set verbosity of the package.  If `true` all communication with the underlying process will be printed on stdout. E.g.:
```@repl abc
empty!(Gnuplot.options.init);                              # hide
gpexec("set term wxt");                                    # hide
Gnuplot.options.verbose = true;
x = 1.:10;
@gp x x.^2 "w l t 'Parabola'"
Gnuplot.save("output.png", term="pngcairo size 480,360 fontscale 0.8")
Gnuplot.options.verbose = false                            # hide
push!(Gnuplot.options.init, linetypes(:Set1_5, lw=1.5));   # hide
gpexec("set term unknown");                                # hide
```
Each line reports the package name (`GNUPLOT`), the session name (`default`), the command or string being sent to gnuplot process, and the returned response (line starting with `->`).  Default value for `verbose` is `false`;


## Package initialization

If you use **Gnuplot.jl** frequently you may find convenient to automatically apply the package settings ([Options](@ref)) whenever the package is loaded.  A possibility is to use the [atreplinit](https://docs.julialang.org/en/v1/stdlib/REPL/#Base.atreplinit) function and within the `startup.jl` initialization file (further info [here](https://docs.julialang.org/en/v1/stdlib/REPL/)), e.g.:
```julia
atreplinit() do repl
    try
        @eval begin
            using Gnuplot

            # Uncomment the following if you don't have gnuplot
            # installed on your platform:
            #Gnuplot.options.dry = true

            # Force a specific display behaviour (see documentation).  If
            # not given explicit Gnuplot.jl will choose the best option
            # according to your runtime environment.
            #Gnuplot.options.gpviewer = true

            # Set the proper path if the gnuplot executable is not
            # available in your $PATH
            #Gnuplot.options.cmd = "/path/to/gnuplot"

            # Set the default terminal for interacitve use
            # (only meaningful if Gnuplot.options.gpviewer = true)
            if Gnuplot.options.gpviewer
                Gnuplot.options.term = "wxt size 700,400 lw 1.4 enhanced"
            end

            # Set the default linetypes
            empty!(Gnuplot.options.init)
            push!(Gnuplot.options.init, Gnuplot.linetypes(:Set1_5, lw=1.5, ps=1.5))

            # Initialize the gnuplot REPL
            if Gnuplot.options.gpviewer
                Gnuplot.repl_init(start_key='>')
            end
        end
    catch err
        @show err
    end
end
```

```@setup abc
using Gnuplot
Gnuplot.quitall()
mkpath("assets")

Gnuplot.options.term = "unknown"
empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5))
saveas(file) = save(term="pngcairo size 550,350 fontscale 0.8", output="assets/$(file).png")
```

# Display options

The display behaviour of **Gnuplot.jl** depends on the value of the `Gnuplot.options.gpviewer` boolean option:

- if `true` the plot is displayed in a gnuplot window, using one of the interactive terminals such as `wxt`, `qt` or `aqua`.  There is exactly one window for each session, and the plots are updated by replacing the displayed image.  The preferred terminal can optionally be set using `Gnuplot.options.term`;

- if `false` the plot is displayed through the Julia [multimedia interface](https://docs.julialang.org/en/v1/base/io-network/#Multimedia-I/O-1), i.e. it is exported as either a `png`, `svg` or `html` file, and displayed in an external viewer.  In this case the package is unable to replace a previous plot, hence each update results in a separate image being displayed.  The terminal options to export the images are set in `Gnuplot.options.mime`.

The latter approach can only be used when running a Jupyter, JupyterLab or Juno session, while the former approach is appropriate in all cases (most notably, for the standard Julia REPL).  The `Gnuplot.options.gpviewer` flag is automatically set when the package is first loaded according to the runtime environment, however the user can change its value at any time to fit specific needs.

Further informations and examples for both options are available in this Jupyter [notebook](https://github.com/gcalderone/Gnuplot.jl/blob/gh-pages/v1.3.0/options/display.ipynb).

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

- `mime::Dict{MIME, String}`: dictionary of MIME types and corresponding gnuplot terminals.  Used to export images with either [`save()`](@ref) or `show()` (see [Display options](@ref)).  Default values are:
  - `MIME"application/pdf" => "pdfcairo enhanced"`
  - `MIME"image/jpeg"      => "jpeg enhanced"`
  - `MIME"image/png"       => "pngcairo enhanced"`
  - `MIME"image/svg+xml"   => "svg enhanced mouse standalone dynamic background rgb 'white'"`
  - `MIME"text/html"       => "svg enhanced mouse standalone dynamic"`
  - `MIME"text/plain"      => "dumb enhanced ansi"`


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
save(term="pngcairo size 480,360 fontscale 0.8", output="output.png")
Gnuplot.options.verbose = false                            # hide
push!(Gnuplot.options.init, linetypes(:Set1_5, lw=1.5));   # hide
gpexec("set term unknown");                                # hide
```
Each line reports the package name (`GNUPLOT`), the session name (`default`), the command or string being sent to gnuplot process, and the returned response (line starting with `->`).  Default value is `false`;


## Jupyter and Juno

**Gnuplot.jl** can display plots in Jupyter and Juno by exporting images in the PNG and SVG formats.  To customize the terminals used to export the images set the `term_png` or `term_svg` fields of the [`Gnuplot.Options`](@ref) structure, e.g.:
```@repl abc
Gnuplot.options.term_png = "pngcairo size 700,400 linewidth 2";
Gnuplot.options.term_svg = "svg dynamic";
```


## Package initialization

If you use **Gnuplot.jl** frequently you may find convenient to collect all the package settings ([Options](@ref)) in a single place, to quickly recall them in a Julia session.  I suggest to put the following code in the `~/.julia/config/startup.jl` initialization file (further info [here](https://docs.julialang.org/en/v1/stdlib/REPL/)):
```julia
macro gnuplotrc()
    return :(
        using Gnuplot;

        # Uncomment the following if you don't have the gnuplot
        # executable installed on your platform:
        #Gnuplot.options.dry = true;

        # Set the proper path if the gnuplot executable is not
        # available in your $PATH
        #Gnuplot.options.cmd = "/path/to/gnuplot";

        # Force a specific display behaviour (see documentation).  If
        # not given explicit Gnuplot.jl will choose the best option
        # according to your runtime environment.
        #Gnuplot.options.gpviewer = true

        # Set the default terminal for interacitve use
        Gnuplot.options.term = "wxt size 700,400";

        # Set the terminal options for the exported MIME types:
        #Gnuplot.options.mime[MIME"image/png"] = "";
        #Gnuplot.options.mime[MIME"image/svg+xml"] = "svg enhanced standalone dynamic";
        #Gnuplot.options.mime[MIME"text/html"] = "svg enhanced standalone mouse dynamic";

        # Set the terminal to plot in a terminal emulator:
        # (try with `save(MIME"text/plain")`):
        #Gnuplot.options.mime[MIME"text/plain"] = "sixelgd enhanced"; # requires vt340 emulation

        # Set the default linetypes
        empty!(Gnuplot.options.init);
        push!(Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5));

        # Initialize the gnuplot REPL using the provided `start_key`.
        if Gnuplot.options.gpviewer;
            Gnuplot.repl_init(start_key='>');
        end;
    )
end
```
At the Julia prompt you may load the package and the associated settings by typing:
```julia
julia> @gnuplotrc
```
and you're ready to go.

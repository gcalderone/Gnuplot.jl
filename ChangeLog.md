# Version 1.2.0  (not yet released)

- New features:
	* REPL mode: a new `Gnuplot.repl_init()` function is available to
      install a gnuplot REPL;

	* `@gp` and `@gsp` now accepts a `Gnuplot.PlotRecipe` object,
      collect commands, data and plot specifications in a single
      argument;

	* The `plotrecipe` function can be extended to register new implicit
      recipes to display input data;

	* The `linetypes` function now accept the `lw` and `ps` keywords
      (to set the line width and point size respectively), and the
      `dashed` keyword (to use dashed patterns in place of solid
      lines);

	* The new `Gnuplot.options.reset::Vector{String}` field allows to
      set initialization commands to be executed when a session is
      reset.  Unlike `Gnuplot.options.reset`, these commands are saved
      in the session and can be dumped to a script;

- Bugfix:
	* When a `Vector{String}` is passed to `driver()` it used to be
	modified, and couldn't be used again in a second call.  Now the
	original is preserved;

	* `contourlines()` used to return a single blanck line to
	distinguish iso-contour lines, and this may cause problems in 3D
	plot.  Now two blanck lines are returned;


# Version 1.1.0 (released on: Apr. 09, 2020)

- First production ready version;
- Completed documentation and example gallery;

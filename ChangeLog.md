# Version 1.2.0 (not yet released)

- New features:
	* REPL mode: a new `Gnuplot.repl_init()` function is available to
      install a gnuplot REPL;

	* `@gp` and `@gsp` now accepts a `Gnuplot.PlotElements` object,
      containing commands, data and plot specifications in a single
      argument;

	* The `recipe()` function can be extended to register new implicit
      recipes to display input data;

	* The `linetypes` function now accept the `lw`, `ps` (to set the
      line width and point size respectively), and the `dashed` (to
      use dashed patterns in place of solid lines) keywords;

	* The new `Gnuplot.options.reset::Vector{String}` field allows to
      set initialization commands to be executed when a session is
      reset.  Unlike `Gnuplot.options.init`, these commands are saved
      in the session and can be saved into a script;

	* New functions: `gpvars()` to retrieve all gnuplot variables,
      `gpmargins()` to retrieve current plot margins (in screen
      coordinates, `gpranges()` to retrieve current plot axis ranges;
	
	* New keywords for `@gp` and `@gsp`: `lmargin`, `rmargin`,
      `bmargin`, `tmargin`, `margins`, to set plot margins;
	  
- New recipes:
	* to display histograms (as returned by `hist()`);

    * to display images;

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

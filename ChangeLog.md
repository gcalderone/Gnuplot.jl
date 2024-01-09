# Version 1.6.2
* New function: `show_specs()`;

* Bugfix: `@gp x x x "w p lc pal"` when using the binary data format used to raise an error because of a missing `using` clause.  Now the `using` clause is added any time the binary format is used, and a check is made to avoid duplicated clauses in case the user adds a custom one;

* Bugfix: forcing a blank between the GPVAL_TERM and GPVAL_TERMOPTTIONS values when reading default terminal (fixes #62);


# Version 1.6.1
* Bugfix: avoid automatic sending of "set multiplot next" whenever a plot slot has no associated plot commands;


# Version 1.6.0

This release features a thorough refactor which allowed to simplify the code while maintaining the same functionalities.
A few minor changes may, however, break your code.  Specifically:
  * Real numbers in @gp and @gsp are no longer interpreted as vectors with one element (replace them wiyh, e.g. `[0.]`);

  * Multiplot ID can only be specified once in a `@gp` or `@gsp` call, and it must appear before other plot specs;

  * Mixing plot and splot commands is now detected as an error;

  * Scripts are now saved using `Gnuplot.savescript` (rather than `Gnuplot.save`);

  * `Gnuplot.save` is no longer exported to avoid collision with other packages;

  * In `Gnuplot.save`, `output=` is no longer a keyword, but the required first argument;

  * The `Options` structure no longer has a `mime` field: to customize terminal for a specific MIME a new method should be implemented;

This release also features the first built-in explitict recipe: `line()`.



# Version 1.5.0
- New features:
	* using PrecompileTools to reduce time-to-first-plot in Julia v1.9;

	* The `hist` function is now a simple wrapper to
      `StatsBase.fit(Histogram...)`;

	* The output of `hist` can be passed to `hist_bins` and `hist_weights` functions to obtain ready-to-plot arrays;

Note: Julia version >= 1.9 is now required!

# Version 1.4.1
- New features:
	* Implicit recipes can now returns a `Vector{PlotElement}`;

	* Allow using single quotes in output file names (#52);

	* New function: `palette_levels()` can be used to modify palette levels before passing them to gnuplot;

- Bugfix:
	* Fixed `BoundsErrors` in `hist()` (#49);

	* Fixed problem when generating documentation (#51);


# Version 1.4.0 (released on: May 5, 2021)
- New features:
    * Missing values are accepted if the input arrays have `eltype <:
      AbstractFloat`;

    * Missing values are also accepted in calls to `hist`;

	* VSCode and Pluto sessions are now properly handled (#35 and #43);

- Bugfix:
	* Multiplot were not displayed in Jupyter (#25);

	* `gpvars()` fails if gnuplot character encoding is utf8
      (#24);


# Version 1.3.0 (released on: Apr. 29, 2020)

- New features:
    * The new `dgrid3d()` allows to interpolate scattered 2D data on a
       2D regular grid;

    * The `Options` structure features a new `mime` field containing a
      dictionary to map a MIME type to gnuplot terminals;

    * The `Options` structure features a new `gpviewer` field allowing
      to choose the display behaviour (using either gnuplot
      interactive terminals or anexternal viewer such as Jupyter or
      Juno);

    * The `save()` function now accepts a `MIME` argument in place of
      the `term=` keyword.  The actual terminal is retrieved from the
      `Options.mime` dictionary;

    * The `contourlines()` function now accepts `AbstractVector` and
      `AbstractMatrix` as arguments, rather than `Vector` and
      `Matrix`;

    * The `contourlines()` function now accepts a `fractions` input to
      generate contours encompassing given fractions of the total
      counts in a 2D histogram;

    * The `palette()` function now accept a boolean `smooth` keyword,
      allowing to interpolate a discrete palette into a continuous one.

- Breaking changes:
    * The `Options` structure no longer provides the `term_svg` and
      `term_png` fields.  They have been replaced by the `mime`
      dictionary.


# Version 1.2.0 (released on: Apr. 20, 2020)

- New features:
    * REPL mode: a new `Gnuplot.repl_init()` function is available to
      install a gnuplot REPL;

    * Implemented the "recipe" mechanism: the `recipe()` function can
      now be extended to register new implicit recipes to display
      data;

    * `@gp` and `@gsp` now accepts a `Gnuplot.PlotElements` object,
      containing commands, data and plot specifications in a single
      argument;

    * The `linetypes` function now accept the `lw`, `ps` (to set the
      line width and point size respectively), and the `dashed` (to
      use dashed patterns in place of solid lines) keywords;

    * The new `Gnuplot.options.term::String` field allows to set the
      default terminal for interactive sessions;

    * New functions: `gpvars()` to retrieve all gnuplot variables,
      `gpmargins()` to retrieve current plot margins (in screen
      coordinates, `gpranges()` to retrieve current plot axis ranges;

    * New keywords accepted by `@gp` and `@gsp`: `lmargin`, `rmargin`,
      `bmargin`, `tmargin`, `margins`, to set plot margins;

    * Implemented new implicit recipes to display histograms (as
      returned by `hist()`), contour lines (as returned by
      `contourlines()`) and images;

    * Implemented automatic display of plots in both Jupyter and Juno;

    * Documentation updated;


- Breaking changes:
    * The 2D matrix are now sent to gnuplot in a column-major order,
      to comply with Julia array layout;


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

# Version 1.3.0 (released on: Apr. 28, 2020)

- New features:

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

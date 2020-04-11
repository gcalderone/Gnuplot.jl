# Version 1.2.0
git-tree-sha1: master
released on: 

- New features:
	* REPL mode: a new `Gnuplot.repl_init()` function is available to
      install a gnuplot REPL;

	* `@gp` and `@gsp` now accepts a `Gnuplot.DataSet` object, to
	allow customized data input;

- Bugfix:
	* When a `Vector{String}` is passed to `driver()` it used to be
	modified, and couldn't be used again in a second call.  Now a copy
	is made and the original is preserved;

	* `contourlines()` used to return a single blanck line to
	distinguish iso-contour lines, and this may cause problems in 3D
	plot.  Now two blanck lines are returned;


# Version 1.1.0 
git-tree-sha1: d62f8713b2e49bce9ef37bd21b80c4297d316915
released on: Apr. 09, 2020

- First production ready version;
- Completed documentation and example gallery;

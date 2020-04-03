# Style Guide

The **Gnuplot.jl** loose syntax allows to create a plot using very different approaches.  While this was one of the initial purposes for the package, it may lead to decreased code readability if not used judiciously.

Here I will summarize a few, non-mandatory, guidelines which allows to maintain a neat syntax and a high readability:

### 1 - Use macros without parentheses and commas:
The two most important symbols exported by the package (`@gp` and `@gsp`) are macros.  As such they are supposed to be invoked without parentheses and commas.  E.g. use:
```julia
@gp x y "with lines"
```
in place of 
```julia
@gp(x, y, "with lines")
```

If you have very long lines you may split them in multiple statements using the `:-` symbol, which resembles both hyphenation in natural language and indentation for the plot-producing code:
```julia
@gp    "set grid" :- 
@gp :- x y "with lines"
```
Note that the trailing `:-` symbol is not mandatory.  If omitted, the plot will be updated at each statement (rather than at the last one).


### 2 - Use keywords in place of gnuplot commands:

As discussed in [Keywords for common commands](@ref) several commonly used gnuplot commands can be replaced with a keyword.  E.g. you can use
```julia
@gp ... xrange=[-1,5] ...
```
in place of 
```julia
@gp ... "set xrange [-1:5]" ...
```
This help reducing the number of strings, as well as the associated interpolating characters (`$`), and results in a more concise syntax.


### 3 - Use abbreviations for commands and keywords:

Many gnuplot commands, as well as all keywords (see [Keywords for common commands](@ref)), can be abbreviated as long as the abbreviation is unambiguous.  E.g., the following code:
```julia
@gp    "set grid" "set key left" "set logscale y"
@gp :- "set title 'Plot title'" "set label 'X label'" "set xrange [0:*]"
@gp :- x y "with lines"
```
can be replaced with a shorter version:
```julia
@gp    "set grid" k="left" ylog=true
@gp :- tit="Plot title" xlab="X label" xr=[0,NaN]
@gp :- x y "w l"
```
Besides being more idiomatic, the possibility to exploit abbreviations is of great importance when performing interactive data exploration.

Moreover, in many gnuplot examples and documentation it is very common to use abbreviations (i.e. `w l` in place of `with lines`) so there is no reason to avoid them in **Gnuplot.jl**.



### 4 - If possible, follow the *commands* -> *data* + *plot specs* order

The two following examples produce exactly the same plot:
```julia
x = -10.:10
@gp    "set grid" "set multiplot layout 2,1" 
@gp :- 1 x x.^2 "w l t 'f(x) = x^2"  # first plot
@gp :- 2 x x.^3 "w l t 'f(x) = x^3"  # second plot
```
and
```julia
@gp    2 x x.^3 "w l t 'f(x) = x^3"  # second plot
@gp :- 1 x x.^2 "w l t 'f(x) = x^2"  # first plot
@gp :- "set grid" "set multiplot layout 2,1"
```
However, the first form appears more *logical* and easy to follow.

In analogy with previous example, even on single plot, the following form
```julia
@gp    "set grid"
@gp :- x x.^2 "w l t 'f(x) = x^2"
```
should be preferred over
```julia
@gp    x x.^2 "w l t 'f(x) = x^2"
@gp :- "set grid"
```
even if the output is exactly the same.


### 5 - Join multiple command strings:

Instead of specifying several commands as strings
```julia
@gp :- "set key off"  "set auto fix"  "set size square"
@gp :- "set offsets graph .05, graph .05, graph .05, graph .05"
@gp :- "set border lw 1 lc rgb 'white'"
```
join them in a single string using triple quotes and `;`
```julia
@gp :- """set key off;  set auto fix;  set size square;
          set offsets graph .05, graph .05, graph .05, graph .05;
          set border lw 1 lc rgb 'white'; """
```

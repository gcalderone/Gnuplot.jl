# Gnuplot.jl
## A Julia interface to Gnuplot.

|:------------------:|:------------------------------------------------------------------------------------------------------------------------------------:|
- ** Build status**  | [![Build Status](https://travis-ci.org/gcalderone/Gnuplot.jl.svg?branch=master)](https://travis-ci.org/gcalderone/Gnuplot.jl)        |
|:------------------:|:------------------------------------------------------------------------------------------------------------------------------------:|
| **License**        | [![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)                                         |
|:------------------:|:------------------------------------------------------------------------------------------------------------------------------------:|
| **Documentation**  | [![DocumentationStatus](https://img.shields.io/badge/docs-latest-blue.svg?style=flat)](https://gcalderone.github.io/Gnuplot.jl/dev/) |
|:------------------:|:------------------------------------------------------------------------------------------------------------------------------------:|
| **Examples**       | [Examples](https://img.shields.io/website?style=flat)](https://lazarusa.github.io/gnuplot-examples//)                                |
|:------------------:|:------------------------------------------------------------------------------------------------------------------------------------:|

**Gnuplot.jl** provides a simple package able to send both data and commands from Julia to an underlying [gnuplot](http://gnuplot.sourceforge.net/) process.  Its main purpose it to provide a fast and powerful data visualization framework, using an extremely concise Julia syntax.

The documentation can be found [here](https://gcalderone.github.io/Gnuplot.jl/dev/), while the gallery of examples is maintained [here](https://lazarusa.github.io/gnuplot-examples/).

## Installation

Install with:
```julia-repl
]dev Gnuplot
```
A working [gnuplot](http://gnuplot.sourceforge.net/) package must be installed on your platform.


Test package:
```julia-repl
using Gnuplot
println(Gnuplot.gpversion())
test_terminal()
```



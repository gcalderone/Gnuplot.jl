using Gnuplot, Random
Random.seed!(1)
Gnuplot.quitall()
mkpath("assets")
Gnuplot.splash("assets/logo.png")
Gnuplot.options.term = "unknown"
empty!(Gnuplot.options.init)
push!( Gnuplot.options.init, linetypes(:Set1_5, lw=1.5, ps=1.5))
saveas(file) = Gnuplot.save(term="pngcairo size 550,350 fontscale 0.8", "assets/$(file).png")

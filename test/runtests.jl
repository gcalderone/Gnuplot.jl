using Test, Gnuplot
try
    @info "Gnuplot.jl version: " * string(Gnuplot.version())
    @info "gnuplot    version: " * string(Gnuplot.gpversion())
catch
    Gnuplot.options.dry = true
end
Gnuplot.options.gpviewer = true

x = [1, 2, 3]
y = [4, 5, 6]

s = Gnuplot.arrays2datablock(x)
@test all(s .== [" 1"   ,
                 " 2"   ,
                 " 3"   ])

s = Gnuplot.arrays2datablock(x, y)
@test all(s .== [" 1 4",
                 " 2 5",
                 " 3 6"])

s = Gnuplot.arrays2datablock(x, y, x.+y)
@test all(s .== [" 1 4 5",
                 " 2 5 7",
                 " 3 6 9"])

z = [X+Y for X in x, Y in y];
s = Gnuplot.arrays2datablock(z)
@test all(s .== ["0 0 5",
                 "1 0 6",
                 "2 0 7",
                 ""     ,
                 "0 1 6",
                 "1 1 7",
                 "2 1 8",
                 ""     ,
                 "0 2 7",
                 "1 2 8",
                 "2 2 9"])

s = Gnuplot.arrays2datablock(z, z)
@test all(s .== [" 5 5",
                 " 6 6",
                 " 7 7",
                 ""    ,
                 " 6 6",
                 " 7 7",
                 " 8 8",
                 ""    ,
                 " 7 7",
                 " 8 8",
                 " 9 9"])

s = Gnuplot.arrays2datablock(x, y, z)
@test all(s .== [" 1 4 5" ,
                 " 2 4 6" ,
                 " 3 4 7" ,
                 ""       ,
                 " 1 5 6" ,
                 " 2 5 7" ,
                 " 3 5 8" ,
                 ""       ,
                 " 1 6 7" ,
                 " 2 6 8" ,
                 " 3 6 9" ])

c = [[X, Y] for Y in y for X in x];  # First Y (i.e. rows) then X (i.e. columns)
u = getindex.(c, 1)
v = getindex.(c, 2)

s = Gnuplot.arrays2datablock(u, v, z)
@test all(s .== [" 1 4 5" ,
                 " 2 4 6" ,
                 " 3 4 7" ,
                 ""       ,
                 " 1 5 6" ,
                 " 2 5 7" ,
                 " 3 5 8" ,
                 ""       ,
                 " 1 6 7" ,
                 " 2 6 8" ,
                 " 3 6 9" ])

s = Gnuplot.arrays2datablock(1:3, 1:3, ["One", "Two", "Three"])
@test all(s .== [ " 1 1 \"One\""  ,
                  " 2 2 \"Two\""  ,
                  " 3 3 \"Three\""])


#-----------------------------------------------------------------
dummy = palette_names()
pal = palette(:deepsea)
@test pal == "set palette defined (0.0 '#2B004D', 0.25 '#4E0F99', 0.5 '#3C54D4', 0.75 '#48A9F8', 1.0 '#C5ECFF')\nset palette maxcol 5\n"
ls = linetypes(:Set1_5, lw=1.5, ps=2)
@test ls == "unset for [i=1:256] linetype i\nset linetype 1 lc rgb '#E41A1C' lw 1.5 dt solid pt 1 ps 2\nset linetype 2 lc rgb '#377EB8' lw 1.5 dt solid pt 2 ps 2\nset linetype 3 lc rgb '#4DAF4A' lw 1.5 dt solid pt 3 ps 2\nset linetype 4 lc rgb '#984EA3' lw 1.5 dt solid pt 4 ps 2\nset linetype 5 lc rgb '#FF7F00' lw 1.5 dt solid pt 5 ps 2\nset linetype cycle 5\n"

dummy = terminals()
# if "sixelgd" in terminals()
#     Gnuplot.options.term = "sixelgd enhanced"
# elseif "sixel" in terminals()
#     Gnuplot.options.term = "sixel enhanced"
# elseif "dumb" in terminals()
#     Gnuplot.options.term = "dumb"
# else
#     Gnuplot.options.term = "unknown"
# end
# Gnuplot.quitall()

# Force unknown on Travis CI
Gnuplot.options.term = "unknown"

@gp 1:9
@info "using terminal: " terminal()
#test_terminal("unknown")

#-----------------------------------------------------------------
# Test wth empty dataset
@gp Float64[]
@gsp Float64[]
@gp Float64[] Float64[]
@gsp Float64[] Float64[]


#-----------------------------------------------------------------
x = collect(1.:100);

for i in 1:10
    @gp :gp1 "plot sin($i*x)"
    @gp :gp2 "plot sin($i*x)"
    @gp :gp3 "plot sin($i*x)"
    sleep(0.3)
end
Gnuplot.quitall()

#-----------------------------------------------------------------
@gp "plot sin(x)"
@gp "plot sin(x)" "pl cos(x)"
@test_throws AssertionError @gp "plo sin(x)" "s cos(x)"

@gp mar="0,1,0,1" "plot sin(x)"
@gp :- mar=gpmargins() "plot cos(x)"
@gp :- [0.] [0.]

@gp "plot sin(x)" xr=(-2pi,2pi) "pause 2" "plot cos(4*x)"

x = range(-2pi, stop=2pi, length=100);
y = 1.5 * sin.(0.3 .+ 0.7x);
err = 0.1 * maximum(abs.(y)) .* fill(1, size(x));
noise = err .* randn(length(x));

h = hist(noise, nbins=10)
@gp hist_bins(h) hist_weights(h) "w steps notit"
@gp h

@gp x y
@gp x y "w l"

name = "\$MyDataSet1"
@gp name=>(x, y) "plot $name w l" "pl $name u 1:(2*\$2) w l"

@gsp randn(Float64, 30, 50)
@gp 1:30 1:50 randn(Float64, 30, 50) "w image"
@gsp x y y

@gp("set key horizontal", "set grid",
    xrange=(-7,7), ylabel="Y label",
    x, y, "w l t 'Real model' dt 2 lw 2 lc rgb 'red'",
    x, y+noise, err, "w errorbars t 'Data'")

@gp "f(x) = a * sin(b + c*x); a = 1; b = 1; c = 1;"   :-
@gp :- name=>(x, y+noise, err)                        :-
@gp :- "fit f(x) $name u 1:2:3 via a, b, c;"          :-
@gp :- "set multiplot layout 2,1"                     :-
@gp :- "plot $name w points" ylab="Data and model"    :-
@gp :- "plot $name u 1:(f(\$1)) w lines"              :-
@gp :- mid=2 xlab="X label" ylab="Residuals"              :-
@gp :- mid=2 "plot $name u 1:((f(\$1)-\$2) / \$3):(1) w errorbars notit"

# Retrieve values for a, b and c
if Gnuplot.options.dry
    a = 1.5
    b = 0.3
    c = 0.7
else
    a = Meta.parse(gpexec("print a"))
    b = Meta.parse(gpexec("print b"))
    c = Meta.parse(gpexec("print c"))
end

@gp    :dry "f(x) = a * sin(b + c*x); a = 1; b = 1; c = 1;"  :-
@gp :- :dry "a = $a; b = $b; c = $c"                         :-
@gp :- :dry "set multiplot layout 2,1" ylab="Data and model" :-
name = "\$MyDataSet1"
@gp :- :dry name=>(x, y+noise, err)                          :-
@gp :- :dry "plot $name w points"                            :-
@gp :- :dry "plot $name u 1:(f(\$1)) w lines"                :-
@gp :- :dry mid=2 xlab="X label" ylab="Residuals"                :-
@gp :- :dry mid=2 "plot $name u 1:((f(\$1)-\$2) / \$3):(1) w errorbars notit" :-
@gp :- :dry
savescript(:dry, "test.gp")        # write on file test.gp
Gnuplot.quitall()
#gpexec("load 'test.gp'") # load file test.gp, commented to avoid errors in CI

#-----------------------------------------------------------------
@gp("""
        approx_1(x) = x - x**3/6
        approx_2(x) = x - x**3/6 + x**5/120
        approx_3(x) = x - x**3/6 + x**5/120 - x**7/5040
        label1 = "x - {x^3}/3!"
        label2 = "x - {x^3}/3! + {x^5}/5!"
        label3 = "x - {x^3}/3! + {x^5}/5! - {x^7}/7!"
        #
        set termoption enhanced
        save_encoding = GPVAL_ENCODING
        set encoding utf8
        #
        set title "Polynomial approximation of sin(x)"
        set key Left center top reverse
        set xrange [ -3.2 : 3.2 ]
        set xtics ("-π" -pi, "-π/2" -pi/2, 0, "π/2" pi/2, "π" pi)
        set format y "%.1f"
        set samples 500
        set style fill solid 0.4 noborder""",
    "plot '+' using 1:(sin(\$1)):(approx_1(\$1)) with filledcurve title label1 lt 3",
    "plot '+' using 1:(sin(\$1)):(approx_2(\$1)) with filledcurve title label2 lt 2",
    "plot '+' using 1:(sin(\$1)):(approx_3(\$1)) with filledcurve title label3 lt 1",
    "plot sin(x) with lines lw 1 lc rgb 'black'")

#-----------------------------------------------------------------
@gp("""
        set zrange [-1:1]
        unset label
        unset arrow
        sinc(u,v) = sin(sqrt(u**2+v**2)) / sqrt(u**2+v**2)
        set xrange [-5:5]; set yrange [-5:5]
        set arrow from 5,-5,-1.2 to 5,5,-1.2 lt -1
        set label 1 "increasing v" at 6,0,-1
        set arrow from 5,6,-1 to 5,5,-1 lt -1
        set label 2 "u=0" at 5,6.5,-1
        set arrow from 5,6,sinc(5,5) to 5,5,sinc(5,5) lt -1
        set label 3 "u=1" at 5,6.5,sinc(5,5)
        set parametric
        set hidden3d offset 0	# front/back coloring makes no sense for fenceplot #
        set isosamples 2,33
        xx=-5; dx=(4.99-(-4.99))/9
        x0=xx; xx=xx+dx
        x1=xx; xx=xx+dx
        x2=xx; xx=xx+dx
        x3=xx; xx=xx+dx
        x4=xx; xx=xx+dx
        x5=xx; xx=xx+dx
        x6=xx; xx=xx+dx
        x7=xx; xx=xx+dx
        x8=xx; xx=xx+dx
        x9=xx; xx=xx+dx""",
    "splot [u=0:1][v=-4.99:4.99]x0, v, (u<0.5) ? -1 : sinc(x0,v) notitle",
	"splot x1, v, (u<0.5) ? -1 : sinc(x1,v) notitle",
	"splot x2, v, (u<0.5) ? -1 : sinc(x2,v) notitle",
	"splot x3, v, (u<0.5) ? -1 : sinc(x3,v) notitle",
	"splot x4, v, (u<0.5) ? -1 : sinc(x4,v) notitle",
	"splot x5, v, (u<0.5) ? -1 : sinc(x5,v) notitle",
	"splot x6, v, (u<0.5) ? -1 : sinc(x6,v) notitle",
	"splot x7, v, (u<0.5) ? -1 : sinc(x7,v) notitle",
	"splot x8, v, (u<0.5) ? -1 : sinc(x8,v) notitle",
	"splot x9, v, (u<0.5) ? -1 : sinc(x9,v) notitle")



x = randn(5000);
y = randn(5000);
h = hist(x, y, nbins1=20, nbins2=20);
clines = contourlines(h, "levels discrete 15, 30, 45");
@gp clines
@gp "set size ratio -1"
for i in 1:length(clines)
    @gp :- clines[i].data "w l t '$(clines[i].z)' lw $i dt $i"
end


Gnuplot.options.verbose = true
@gp randn(10^6) randn(10^6)
@gp :- [0.] [0.]
Gnuplot.quit(:default)

Gnuplot.options.dry = true
@gp hist(randn(1000))

# Various hist() corner cases
@gp hist([1,2,3], bs=2)
@gp hist([1,1,1], bs=1)

Gnuplot.quitall()

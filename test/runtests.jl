using Base.Test
using Gnuplot

function pressEnter()
    println("Press enter...")
    readline(STDIN)
end

function gp_test(terminal="unknown")
    gpOptions.startup = "set term $terminal"

    gpReset()
    x = collect(1.:100)

    #-----------------------------------------------------------------
    gpSend("plot sin(x)")
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    id1 = gpCurrentID()
    id2 = gpNewSession()
    id3 = gpNewSession()

    for i in 1:10
        gpSetCurrentID(id1)
        gpSend("plot sin($i*x)")

        gpSetCurrentID(id2)
        gpSend("plot sin($i*x)")

        gpSetCurrentID(id3)
        gpSend("plot sin($i*x)")

        sleep(0.3)
    end
    terminal == "unknown"  ||  pressEnter()
    gpExitAll()

    #-----------------------------------------------------------------
    gpReset()
    name = gpData([1,2,3,5,8,13])
    gpPlot("$name w points ps 3")
    gpDump()
    terminal == "unknown"  ||  pressEnter()

    gpPlot(last=true, "w l lw 3")
    gpDump()
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    gpReset()

    gpCmd("set format y \"%.1f\"")
    gpCmd("set key box opaque")
    gpCmd("set xrange [-2*pi:2*pi]")
    gpMulti("layout 2,2 columnsfirst title \"Multiplot title\"")

    gpCmd(ylab="Y label")
    gpPlot("sin(x) lt 1")

    gpNext()
    gpCmd(xlab="X label")
    gpPlot("cos(x) lt 2")

    gpNext()
    gpCmd("unset ylabel")
    gpCmd("unset ytics")
    gpCmd("unset xlabel")
    gpPlot("sin(2*x) lt 3")

    gpNext()
    gpCmd(xlab="X label")
    gpPlot("cos(2*x) lt 4")

    gpDump()
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    @gp("set format y \"%.1f\"",
        "set key box opaque",
        xr=(-2pi,2pi),
        :multi, "layout 2,2 columnsfirst title \"Multiplot title\"",
        ylab="Y label",
        :plot, "sin(x) lt 1",
        :next,
        xlab="X label",
        :plot, "cos(x) lt 2",
        :next,
        "unset ylabel",
        "unset ytics",
        "unset xlabel",
        :plot, "sin(2*x) lt 3",
        :next,
        xlab="X label",
        :plot, "cos(2*x) lt 4"
        )
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    @gpi(:reset, "set key off",
         xr=(1,10), yr=(1,100), xlog=true, ylog=true,
         :multi, "layout 2,2 columnsfirst title \"Multiplot title\"")
    
    for i in 1:4
        @gpi(x, x.^i, "w l lw 3 lt $i", :next)
    end
    @gpi()
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    lw = 5
    @gp "set title 'My title'" x x.^2. "w l tit '{/Symbol L}_{/Symbol a}' lw $lw dt 2 lc rgb 'red'"
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    @gp("set title 'My title'",
        x, x.^2  , "w l tit '{/Symbol L}_{/Symbol a}' lw $lw dt 2 lc rgb 'red'",
        x, x.^2.2, "w l tit 'bbb'"
        )
    terminal == "unknown"  ||  pressEnter()

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
        :plot, "'+' using 1:(sin(\$1)):(approx_1(\$1)) with filledcurve title label1 lt 3",
        :plot, "'+' using 1:(sin(\$1)):(approx_2(\$1)) with filledcurve title label2 lt 2",
        :plot, "'+' using 1:(sin(\$1)):(approx_3(\$1)) with filledcurve title label3 lt 1",
        :plot, "sin(x) with lines lw 1 lc rgb 'black'")

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
        splot=true,
        :plot, "[u=0:1][v=-4.99:4.99]x0, v, (u<0.5) ? -1 : sinc(x0,v) notitle",
	    :plot, "x1, v, (u<0.5) ? -1 : sinc(x1,v) notitle",
	    :plot, "x2, v, (u<0.5) ? -1 : sinc(x2,v) notitle",
	    :plot, "x3, v, (u<0.5) ? -1 : sinc(x3,v) notitle",
	    :plot, "x4, v, (u<0.5) ? -1 : sinc(x4,v) notitle",
	    :plot, "x5, v, (u<0.5) ? -1 : sinc(x5,v) notitle",
	    :plot, "x6, v, (u<0.5) ? -1 : sinc(x6,v) notitle",
	    :plot, "x7, v, (u<0.5) ? -1 : sinc(x7,v) notitle",
	    :plot, "x8, v, (u<0.5) ? -1 : sinc(x8,v) notitle",
	    :plot, "x9, v, (u<0.5) ? -1 : sinc(x9,v) notitle")

    gpExitAll()
    return true
end

@test gp_test()

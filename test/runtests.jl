using Base.Test
using Gnuplot

function pressEnter()
    println("Press enter...")
    readline(STDIN)
end

function gp_test(terminal="unknown")
    gp_setOption(verb=1)
    gp_setOption(startup="set term $terminal")

    gp_reset()
    x = collect(1.:100)

    #-----------------------------------------------------------------
    gp_send("plot sin(x)")
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    id1 = gp_current()
    id2 = gp_new()
    id3 = gp_new()

    for i in 1:10
        gp_setCurrent(id1)
        gp_send("plot sin($i*x)")

        gp_setCurrent(id2)
        gp_send("plot sin($i*x)")

        gp_setCurrent(id3)
        gp_send("plot sin($i*x)")

        sleep(0.3)
    end
    terminal == "unknown"  ||  pressEnter()
    gp_exitAll()

    #-----------------------------------------------------------------
    gp_reset()
    name = gp_data([1,2,3,5,8,13])
    gp_plot("$name w points ps 3")
    gp_run()
    terminal == "unknown"  ||  pressEnter()

    gp_plot(last=true, "w l lw 3")
    gp_run()
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    gp_reset()

    gp_cmd("set format y \"%.1f\"")
    gp_cmd("set key box opaque")
    gp_cmd("set xrange [-2*pi:2*pi]")

    gp_next()
    gp_cmd("set multiplot layout 2,2 columnsfirst title \"Multiplot title\"")
    gp_cmd(ylab="Y label")
    gp_plot("sin(x) lt 1")

    gp_next()
    gp_cmd(xlab="X label")
    gp_plot("cos(x) lt 2")

    gp_next()
    gp_cmd("unset ylabel")
    gp_cmd("unset ytics")
    gp_cmd("unset xlabel")
    gp_plot("sin(2*x) lt 3")

    gp_next()
    gp_cmd(xlab="X label")
    gp_plot("cos(2*x) lt 4")

    gp_run()
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    @gp(
        "set format y \"%.1f\"",
        "set key box opaque",
        xr=(-2pi,2pi),
        :next,
        "set multiplot layout 2,2 columnsfirst title \"Multiplot title\"",
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
        :plot, "cos(2*x) lt 4",
        )
    terminal == "unknown"  ||  pressEnter()

    #-----------------------------------------------------------------
    @gp(
        "set format y \"%.1f\"",
        "set key box opaque",
        xr=(1,10), yr=(1,40),
        :next,
        "set multiplot layout 2,2 columnsfirst title \"Multiplot title\"",
        ylab="Y label",
        x, x, "lt 1",
        :next,
        xlab="X label",
        x, 2x, "lt 2",
        :next,
        "unset ylabel",
        "unset ytics",
        "unset xlabel",
        x, 3x, "lt 3",
        :next,
        xlab="X label",
        x, 4x, "lt 4"
        )
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

    return true
end

@test gp_test()

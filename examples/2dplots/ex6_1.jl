# This file was generated, do not modify it. # hide
using Gnuplot
ecycl_x(r,k,θ) = r*(k .+ 1).*cos.(θ) .- r*cos.((k .+ 1) .* θ)
ecycl_y(r,k,θ) = r*(k .+ 1).*sin.(θ) .- r*sin.((k .+ 1) .* θ)
θ = LinRange(0,6.2π,1000)
@gp(ecycl_x(1,1,θ), ecycl_y(1,1,θ), "w l lw 2 t '1'",
    "set size square")
for k in 2:0.5:5.
    @gp(:-, ecycl_x(2k,k,θ), ecycl_y(2k,k,θ), "w l lw 2 t '$(k)' ", 
        "set key outside title 'k, r=2k' box opaque",
        xlabel = "x(θ) = r(k+1)cos(θ) -rcos((k+1)θ)", 
        ylabel = "y(θ) = r(k+1)cos(θ) -rcos((k+1)θ) ",
        title = "Epicycloid",:-)
end
@gp
save(term="pngcairo font 'Consolas, 12' size 600,600", output="plt2_ex6dot1.png") # hide
reset session
$data2 << EOD
 1 1
 2 4
 3 9
 4 16
 5 25
 6 36
 7 49
 8 64
 9 81
 10 100
EOD
reset
unset for [i=1:256] linetype i
set linetype 1 lc rgb '#E41A1C' lw 1.5 dt solid pt 1 ps 1.5
set linetype 2 lc rgb '#377EB8' lw 1.5 dt solid pt 2 ps 1.5
set linetype 3 lc rgb '#4DAF4A' lw 1.5 dt solid pt 3 ps 1.5
set linetype 4 lc rgb '#984EA3' lw 1.5 dt solid pt 4 ps 1.5
set linetype 5 lc rgb '#FF7F00' lw 1.5 dt solid pt 5 ps 1.5
set linetype cycle 5

plot $data2 w l
unset multiplot

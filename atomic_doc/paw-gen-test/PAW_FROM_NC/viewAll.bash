#!/bin/bash

LD1=../ld1-orig.x
LD_=../ld1.x

NCONF=11
CALCLIST="NC NChard US UShard PAW-AE-QAE PAW-NChard-Qhard PAW-NChard-Qsmooth"

first="NC"
last="PAW-NChard-Qsmooth"

echo "# occ AE "$CALCLIST > s.dat
echo "# occ AE "$CALCLIST > p.dat
echo "# occ AE "$CALCLIST > e.dat

for ((i=0;((i<NCONF));i++)); do
occ=$(dc -e "2k 2 $((NCONF-1))/ $i* _1 * 2+ p")
#occ=$(dc -e "2k 1 $((NCONF-1))/ $i* _1 * 2+ p")
echo $occ

for calc in $CALCLIST; do
awk -v calc=$calc -v occ=$occ -v first=$first -v last=$last '
/     1 0     2S   1\(/ {sae=$6; sps=$7}
/     2 1     2P   1\(/ {pae=$6; pps=$7}
/dEtot_ae/ {eae=$3}
/dEtot_ps/ {eps=$3}
END {
if (calc==first) printf "%f ", occ >>"s.dat";
if (calc==first) printf "%f ", occ >>"p.dat";
if (calc==first) printf "%f ", occ >>"e.dat";
if (calc==first) printf "%f ", sae >>"s.dat";
if (calc==first) printf "%f ", pae >>"p.dat";
if (calc==first) printf "%f ", eae >>"e.dat";
printf "%f ",sps-sae >>"s.dat";
printf "%f ",pps-pae >>"p.dat";
printf "%f ",eps-eae >>"e.dat";
if (calc==last) printf "\n" >>"s.dat";
if (calc==last) printf "\n" >>"p.dat";
if (calc==last) printf "\n" >>"e.dat";
}' $calc/$calc.tst_$occ.out
done
done

cat <<EOF | gnuplot
set term post eps dl 2
set out 'all.eps'
set da s l
set xlabel "2s occupation"
set multiplot
set origin 0,0
set size 0.5,1
set ylabel "E(2s): PS - AE (Ry)"
set key bottom right
plot 's.dat' u 1:3 t "NC", 's.dat' u 1:4 t "NChard", 's.dat' u 1:5 t "US", 's.dat' u 1:6 t "UShard", 's.dat' u 1:7 t "PAW-AE-QAE", 's.dat' u 1:8 t "PAW-NChard-Qhard" w p, 's.dat' u 1:9 t "PAW-NChard-Qsmooth" w p
set nokey
set origin 0.55,0.5
set size 0.45,0.5
set ylabel "E(2p): PS - AE (Ry)"
plot 'p.dat' u 1:3 t "NC", 'p.dat' u 1:4 t "NChard", 'p.dat' u 1:5 t "US", 'p.dat' u 1:6 t "UShard", 'p.dat' u 1:7 t "PAW-AE-QAE", 'p.dat' u 1:8 t "PAW-NChard-Qhard" w p, 'p.dat' u 1:9 t "PAW-NChard-Qsmooth" w p
set origin 0.55,0.0
set size 0.45,0.5
set ylabel "deltaE: PS - AE (Ry)"
plot 'e.dat' u 1:3 t "NC", 'e.dat' u 1:4 t "NChard", 'e.dat' u 1:5 t "US", 'e.dat' u 1:6 t "UShard", 'e.dat' u 1:7 t "PAW-AE-QAE", 'e.dat' u 1:8 t "PAW-NChard-Qhard" w p, 'e.dat' u 1:9 t "PAW-NChard-Qsmooth" w p
set nomultiplot
! gv -antialias -scale 3 all.eps &
EOF

cat <<EOF | gnuplot
set term post eps dl 2
set out 'all2.eps'
set da s l
set xlabel "2s occupation"
set multiplot
set origin 0,0
set size 0.5,1
set ylabel "E(2s): PAW - reference (Ry)"
set key bottom right
plot 's.dat' u 1:7 t "PAW-AE-QAE", 's.dat' u 1:(\$8-\$4) t "PAW-NChard-Qhard" w p, 's.dat' u 1:(\$9-\$4) t "PAW-NChard-Qsmooth"
set nokey
set origin 0.55,0.5
set size 0.45,0.5
set ylabel "E(2p):  PAW - reference (Ry)"
plot 'p.dat' u 1:7 t "PAW-AE-QAE", 'p.dat' u 1:(\$8-\$4) t "PAW-NChard-Qhard" w p, 'p.dat' u 1:(\$9-\$4) t "PAW-NChard-Qsmooth"
set origin 0.55,0.0
set size 0.45,0.5
set ylabel "deltaE:  PAW - reference (Ry)"
plot 'e.dat' u 1:7 t "PAW-AE-QAE", 'e.dat' u 1:(\$8-\$4) t "PAW-NChard-Qhard" w p, 'e.dat' u 1:(\$9-\$4) t "PAW-NChard-Qsmooth"
set nomultiplot
! gv -antialias -scale 3 all2.eps &
EOF

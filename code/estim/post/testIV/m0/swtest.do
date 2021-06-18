*** Conditional F test (Sanderson-Windmeijer) for model 0 (Table A16 RC logit I)
cd ~/Documents/GitHub/FightBrand/code/estim/post/testIV/m0

* BLP IV
import delimited swtest_blp.csv, clear
egen networkRegion = group(network region)
ivreg2 delta x1-x63 (jacob* = z*), ffirst cluster(networkRegion)

* Quad IV
import delimited swtest_diff-quad.csv, clear
egen networkRegion = group(network region)
ivreg2 delta x1-x63 (jacob* = z*), ffirst cluster(networkRegion)

* Local IV
import delimited swtest_diff-local.csv, clear
egen networkRegion = group(network region)
ivreg2 delta x1-x63 (jacob* = z*), ffirst cluster(networkRegion)

/*** Replication by hand
ivreg2 delta x1-x63 (jacob1-jacob3 = z*), ffirst

ivregress 2sls jacob1 x1-x63 (jacob2 jacob3 = z*)
predict vhat, r
regress vhat x1-x63 z*
test z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 z11 z12 z13 z14
scalar Fsw = r(F) * r(df) / (r(df)-2)
di Fsw

drop vhat
ivregress 2sls jacob2 x1-x63 (jacob1 jacob3 = z*)
predict vhat, r
regress vhat x1-x63 z*
test z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 z11 z12 z13 z14
scalar Fsw = r(F) * r(df) / (r(df)-2)
di Fsw

drop vhat
ivregress 2sls jacob3 x1-x63 (jacob1 jacob2 = z*)
predict vhat, r
regress vhat x1-x63 z*
test z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 z11 z12 z13 z14
scalar Fsw = r(F) * r(df) / (r(df)-2)
di Fsw

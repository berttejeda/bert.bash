diag.internet () { ping -w 1 -c 1 8.8.8.8 2&>1 /dev/null || echo No internet; }

#@ diag

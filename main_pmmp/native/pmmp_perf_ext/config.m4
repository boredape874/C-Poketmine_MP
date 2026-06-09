PHP_ARG_ENABLE(pmmp_perf_ext, whether to enable pmmp_perf_ext,
[  --enable-pmmp_perf_ext Enable PMMP performance extension])

if test "$PHP_PMMP_PERF_EXT" != "no"; then
  PHP_NEW_EXTENSION(pmmp_perf_ext, pmmp_perf_ext.c, $ext_shared)
fi

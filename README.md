# cert-manager

A commodore Component for cert-manager

Known issues:

- The chart uses the clusters api version to decide which version of CRDs to install.
  When using `helm template`, the chart will install CRDs named legacy (see [issue #543](https://github.com/deepmind/kapitan/issues/543)).

# Commodore Component: cert-manager

This is a [Commodore][commodore] Component for cert-manager.

This repository is part of Project Syn.
For documentation on Project Syn and this component, see https://syn.tools.

## Documentation

Documentation for this component is written using [Asciidoc][asciidoc] and [Antora][antora].
It is located in the [docs/](docs) folder.
The [Divio documentation structure](https://documentation.divio.com/) is used to organize its content.

## Known issues

- The chart uses the clusters api version to decide which version of CRDs to install.
  When using `helm template`, the chart will install CRDs named legacy (see [issue #543](https://github.com/deepmind/kapitan/issues/543)).

## Contributing and license

This library is licensed under [BSD-3-Clause](LICENSE).
For information about how to contribute see [CONTRIBUTING](CONTRIBUTING.md).

[commodore]: https://docs.syn.tools/commodore/index.html
[asciidoc]: https://asciidoctor.org/
[antora]: https://antora.org/

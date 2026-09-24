# OpenID Federation Well-Known Binding 1.0

This repository contains the OpenID Federation Well-Known Binding 1.0 draft specification.

## Overview

This specification binds an OpenID Federation 1.0 Entity to the documents it publishes at well-known URIs, and to documents those documents reference, such as JSON Web Key Sets. The Entity signs digests of these documents in its own Entity Configuration. A verifier holding a Trust Anchor key can then authenticate them, and the keys they lead to, without relying on DNS or the Web PKI. The documents are served unchanged, and the Trust Anchor re-signs nothing when they change.

## Status

This is an individual draft for the OpenID Connect Working Group. It has not been adopted by the working group.

## Builds

You can view the latest editors' draft at [https://dickhardt.github.io/well-known-binding/main.html](https://dickhardt.github.io/well-known-binding/main.html).

Previews for each branch of this project are automatically built and published at the URL https://dickhardt.github.io/well-known-binding/$branchname.html.
Previews for branches associated with pending Pull Requests are accessible using this pattern.

To build locally, install [mmark](https://github.com/mmarkdown/mmark) and [xml2rfc](https://pypi.org/project/xml2rfc/), then run `make`.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) to learn how to contribute to this project.

## Contact

For further information and to get involved, please visit the [OpenID Connect Working Group website](https://openid.net/wg/connect/).

# OpenID Federation Well-Known Binding 1.0

This repository contains the OpenID Federation Well-Known Binding 1.0 draft specification.

## Overview

This specification binds an OpenID Federation 1.1 Entity to the documents it publishes at well-known URIs, and to the JSON Web Key Sets those documents reference. The Entity signs digests of these documents in its own Entity Configuration. A verifier that validates the Entity's Trust Chain can then authenticate them, including the protocol keys in the JSON Web Key Sets, without relying only on DNS or the Web PKI. The documents are served unchanged, and only the Entity re-signs when they change.

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

%%%
title = "OpenID Federation Well-Known Binding 1.0"
abbrev = "OpenID-Federation-WK-Binding"
ipr = "none"
workgroup = "OpenID Connect"
keyword = ["federation", "trust mark", "well-known", "metadata", "jwks", "digest"]
category = "std"
date = 2026-09-24T00:00:00Z

[seriesInfo]
name = "Internet-Draft"
value = "openid-federation-well-known-binding-1_0"
status = "standard"

[[author]]
initials = "D."
surname = "Hardt"
fullname = "Dick Hardt"
organization = "Hellō"
  [author.address]
  email = "dick.hardt@gmail.com"

%%%

<reference anchor="OpenID.Federation" target="https://openid.net/specs/openid-federation-1_0.html">
  <front>
    <title>OpenID Federation 1.0</title>
    <author initials="R." surname="Hedberg" fullname="Roland Hedberg" role="editor">
      <organization>independent</organization>
    </author>
    <author initials="M.B." surname="Jones" fullname="Michael B. Jones">
      <organization>Self-Issued Consulting</organization>
    </author>
    <author initials="A.Å." surname="Solberg" fullname="Andreas Åkre Solberg">
      <organization>Sikt</organization>
    </author>
    <author initials="J." surname="Bradley" fullname="John Bradley">
      <organization>Yubico</organization>
    </author>
    <author initials="G." surname="De Marco" fullname="Giuseppe De Marco">
      <organization>independent</organization>
    </author>
    <author initials="V." surname="Dzhuvinov" fullname="Vladimir Dzhuvinov">
      <organization>Connect2id</organization>
    </author>
    <date day="17" month="February" year="2026"/>
  </front>
</reference>

<reference anchor="I-D.hardt-oauth-aauth-protocol" target="https://datatracker.ietf.org/doc/draft-hardt-oauth-aauth-protocol">
  <front>
    <title>AAuth Protocol</title>
    <author initials="D." surname="Hardt" fullname="Dick Hardt">
      <organization>Hellō</organization>
    </author>
    <date year="2026"/>
  </front>
</reference>

.# Abstract

This specification binds an OpenID Federation 1.0 Entity to the documents it publishes at well-known URIs, and to the JSON Web Key Sets those documents reference. The Entity signs digests of these documents in its own Entity Configuration. A verifier that validates the Entity's Trust Chain can then authenticate them, including the protocol keys in the JSON Web Key Sets, without relying only on DNS or the Web PKI. The documents are served unchanged, and only the Entity re-signs when they change. For a JWK Set, this is an alternative to `signed_jwks_uri` that leaves the JWK Set as plain JSON. The mechanism applies to any well-known URI, with no per-protocol profile.

Optionally, a well-known document that is a JSON object can also state which of the Entity's Trust Marks apply to the role it describes, and which Trust Marks the Entity requires of its counterparties.

.# Notices

[OpenID Foundation copyright and IPR notices, per OIDF specification boilerplate.]

{mainmatter}

# Introduction

Many protocols have a server publish metadata at a well-known URI [@!RFC8615]. Examples are OAuth 2.0 Authorization Server Metadata [@!RFC8414], OAuth 2.0 Protected Resource Metadata [@!RFC9728], and the AAuth Protocol [@?I-D.hardt-oauth-aauth-protocol]. The metadata's `jwks_uri` member locates the JSON Web Key Set (JWK Set) that holds the server's protocol keys, such as the keys it signs tokens with. Both documents are fetched over HTTPS, so the binding between the server's identifier and its protocol keys rests on DNS and the Web PKI: whoever can answer for the origin can publish keys for it.

That is sufficient for many deployments. It is not sufficient where the Web PKI is not an acceptable root of trust for protocol keys, or where a party needs to know more than "this origin published these keys", for example that the origin belongs to an accredited payment institution.

OpenID Federation 1.0 [@!OpenID.Federation] binds an Entity's Federation Entity Keys to its Entity Identifier through a Trust Chain, independently of the Web PKI. It expresses accreditation of an Entity by a third party as Trust Marks. For OpenID Connect, it defines a different binding for metadata: OpenID Provider and Relying Party metadata is carried in Entity Statements, and metadata policies cascade down the Trust Chain to produce the metadata a verifier uses ([@!OpenID.Federation], Section 6.1). It binds a JWK Set inline as `jwks`, or as a signed JWT at `signed_jwks_uri` ([@!OpenID.Federation], Section 5.2.1). It does not authenticate documents that a protocol publishes at its own well-known URI, or a JWK Set served as plain JSON.

This specification provides that binding. An Entity lists, in a `well_known_bindings` claim in its Entity Configuration, digests of its well-known documents and of the JWK Sets they reference by `jwks_uri`. The Entity signs these digests with its Federation Entity Key, which the Trust Chain binds to its Entity Identifier. A verifier that validates the Trust Chain and checks the digests has authenticated the Entity's protocol metadata and protocol keys. It relies on DNS and the Web PKI only for transport and as a redundant check.

The binding needs no Trust Marks. As an optional addition, this specification defines two members with which a well-known document that is a JSON object states which of the Entity's Trust Marks apply to the role it describes, and which Trust Marks the Entity requires of the Entities it deals with (#trust-marks-in-documents). The document's digest authenticates these statements.

## Non-Goals {#non-goals}

- **Not a change to OpenID Federation.** This specification defines one Entity Configuration claim, `well_known_bindings`, and nothing else inside Entity Statements.
- **Not a change to the protocols whose documents are bound.** Documents are served unchanged at their existing locations, and each protocol processes them as before, including its checks on identifier members such as `issuer`. A verifier adds the checks in (#verification). The only additions to documents are the two optional Trust Mark members.
- **Not Trust Mark issuance.** Which parties issue which Trust Marks, what a Trust Mark certifies, and how an Entity obtains one are properties of each federation. OpenID Federation already expresses which issuers are recognized for which types (`trust_mark_issuers`, `trust_mark_owners`).
- **Not mandatory.** A verifier decides by its own policy whether to require federation verification of a given peer.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# Terminology

Terms defined in [@!OpenID.Federation] are used with the same meaning, in particular Entity, Entity Identifier, Entity Type, Entity Statement, Entity Configuration, Subordinate Statement, Trust Anchor, Trust Chain, Trust Mark, Trust Mark Issuer, Federation Entity Keys, and Resolved Metadata.

This specification also uses:

- **Superior**: An Entity above another Entity in a federation, such as an Intermediate Entity or a Trust Anchor ([@!OpenID.Federation], Section 1.2). The Superior directly above an Entity issues the Subordinate Statement about it.
- **Well-known suffix**: The URI suffix of a well-known URI ([@!RFC8615], Section 3.1), that is, the path segment following `/.well-known/`, such as `oauth-authorization-server`.
- **Covered document**: A document served at a well-known URI whose digest an Entity lists under this specification. A covered document can be in any format.
- **Protocol keys**: The keys in the JWK Set at a covered document's `jwks_uri`, which the Entity uses in the protocol the document belongs to. They are distinct from the Entity's Federation Entity Keys, which sign its Entity Configuration.
- **Digest**: A hash of a document's exact octets, computed and encoded as defined in (#digest-computation).
- **Verifier**: A party that fetches an Entity's covered documents and checks them as defined in (#verification).

# Overview {#overview}

OpenID Federation defines how a verifier resolves and validates the Entity's Trust Chain ([@!OpenID.Federation], Section 10). The figure shows that as one step, after the digest checks (#verification).

~~~ ascii-art
Verifier                               Entity
                                   entity.example
   |                                      |
   | GET /.well-known/<suffix>            |
   |------------------------------------->|
   |  covered document                    |
   |<-------------------------------------|
   |                                      |
   | GET jwks_uri                         |
   |------------------------------------->|
   |  JWK Set                             |
   |<-------------------------------------|
   |                                      |
   | GET /.well-known/openid-federation   |
   |------------------------------------->|
   |  Entity Configuration                |
   |<-------------------------------------|
   |                                      |
   +- check covered document digest       |
   +- check JWK Set digest                |
   +- validate Trust Chain                |
   +- check Trust Marks (optional)        |
~~~
Figure: Verifying a covered document and its JWK Set

| Statement or document | Signed by | Binds |
|---|---|---|
| Trust Chain | Superiors, up to the Trust Anchor | Entity Identifier to the Entity's Federation Entity Keys |
| Entity Configuration | Entity's Federation Entity Key | Digests of covered documents and JWK Sets |
| Covered document | Bound by digest | Protocol metadata, including `jwks_uri` |
| JWK Set at `jwks_uri` | Bound by digest | Protocol keys |

The Entity signs the digests itself. Updating a covered document or rotating a protocol key therefore requires only that the Entity re-sign its own Entity Configuration. No Superior is involved.

# Well-Known Bindings Claim {#well-known-bindings}

An Entity that uses this specification includes the following claim in its Entity Configuration. Like the claims in [@!OpenID.Federation], Section 3.1.2, it does not appear in Subordinate Statements, and a verifier ignores it there.

- `well_known_bindings` (REQUIRED): JSON object. Each member name is a well-known suffix. Each member value is a JSON object with the following members:
    - `digests` (REQUIRED): Non-empty JSON array of digests of the covered document.
    - `jwks_digests`: Non-empty JSON array of digests of the JWK Set at the covered document's `jwks_uri`. REQUIRED if the covered document is a JSON object with a `jwks_uri` member, and MUST NOT be present otherwise.
    - `digest_alg` (OPTIONAL): String. The hash algorithm for every digest in this member value, identified by its name in the IANA "Hash Algorithms for HTTP Digest Fields" registry established by [@!RFC9530]. It MUST have status "Active" in that registry. Default: `sha-256`.

Implementations MUST support `sha-256`.

A covered document or JWK Set matches if its digest equals any element of its array, `digests` or `jwks_digests`. An array has more than one element only while that covered document or JWK Set is being replaced (#updates).

Other specifications MAY define additional members of a `well_known_bindings` member value, for example digests of the image at a covered document's `logo_uri`. A verifier ignores members it does not understand.

The Entity SHOULD NOT list `well_known_bindings` in the `crit` claim ([@!OpenID.Federation], Section 3.1.1), so that verifiers that do not implement this specification can still use its Entity Configuration.

The Entity Configuration still declares the Entity's Entity Types in its `metadata` claim, and every Entity has at least one ([@!OpenID.Federation], Sections 1.2 and 3.1.1). An Entity whose protocol has no Entity Type, such as an AAuth server, can declare `federation_entity` ([@!OpenID.Federation], Section 5.1.1).

Example, for the authorization server in (#example-as):

```json
"well_known_bindings": {
  "oauth-authorization-server": {
    "digests": [
      "O-YmLY31Z3ljOBWYLt1JjjI0xbOMNA2HVuGDeHwYJAo"
    ],
    "jwks_digests": [
      "HRb-DHuBwopK4jeYA9XkP7OPK_u7kxeth9NSptaj8r4"
    ]
  }
}
```

(#examples) has examples for other well-known documents.

## Digest Computation {#digest-computation}

A digest is computed over the content of the HTTP response that delivered the document, after removing any content codings ([@!RFC9110], Section 8.4). The input is the exact octets, with no parsing, canonicalization, or re-serialization. The hash algorithm is the entry's `digest_alg`. The digest is the base64url encoding of the hash output without padding ([@!RFC7515], Section 2).

While a digest is listed, the Entity MUST serve the document with the same octets on every request, whatever the requester or the result of content negotiation. An intermediary that transforms content, for example by minification or re-serialization, causes verification to fail. The Entity SHOULD serve covered documents and JWK Sets with `Cache-Control: no-transform` ([@!RFC9111], Section 5.2.2.6).

# Verification {#verification}

A verifier performs the following steps when it discovers a peer's covered document. They are in addition to the checks defined by the peer's protocol. Steps 1 and 2 are fetches the protocol already makes.

1. Fetch the covered document from the location its protocol defines. Do not act on its content yet, other than in step 2 (#unauthenticated-content).
2. If the covered document has a `jwks_uri` member, fetch the JWK Set at that URL.
3. Fetch the Entity Configuration for the identifier the protocol uses for the peer, such as `issuer` in [@!RFC8414] or `resource` in [@!RFC9728] (#path-identifiers). Its Entity Identifier MUST equal that identifier. Validate it per [@!OpenID.Federation], Section 3.2.
4. In its `well_known_bindings` claim, take the member named by the covered document's well-known suffix. If it is absent, verification fails.
5. Compute the covered document's digest (#digest-computation), and compare it to `digests`. If a JWK Set was fetched in step 2, compute its digest and compare it to `jwks_digests`. If `jwks_digests` is absent, or no element of either array matches, verification fails.
6. Resolve and validate a Trust Chain from the Entity Configuration to one of the verifier's configured Trust Anchors, including the signature on each Entity Statement in it ([@!OpenID.Federation], Section 10). The verifier SHOULD perform this step, and MUST if its policy requires federation verification of the peer. If it fails, verification fails.
7. The verifier MAY check the Trust Marks it needs among those the covered document lists in `trust_mark_types` (#verifying-trust-marks). This step requires step 6.

Without step 6, verification relies on DNS and the Web PKI (#without-trust-chain). The verifier uses the covered document, and the protocol keys in the JWK Set, only after the steps it performs succeed.

## Identifiers with a Path {#path-identifiers}

[@!RFC8414] and [@!RFC9728] allow an identifier with a path component. The Entity Identifier is the same string, path included, so the Entity Configuration is at the identifier with `/.well-known/openid-federation` appended ([@!OpenID.Federation], Section 9). The protocol can place its own document differently: [@!RFC8414], Section 3.1 and [@!RFC9728], Section 3.1 insert the well-known path between the host and the path. The verifier fetches each document where its own specification places it (#example-path).

## Caching {#caching}

A verifier MAY cache the outcome of verification, but not beyond the Entity Configuration's `exp`, nor beyond the expiration time of the Trust Chain if it resolved one ([@!OpenID.Federation], Section 10.4). Within that period, a verifier can re-fetch a covered document or JWK Set, for example on a protocol key with an unknown `kid`. It checks the new content against the digests in its cached Entity Configuration.

# Document Updates {#updates}

Replacing a covered document or JWK Set changes its digest. The Entity overlaps the old and new digests, so that no verifier holding a valid cached Entity Configuration sees a document it cannot match:

1. Issue an Entity Configuration whose digest array contains both the current digest and the digest of the replacement document.
2. Wait until every Entity Configuration that lists only the current digest has expired, per its `exp` claim.
3. Replace the document.
4. Issue Entity Configurations whose digest array contains only the new digest.

Step 4 can happen at the Entity Configuration's next routine re-issue. The Entity Configuration lifetime bounds the wait in step 2. An Entity that updates its documents often SHOULD use a short `exp`. Rotating a protocol key is a replacement of the JWK Set, done the same way.

# Trust Marks in Well-Known Documents {#trust-marks-in-documents}

This section is OPTIONAL to implement. The binding in the preceding sections does not depend on it.

An Entity's Trust Marks are in the `trust_marks` claim of its Entity Configuration ([@!OpenID.Federation], Section 3.1.2). This specification does not carry Trust Marks anywhere else, and does not alter them. A Trust Mark says nothing about covered documents or protocol keys, and is unaffected when they change.

A covered document that is a JSON object MAY contain the two members defined below. The document makes these statements for the role it describes, and its digest authenticates them. When one origin serves several roles, each role's document makes its own statements.

[@!RFC8414], Section 2 permits additional metadata parameters, and [@!RFC9728], Section 3.2 requires consumers to ignore parameters they do not understand. Adding these members therefore does not affect existing consumers.

## trust_mark_types {#trust-mark-types}

- `trust_mark_types` (OPTIONAL): JSON array of strings. Each element is a `trust_mark_type` that the Entity presents as relevant to the role this document describes.

An Entity Configuration can hold Trust Marks for many purposes, and `trust_mark_types` selects those that apply to one role. An Entity *holds* a Trust Mark type in a role when all of the following are true:

1. Its covered document for that role lists the type in `trust_mark_types`.
2. Its Entity Configuration contains a Trust Mark of that type that is valid per [@!OpenID.Federation], Section 7.3.
3. If the Trust Anchor's `trust_mark_issuers` claim lists issuers for that type, the Trust Mark's issuer is one of them.

A verifier evaluating the Entity in a role considers only the types the Entity holds in that role.

## trust_mark_types_required {#trust-mark-types-required}

- `trust_mark_types_required` (OPTIONAL): JSON object. Each member name is the well-known suffix of the covered document that describes a counterparty role. Each member value is a non-empty JSON array of `trust_mark_type` strings that an Entity in that role MUST hold (#trust-mark-types) for this Entity to deal with it in that role.

Example: an OAuth protected resource that accepts access tokens only from authorization servers holding a payment-institution Trust Mark. (#example-as) shows an authorization server that meets this requirement.

```json
{
  "resource": "https://api.bank.example",
  "authorization_servers": ["https://as.bank.example"],
  "jwks_uri": "https://api.bank.example/jwks",
  "trust_mark_types": [
    "https://openfinance.example/account-servicing"
  ],
  "trust_mark_types_required": {
    "oauth-authorization-server": [
      "https://openfinance.example/payment-institution"
    ]
  }
}
```

`trust_mark_types_required` is for discovery. It lets a client learn before a call that the resource would refuse its authorization server, and lets an operator learn which Trust Marks it needs to obtain. The Entity enforces its requirements from its own policy, whether or not it publishes them (#published-requirements).

## Verifying Trust Marks {#verifying-trust-marks}

A verifier whose policy requires Trust Marks of a peer in a role first verifies the peer's covered document for that role, including step 6 (#verification). It then checks that the peer holds each required type in that role (#trust-mark-types).

## Trust Mark Requirement Errors {#errors}

This specification defines an error that a protocol MAY adopt. An Entity returns it when it refuses to deal with a counterparty because the counterparty does not hold its required Trust Marks. A protocol that uses JSON error responses with an `error` member conveys it with these members:

- `error`: `trust_mark_required`
- `entity` (REQUIRED): The Entity Identifier of the counterparty that does not meet the requirement.
- `trust_mark_types` (REQUIRED): JSON array of the required `trust_mark_type` values that the counterparty does not hold.

The adopting protocol defines the HTTP status code and where the error is returned. The `entity` can identify a party other than the requester, such as the requester's authorization server. A party that relays the error relays it unchanged.

A peer that fails verification (#verification) has not been refused on Trust Marks. The protocol reports that as a metadata or key discovery failure.

# Security Considerations {#security-considerations}

## What the Trust Chain Attests

The Trust Chain attests only that the Entity's Federation Entity Keys belong to its Entity Identifier. The Entity itself attests the digests, and therefore its covered documents, its JWK Sets, and the Trust Mark statements in them. A verifier trusts the Entity's statements about its own documents exactly as far as it trusts the Entity's Federation Entity Keys. Only Trust Marks convey accreditation of the Entity by third parties.

## DNS and Transport

Once the Trust Chain is validated and the digests match, DNS and TLS serve only as transport and as a redundant check. An attacker who can answer for the origin can withhold documents but cannot substitute them.

## Federation Key Compromise

An attacker holding an Entity's Federation Entity Key can issue an Entity Configuration that lists digests of documents the attacker chooses, and so substitute the Entity's protocol keys. This lasts until the Superior removes the key from its Subordinate Statement and Trust Chains cached by verifiers expire. Entities SHOULD protect Federation Entity Keys at least as well as their protocol keys, and SHOULD NOT hold the two in the same place.

## Trust Anchor Key Rollover

The Trust Anchor's Federation Entity Keys configured in a verifier are its root of trust. The Trust Anchor publishes its next key in its Entity Configuration before signing with it ([@!OpenID.Federation], Section 11.2). A verifier that does not refresh the Trust Anchor's Entity Configuration within that overlap can no longer validate Trust Chains, and must be re-configured out of band. OpenID Federation defines no hold-down period comparable to [@?RFC5011], so a compromised current Trust Anchor key can introduce a replacement key that verifiers accept immediately.

## Unauthenticated Content Before Verification {#unauthenticated-content}

A covered document and its JWK Set are unauthenticated until their digests match in step 5 of (#verification), and, for a verifier whose policy requires federation verification, until the Trust Chain is validated in step 6. Before then, the verifier MUST NOT act on any member of the covered document other than fetching the JWK Set in step 2. This includes URL-valued members, `trust_mark_types`, and `trust_mark_types_required`. A modified covered document can make the verifier fetch a JWK Set from a URL of an attacker's choosing. The verifier discards that JWK Set when its digest does not match.

## Verification Without a Trust Chain {#without-trust-chain}

A verifier that skips step 6 of (#verification) has checked only that the covered document and JWK Set match an Entity Configuration served by the same origin. That detects a document changed without a matching change to the Entity Configuration. It does not detect an attacker who can answer for the origin, who can serve a matching Entity Configuration. Such a verifier relies on DNS and the Web PKI as it would without this specification.

## Other URLs in Covered Documents

`jwks_digests` authenticates only the JWK Set. For any other URL-valued member of a covered document, the URL is authenticated but the document at that URL is not. A specification that needs such a document authenticated can define a member for its digests (#well-known-bindings).

## Published Requirements Are Not Enforcement {#published-requirements}

`trust_mark_types_required` informs counterparties; it does not bind the publisher. Whether a verifier requires federation verification or Trust Marks of a peer comes from the verifier's own configuration, never from the peer's documents. A verifier whose policy requires federation verification of a peer MUST NOT fall back to Web PKI trust because the peer's covered document omits `trust_mark_types`, or because the peer serves no Entity Configuration.

## Trust Mark Selection

`trust_mark_types` narrows which Trust Marks count for a role. It cannot add one, because a listed type counts only with a valid Trust Mark (#trust-mark-types). Where the Trust Mark Issuer offers a Trust Mark Status endpoint ([@!OpenID.Federation], Section 8.4), the verifier MAY query it.

## Resolution Cost

Trust Chain resolution adds fetches to metadata discovery. An attacker who can cause a verifier to discover many peers can use this to amplify load on the verifier and on Superiors' fetch endpoints. Verifiers SHOULD cache per (#caching), and SHOULD bound the rate of Trust Chain resolution.

# Privacy Considerations {#privacy-considerations}

Resolving a peer's Trust Chain reveals to the peer's Superiors, through requests to their fetch endpoints, that the verifier is evaluating that peer ([@!OpenID.Federation], Section 19.3). A verifier that considers this sensitive can use a resolver it operates ([@!OpenID.Federation], Section 10.6), or cache Subordinate Statements for their full lifetime.

A Trust Mark in an Entity Configuration is public. An Entity MAY omit from its Entity Configuration any Trust Mark it does not want to disclose.

# IANA Considerations {#iana-considerations}

## JSON Web Token Claims

This specification requests registration of the following in the "JSON Web Token Claims" registry established by [@!RFC7519]:

- Claim Name: `well_known_bindings`
- Claim Description: Digests binding an Entity's well-known documents and JWK Sets to its Entity Configuration
- Change Controller: OpenID Foundation Artifact Binding Working Group - openid-specs-ab@lists.openid.net
- Specification Document(s): (#well-known-bindings) of this specification

`digest_alg` values are taken from the "Hash Algorithms for HTTP Digest Fields" registry established by [@!RFC9530].

# Open Issues

*Note: This section is to be removed before publication.*

- Whether verifiers should re-fetch the Entity Configuration once on a digest mismatch, as a fallback for Entities that do not sequence updates per (#updates).
- Whether to register `trust_mark_types` and `trust_mark_types_required` in the "OAuth Authorization Server Metadata" [@!RFC8414] and "OAuth Protected Resource Metadata" [@!RFC9728] registries, and `trust_mark_required` in the "OAuth Extensions Error Registry" [@!RFC6749].
- Whether to also define a digest companion for a `jwks_uri` that appears directly in Entity Type metadata, as a plain-JSON alternative to `signed_jwks_uri` outside well-known documents.

# Document History

*Note: This section is to be removed before publication.*

- -00
    - Initial draft.

# Acknowledgments

TBD

{backmatter}

# Examples {#examples}

Digest values are illustrative. Entity Configurations are shown as JWT Claims Sets. In each, `jwks` holds the Entity's Federation Entity Keys, and `jwks_digests` binds the JWK Set that holds its protocol keys.

## OAuth Authorization Server {#example-as}

Entity Configuration of an authorization server, served at `https://as.bank.example/.well-known/openid-federation`. It holds the payment-institution Trust Mark type in its authorization server role, so it meets the requirement of the protected resource in (#trust-mark-types-required).

```json
{
  "iss": "https://as.bank.example",
  "sub": "https://as.bank.example",
  "iat": 1790236800,
  "exp": 1790323200,
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "kid": "fed-2026-09",
        "x": "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
        "y": "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0"
      }
    ]
  },
  "authority_hints": ["https://ta.example"],
  "metadata": {
    "oauth_authorization_server": {}
  },
  "well_known_bindings": {
    "oauth-authorization-server": {
      "digests": [
        "O-YmLY31Z3ljOBWYLt1JjjI0xbOMNA2HVuGDeHwYJAo"
      ],
      "jwks_digests": [
        "HRb-DHuBwopK4jeYA9XkP7OPK_u7kxeth9NSptaj8r4"
      ]
    }
  },
  "trust_marks": [
    {
      "trust_mark_type":
        "https://openfinance.example/payment-institution",
      "trust_mark": "eyJ0eXAiOiJ0cnVzdC1tYXJrK2p3dCIs..."
    }
  ]
}
```

The `oauth_authorization_server` member declares the Entity Type. It is empty because the authorization server's metadata is in its covered document, at `https://as.bank.example/.well-known/oauth-authorization-server`:

```json
{
  "issuer": "https://as.bank.example",
  "authorization_endpoint": "https://as.bank.example/auth",
  "token_endpoint": "https://as.bank.example/token",
  "jwks_uri": "https://as.bank.example/jwks",
  "response_types_supported": ["code"],
  "trust_mark_types": [
    "https://openfinance.example/payment-institution"
  ]
}
```

## OAuth Protected Resource {#example-pr}

Excerpt of the Entity Configuration of the protected resource in (#trust-mark-types-required), served at `https://api.bank.example/.well-known/openid-federation`. Its covered document lists the account-servicing type, and the Trust Mark here completes what it needs to hold that type in its protected resource role (#trust-mark-types).

```json
"well_known_bindings": {
  "oauth-protected-resource": {
    "digests": [
      "xghE89DclS2ArTw7gSvMnNCdhxR94zJ6dSvAS8CSXiE"
    ],
    "jwks_digests": [
      "OpHXW1JuZaCwv6-hjpEq2A6w0HoObL6tePwr86Gs1H4"
    ]
  }
},
"trust_marks": [
  {
    "trust_mark_type":
      "https://openfinance.example/account-servicing",
    "trust_mark": "eyJ0eXAiOiJ0cnVzdC1tYXJrK2p3dCIs..."
  }
]
```

## AAuth Person Server

Excerpt of the Entity Configuration of an AAuth Person Server, served at `https://ps.example/.well-known/openid-federation`, during a protocol key rotation (#updates). AAuth defines no Entity Type, so the Entity Configuration declares `federation_entity` (#well-known-bindings). `jwks_digests` holds the digests of the current and the replacement JWK Set.

```json
"metadata": {
  "federation_entity": {}
},
"well_known_bindings": {
  "aauth-person.json": {
    "digests": [
      "ZSfJNhovRpxSda_LXQblMBM2fNIxmV3hPcchhxE4g4I"
    ],
    "jwks_digests": [
      "pUy6FU8E5nvRlZ03W9oFI02hXALOn9p65Gmh05LtEZQ",
      "2wqEXWiqltPQ5Vr3zaudefAwhTdmRGz8yvlGrtcSVys"
    ]
  }
}
```

The covered document at `https://ps.example/.well-known/aauth-person.json`:

```json
{
  "issuer": "https://ps.example",
  "auth_token_endpoint": "https://ps.example/token",
  "person_token_endpoint": "https://ps.example/person",
  "jwks_uri": "https://ps.example/.well-known/jwks.json"
}
```

## Collocated Roles {#example-collocated}

An origin that is both an OAuth authorization server and a protected resource lists one covered document per role. Each document makes its own Trust Mark statements. Both reference the same JWK Set, so their `jwks_digests` are equal.

```json
"well_known_bindings": {
  "oauth-authorization-server": {
    "digests": [
      "DzTlzOI0wxzHdCD43RS-AdGY3RB4KX4VB0T3k73D7_Q"
    ],
    "jwks_digests": [
      "tUGsanRBidFVjcN7TNR0U4GpwLNg-9JEcGgooLMMBhY"
    ]
  },
  "oauth-protected-resource": {
    "digests": [
      "xOKnpnaLGfEscsd0LtJ2KO7io1UqbfB5QnlHIlv0jL0"
    ],
    "jwks_digests": [
      "tUGsanRBidFVjcN7TNR0U4GpwLNg-9JEcGgooLMMBhY"
    ]
  }
}
```

## Identifier with a Path {#example-path}

An authorization server has issuer `https://idp.example/tenant-a`, and its Entity Identifier is the same string. A verifier fetches:

- the covered document at `https://idp.example/.well-known/oauth-authorization-server/tenant-a` ([@!RFC8414], Section 3.1), and
- the Entity Configuration at `https://idp.example/tenant-a/.well-known/openid-federation` ([@!OpenID.Federation], Section 9).

The `well_known_bindings` member for `oauth-authorization-server` has the same form as for an identifier with no path.

# Design Rationale

## Why a Claim and Not Metadata {#why-claim}

Metadata in OpenID Federation is subject to the Entity's Superiors. A Superior can supply or override metadata parameters in its Subordinate Statement and constrain them with `metadata_policy`, and verifiers use the resulting Resolved Metadata ([@!OpenID.Federation], Section 6.1). The digests are the Entity's own statements about documents only it serves. A Superior that supplied or altered them would have to coordinate every document update and key rotation with the Entity (#updates), which is the dependency this specification removes (#why-entity-signs). A Superior that constrained `digest_alg` would add little, since a verifier enforces the algorithms it accepts from its own policy.

A claim in the Entity Configuration is signed only by the Entity and is outside metadata policy, as `jwks` and `trust_marks` are. It also belongs to no Entity Type, so a verifier finds the entry for a document by its well-known suffix alone. No mapping from protocols to Entity Types is needed, and no per-protocol profile.

## Why Keyed by Well-Known Suffix

The well-known suffix is the one identifier every covered document already has. It is registered in the IANA "Well-Known URIs" registry [@!RFC8615], and the verifier holds it from the discovery step it is already performing.

## Why the Claim Does Not State Locations

The verifier already fetches each covered document from the location its protocol defines, and the Entity Configuration from the location OpenID Federation defines. A location in the claim would be a second source that could disagree with the first. It would also have to encode each protocol's rule for identifiers with a path.

## Why the Entity Signs the Digests {#why-entity-signs}

The alternative is to carry digests in a Trust Mark issued by the Trust Anchor or an accreditation body. That would make every key rotation and metadata change a request to a third party. Accreditation changes rarely; keys and metadata change routinely. Putting the digests in the Entity's own Entity Configuration keeps routine changes self-service, while the Superior still controls which Federation Entity Keys speak for the Entity. Trust Marks carry accreditation only.

## Why Not Sign the Documents

[@!RFC8414] and [@!RFC9728] offer `signed_metadata`, OpenID Federation offers `signed_jwks_uri` ([@!OpenID.Federation], Section 5.2.1), and any document could carry a detached JWS ([@!RFC7515], Appendix F). Each has two costs. Servers must produce and serve signed variants of documents they serve today as plain JSON. Verifiers must handle two formats, each rooted in a different key. With digests, an Entity joins a federation by publishing an Entity Configuration, and nothing it already serves changes except the optional Trust Mark members.

For a JWK Set, the three ways OpenID Federation can bind it compare as follows:

| Binding | JWK Set as served | On protocol key rotation |
|---|---|---|
| `jwks` in Entity Type metadata | Not served separately | Entity re-signs its Entity Configuration, or Superior re-issues its Subordinate Statement if the Superior supplies it |
| `signed_jwks_uri` | JWT signed with a Federation Entity Key | Entity re-signs the JWK Set JWT |
| `jwks_digests` | Plain JSON, unchanged | Entity re-signs its Entity Configuration (#updates) |

With `jwks_digests`, verifiers that do not use OpenID Federation fetch the same JWK Set at the same URL. The Entity keeps one JWK Set, whether or not a given verifier checks the binding.

## Why Arrays of Digests

A digest pins one version of a document, and verifiers cache Entity Configurations for their lifetime. Listing old and new digests together lets the Entity pre-publish the new digest, as OpenID Federation pre-publishes a Trust Anchor's next key. The alternative is to require verifiers to re-fetch on mismatch. That shifts the cost to every verifier and creates a forced-fetch vector, so it is recorded as an open issue.

## Why `digest_alg` and base64url

Base64url values match other digests in JOSE documents (`x5t#S256`, `jkt`). One `digest_alg` per covered document, defaulting to `sha-256`, names the algorithm once rather than in every value, using names from the [@!RFC9530] registry. The cost is that changing a document's algorithm is a cutover rather than an overlap.

## Why the Binding Stands Apart from Trust Marks

Binding keys to an Entity Identifier and accrediting the Entity are separate questions, answered by different parties on different schedules. The Trust Chain answers the first; Trust Marks answer the second. A deployment that wants federation-rooted protocol keys and has no accreditation scheme uses the binding alone. The Trust Mark members are defined here because their authentication depends on the binding, not because the binding depends on them.

## Why the Document States Its Trust Marks

The role a Trust Mark accredits is described by the protocol's own document. Putting `trust_mark_types` and `trust_mark_types_required` in that document keeps each statement with its role, so each role on a shared origin states its own. Carrying them in the Entity Configuration instead would separate them from the role they describe.

## Why JSON Objects Only

The Trust Mark members need a document that can carry named members. Documents in other formats can still be covered by digest, but cannot make Trust Mark statements.

## Why Requirements Are Keyed by Well-Known Suffix

A server often deals with counterparties in several roles, and may require different accreditation of each. The counterparty's well-known suffix names its role without another identifier. It is also the suffix of the document in which the counterparty lists its own `trust_mark_types`.

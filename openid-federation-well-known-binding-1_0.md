%%%
title = "OpenID Federation Well-Known Binding 1.0"
abbrev = "OpenID-Federation-WK-Binding"
ipr = "none"
workgroup = "OpenID Connect"
keyword = ["federation", "trust mark", "well-known", "metadata", "jwks", "digest"]
category = "std"

[seriesInfo]
name = "Internet-Draft"
value = "openid-federation-well-known-binding-1_0"
status = "standard"

date = 2026-09-24T00:00:00Z

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

This specification binds an OpenID Federation 1.0 Entity to the documents it publishes at well-known URIs [@!RFC8615], and to documents those documents reference, such as JSON Web Key Sets. The Entity signs digests of these documents in its own Entity Configuration. A verifier holding a Trust Anchor key can then authenticate them, and the keys they lead to, without relying on DNS or the Web PKI. The documents are served unchanged, and the Trust Anchor re-signs nothing when they change. For a JWK Set, this is an alternative to `signed_jwks_uri` that leaves the JWK Set as plain JSON. The mechanism applies to any well-known URI, with no per-protocol profile.

Optionally, a well-known document that is a JSON object or a JWT can also state which of the Entity's Trust Marks apply to the role it describes, and which Trust Marks the Entity requires of its counterparties.

.# Notices

[OpenID Foundation copyright and IPR notices, per OIDF specification boilerplate.]

{mainmatter}

# Introduction

Many protocols have their servers publish metadata at a well-known URI [@!RFC8615]. Examples are OAuth 2.0 Authorization Server Metadata [@!RFC8414], OAuth 2.0 Protected Resource Metadata [@!RFC9728], and the AAuth Protocol [@?I-D.hardt-oauth-aauth-protocol]. Signing keys are then found by following a `jwks_uri` member of that document. Both documents are fetched over HTTPS. The binding between a server's identifier and its keys therefore rests on DNS and the Web PKI: whoever can answer for the origin can publish keys for it.

That is sufficient for many deployments. It is not sufficient where the Web PKI is not an acceptable root of trust for protocol keys, or where a party needs to know more than "this origin published these keys", for example that the origin belongs to an accredited payment institution.

OpenID Federation 1.0 [@!OpenID.Federation] provides a Trust Chain of Entity Statements that binds an Entity's Federation Entity Keys to its Entity Identifier independently of the Web PKI, and Trust Marks that express accreditation of an Entity by a third party. OpenID Federation carries protocol metadata inline in Entity Statements, and binds a JWK Set through inline `jwks` or through `signed_jwks_uri` ([@!OpenID.Federation], Section 5.2.1). It does not authenticate documents that a protocol publishes at its own well-known URI, or a JWK Set served as plain JSON.

This specification provides that binding (#well-known-documents). An Entity's Entity Configuration carries, in its `federation_entity` metadata, digests of its well-known documents and of documents they reference by URL, such as the JWK Set at `jwks_uri`. The Entity signs these digests with its Federation Entity Key. The Trust Anchor vouches only for that key, through the Subordinate Statement it already issues. A verifier that resolves the Trust Chain and checks the digests has authenticated the Entity's protocol metadata and protocol keys, and relies on DNS for nothing but transport.

The binding is useful on its own. An Entity that holds no Trust Marks, in a federation that issues none, gains a JWK Set bound to its Entity Identifier through the Trust Chain, with no change to the JWK Set or the documents it already serves.

This specification also defines, as an optional addition, two members with which a well-known document that is a JSON object or a JWT states which of the Entity's Trust Marks are relevant to the role it describes, and which Trust Marks the Entity requires of the Entities it deals with (#trust-marks-in-documents). Because the document is digest-bound, these statements are authenticated.

## Non-Goals {#non-goals}

- **Not a change to OpenID Federation.** This specification defines metadata parameters for the `federation_entity` Entity Type ([@!OpenID.Federation], Section 5.1.1) and nothing else inside federation statements.
- **Not a change to the protocols whose documents are bound.** Documents are served unchanged at their existing locations. The protocol's own processing of a document is unchanged, including its checks on identifier members such as `issuer`. This specification adds two members that a JSON-object or JWT document can carry, and a check on the documents from which verification keys are taken.
- **Not Trust Mark issuance.** Out of scope are which parties issue which Trust Marks, what a given Trust Mark certifies, and how an Entity obtains one.
- **Not mandatory.** A verifier decides by its own policy whether to require federation verification for a given peer.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# Terminology

Terms defined in [@!OpenID.Federation] are used with the same meaning, in particular Entity, Entity Identifier, Entity Statement, Entity Configuration, Subordinate Statement, Superior, Trust Anchor, Trust Chain, Trust Mark, Trust Mark Issuer, Federation Entity Keys, and Resolved Metadata.

This specification additionally uses:

- **Well-known suffix**: The path segment following `/.well-known/` in a well-known URI ([@!RFC8615], Section 3), such as `oauth-authorization-server`.
- **Covered document**: A well-known document whose digest is carried in an Entity's metadata under this specification. A covered document can be in any format.
- **Statement-capable document**: A covered document whose content is a JSON object [@!RFC8259], or a JWT [@!RFC7519]. For a JWT, "member" means a claim in the JWT Claims Set.
- **Referenced document**: A document located by a URL-valued top-level member of a statement-capable document, such as the JWK Set at `jwks_uri`, whose digest is also carried under this specification.
- **Digest**: The base64url encoding without padding ([@!RFC7515], Section 2) of the output of a hash algorithm applied to a document's content, as defined in (#digest-computation).

# Overview {#overview}

~~~ ascii-art
Verifier                 Trust Anchor              Entity
(TA key configured       ta.example                as.example
 out of band)
    |                        |                          |
    | GET /.well-known/openid-federation                |
    |-------------------------------------------------->|
    |  Entity Configuration, signed by entity fed key:  |
    |    jwks, authority_hints, trust_marks,            |
    |    metadata.federation_entity.                    |
    |      well_known_documents[<suffix>]               |
    |<--------------------------------------------------|
    |                        |                          |
    | GET fetch?sub=https://as.example                  |
    |----------------------->|                          |
    |  Subordinate Statement, signed by TA key:         |
    |    jwks (entity's Federation Entity Keys)         |
    |<-----------------------|                          |
    |                        |                          |
    | GET /.well-known/<suffix>                         |
    |-------------------------------------------------->|
    |   compare digest; read trust_mark_types           |
    |<--------------------------------------------------|
    | GET referenced document (e.g. jwks_uri)           |
    |-------------------------------------------------->|
    |   compare digest                                  |
    |<--------------------------------------------------|
~~~
Figure: Verifying an Entity's well-known documents

| Statement | Signed by | Binds |
|---|---|---|
| TA Entity Configuration | TA Federation Entity Key | TA keys, `trust_mark_issuers`, `trust_mark_owners` |
| Subordinate Statement about the Entity | Superior's Federation Entity Key | Entity Identifier to the Entity's Federation Entity Keys |
| Entity Configuration of the Entity | Entity's Federation Entity Key | Digests of covered and referenced documents; Trust Marks |
| Trust Mark | Trust Mark Issuer's Federation Entity Key | Entity Identifier to a `trust_mark_type` |
| Covered document (through its digest) | — | `trust_mark_types`, `trust_mark_types_required` for the role it describes |

The Entity signs the digests itself. Updating a covered document or rotating a protocol key therefore requires only that the Entity re-sign its own Entity Configuration. Neither a Superior nor any Trust Mark Issuer is involved.

# Well-Known Documents Metadata {#well-known-documents}

This specification defines the following parameters of `federation_entity` metadata ([@!OpenID.Federation], Section 5.1.1):

- `digest_alg` (OPTIONAL): String. The hash algorithm used for every digest in `well_known_documents`. It is identified by its name in the IANA "Hash Algorithms for HTTP Digest Fields" registry established by [@!RFC9530], and MUST have status "Active" in that registry. Default: `sha-256`. Implementations MUST support `sha-256`.
- `well_known_documents` (OPTIONAL): JSON object. Each member name is a well-known suffix. Each member value is a JSON object with the following members:
    - `digests` (REQUIRED): Non-empty JSON array of strings. Each element is a digest (#digest-computation) of the covered document.
    - `uri` (OPTIONAL): String. The `https` URL of the covered document. REQUIRED when the Entity Identifier has a path component (#document-location).
    - `referenced` (OPTIONAL): JSON object, permitted only for a statement-capable document. Each member name is the name of a top-level member of the covered document whose value is an `https` URL. Each member value is a non-empty JSON array of digests of the document at that URL.

A document is accepted if its digest equals any element of the corresponding array. More than one element is present only while the document is being replaced (#updates).

If a statement-capable document contains a `jwks_uri` member, `referenced` MUST contain a `jwks_uri` member. The Entity chooses which other URL-valued members to cover. The verifier's policy determines which it requires (#unreferenced-urls).

Example:

```json
"metadata": {
  "federation_entity": {
    "well_known_documents": {
      "oauth-authorization-server": {
        "digests": ["2hBq7vQeY0mX1kZ5p8m4a0yP3Q2c0m3m0n7Lr1ZkQ9o"],
        "referenced": {
          "jwks_uri": [
            "Kq3rU8mZ4nT1bV9xW2yA5cD7eF0gH6iJ8kL1mN3oP5q"
          ]
        }
      }
    }
  }
}
```

## Document Location {#document-location}

If `uri` is present, it is the location of the covered document. Otherwise the Entity Identifier MUST have no path component, and the location is `{Entity Identifier}/.well-known/{suffix}`.

Some specifications derive well-known locations for path-based identifiers by inserting the well-known path before the path component ([@!RFC8414], Section 3.1; [@!RFC9728], Section 3.1). An Entity whose Entity Identifier has a path states the location in `uri`, whatever construction its protocol uses.

## Digest Computation {#digest-computation}

A digest is computed over the content of the HTTP response that delivered the document, after removing any content codings ([@!RFC9110], Section 8.4). The input is the exact octets, with no parsing, canonicalization, or re-serialization. For a JWT, these are the octets of its serialization as delivered. The hash algorithm is `digest_alg`. The digest value is the base64url encoding of the hash output without padding ([@!RFC7515], Section 2).

While a given digest is published, the Entity MUST serve the covered and referenced documents with octets that do not vary between requests, including by content negotiation or by requester. Intermediaries that transform content, such as minification or re-serialization, break verification. The Entity SHOULD serve these documents with `Cache-Control: no-transform` ([@!RFC9111], Section 5.2.2.6).

A document whose content varies per request cannot be a covered or referenced document.

## Covered Documents That Are JWTs

A covered document that is a JWT is authenticated by its digest under this specification, whether or not the verifier also validates the JWT's signature. The protocol that defines the document determines whether and how its signature is validated. This specification does not change that.

## Relationship to Inline Metadata

An Entity can also publish, inline in its Entity Configuration, metadata for an Entity Type whose parameters appear in a covered document. The inline metadata and the covered document can both contain a parameter with different values. In that case the verifier MUST treat verification as failed, unless the specification defining that Entity Type states which source is authoritative.

## Relationship to Federation JWK Set Parameters {#jwks-parameters}

OpenID Federation binds a protocol JWK Set to an Entity in two ways ([@!OpenID.Federation], Section 5.2.1): inline in Entity Type metadata as `jwks`, or as a JWT signed with a Federation Entity Key and located by `signed_jwks_uri`. A `jwks_uri` entry in `referenced` is a third way:

| Binding | JWK Set as served | On protocol key rotation |
|---|---|---|
| `jwks` in Entity Type metadata | Not served separately | Entity re-signs its Entity Configuration, or Superior re-issues its Subordinate Statement if the Superior supplies it |
| `signed_jwks_uri` | JWT signed with a Federation Entity Key | Entity re-signs the JWK Set JWT |
| `jwks_uri` in `referenced` | Plain JSON, unchanged | Entity re-signs its Entity Configuration (#updates) |

With a `jwks_uri` entry in `referenced`, verifiers that do not use OpenID Federation continue to fetch and use the same JWK Set at the same URL. The Entity keeps one JWK Set, whether or not a given verifier checks the binding.

## Superior-Supplied Metadata

Verifiers use the Resolved Metadata ([@!OpenID.Federation], Section 6). A Superior MAY supply or override the parameters defined here with `metadata` in its Subordinate Statement. It MAY also constrain them with `metadata_policy`, for example with `one_of` on `digest_alg`. A Superior that supplies digests becomes responsible for sequencing updates to them (#updates). This specification RECOMMENDS that Superiors leave digests to the Entity and constrain only `digest_alg`.

# Trust Marks in Well-Known Documents {#trust-marks-in-documents}

This section is OPTIONAL to implement. The binding in (#well-known-documents) does not depend on it.

An Entity's Trust Marks are carried in the `trust_marks` claim of its Entity Configuration ([@!OpenID.Federation], Section 3.1.2), and validated per [@!OpenID.Federation], Section 7.3. This specification does not carry Trust Mark JWTs anywhere else, and does not alter them. A Trust Mark says nothing about covered documents or keys, and is unaffected when they change.

A statement-capable document MAY contain the two members defined below. The document states them for the role it describes. They are authenticated by the document's digest. When one origin serves several roles, each role's document makes its own statements.

Specifications defining well-known documents generally require unrecognized members to be ignored ([@!RFC8414], Section 2; [@!RFC9728], Section 2), so adding these members does not affect existing consumers.

## trust_mark_types {#trust-mark-types}

- `trust_mark_types` (OPTIONAL): JSON array of strings. Each element is the `trust_mark_type` of a Trust Mark in the Entity's Entity Configuration that the Entity presents as relevant to the role this document describes.

An Entity Configuration can hold Trust Marks for many purposes, and `trust_mark_types` selects those that apply to this role. A verifier evaluating the Entity in that role considers only the listed types. A listed type with no valid Trust Mark in the Entity Configuration is treated as not held.

## trust_mark_types_required {#trust-mark-types-required}

- `trust_mark_types_required` (OPTIONAL): JSON object. Each member name is the well-known suffix of the document that describes a counterparty role. Each member value is a non-empty JSON array of `trust_mark_type` strings that an Entity in that role MUST hold for this Entity to deal with it in this role.

A counterparty meets a requirement when both of the following hold:

1. It holds a valid Trust Mark ([@!OpenID.Federation], Section 7.3) of each required type.
2. It lists each required type in `trust_mark_types` of its covered document with that well-known suffix.

Example: an OAuth protected resource that deals only with authorization servers holding a payment-institution Trust Mark:

```json
{
  "resource": "https://api.bank.example",
  "authorization_servers": ["https://as.bank.example"],
  "jwks_uri": "https://api.bank.example/jwks",
  "trust_mark_types": [
    "https://openfinance.example/marks/account-servicing"
  ],
  "trust_mark_types_required": {
    "oauth-authorization-server": [
      "https://openfinance.example/marks/payment-institution"
    ]
  }
}
```

`trust_mark_types_required` is a declaration for discovery. It lets a client learn before a call that the server will refuse it. It also lets an operator learn what it needs to obtain to be reachable. The Entity enforces its requirements from its own policy, whether or not it publishes them (#published-requirements).

# Verification {#verification}

A verifier whose policy requires federation verification for a peer performs the following steps when it discovers the peer's well-known document. These are in addition to the checks defined by the peer's protocol.

1. Fetch the peer's Entity Configuration. Resolve and validate a Trust Chain from it to one of the verifier's configured Trust Anchors ([@!OpenID.Federation], Section 10), obtaining the Resolved Metadata. The Entity Identifier MUST equal the identifier the protocol uses for the peer.
2. Take the member of `well_known_documents` in the Resolved Metadata for `federation_entity` whose name is the well-known suffix being discovered. If it is absent, verification fails.
3. Determine the document's location (#document-location) and fetch it. Compute its digest with `digest_alg`, and compare it to `digests`. If no element matches, verification fails.
4. For each member of `referenced`, take the URL from that member of the covered document and fetch the document. Compute its digest and compare it to the listed digests. If the covered document lacks the member, or no element matches, verification fails.
5. If the verifier's policy requires Trust Marks of the peer, check each required type. The type MUST appear in the covered document's `trust_mark_types`. The Entity Configuration MUST contain a Trust Mark of that type that validates per [@!OpenID.Federation], Section 7.3, with `sub` equal to the Entity Identifier.

The verifier uses the covered document and any referenced document only after these steps succeed. This includes keys from a referenced JWK Set.

## Caching {#caching}

A verifier MAY cache the outcome of verification until the expiration time of the Trust Chain ([@!OpenID.Federation], Section 10.4), which is no later than the Entity Configuration's `exp`. It MUST NOT use a cached Entity Configuration after its `exp`. A verifier may re-fetch a covered or referenced document within that period, for example on an unknown `kid`. When it does, it checks the new content against the digests in its cached Resolved Metadata.

# Updates and Key Rotation {#updates}

Replacing a covered or referenced document changes its digest. The Entity overlaps the old and new digests. That way no verifier holding a valid cached Entity Configuration sees a document it cannot match.

1. Issue an Entity Configuration whose digest array contains both the current digest and the digest of the replacement document.
2. Wait until every Entity Configuration that lists only the current digest has passed its `exp`.
3. Replace the document.
4. Issue Entity Configurations whose digest array contains only the new digest.

Step 4 can happen with the Entity Configuration's next routine re-issue. The Entity's chosen Entity Configuration lifetime bounds the wait in step 2. Entities that update their documents often SHOULD use a short `exp`.

## Protocol Key Rotation

An Entity SHOULD keep two or three keys in a referenced JWK Set, and rotate by replacing the oldest key with a new one. Each rotation is one JWK Set replacement, performed by the procedure above. The Entity MUST NOT sign with the new key before step 3 has completed.

## Federation Key Rotation

Rotation of the Entity's Federation Entity Keys follows [@!OpenID.Federation], Section 11. It does not affect covered documents, referenced documents, digests or Trust Marks.

# Trust Mark Requirement Errors {#errors}

This specification defines an error that a protocol MAY adopt. An Entity returns it when it refuses to deal with a counterparty because the counterparty does not meet its Trust Mark requirements. A protocol that uses JSON error responses with an `error` member conveys it with these members:

- `error`: `trust_mark_required`
- `entity` (REQUIRED): The Entity Identifier of the counterparty that does not meet the requirement.
- `trust_mark_types` (REQUIRED): JSON array of the required `trust_mark_type` values that the counterparty did not meet.

The adopting protocol defines the HTTP status code and where the error is returned. When the error concerns an intermediary rather than the requesting party, a party that receives it relays it unchanged.

A peer that fails federation verification (#verification) has not been refused on Trust Marks. The protocol reports it as a metadata or key discovery failure.

# Security Considerations {#security-considerations}

## What the Trust Anchor Attests

The Trust Anchor, through the Subordinate Statement, attests only that the Entity's Federation Entity Keys belong to its Entity Identifier. The Entity itself attests the digests, and therefore the covered documents, the referenced documents, and the Trust Mark statements in them. A verifier trusts the Entity's statements about its own documents exactly as far as it trusts the Entity's federation key. Only Trust Marks convey accreditation of the Entity by third parties.

## DNS and Transport

Once the Trust Chain is validated and the digests match, DNS and TLS serve only as transport. An attacker who can answer for the origin can withhold documents but cannot substitute them.

## Federation Key Compromise

An attacker who compromises an Entity's Federation Entity Key can issue an Entity Configuration with digests of attacker-chosen documents. The attacker can thereby substitute the Entity's protocol keys for as long as the key remains in the Superior's Subordinate Statement. Entities SHOULD give Federation Entity Keys at least the protection of their protocol keys, and SHOULD NOT hold them in the same place. Recovery is removal of the key from the Subordinate Statement by the Superior.

## Trust Anchor Key Rollover

A verifier's configured Trust Anchor key is its root of trust. [@!OpenID.Federation], Section 11 has the Trust Anchor publish its next key in its Entity Configuration before signing with it. A verifier that does not refresh the Trust Anchor's Entity Configuration within that overlap can no longer validate chains, and must be re-configured out of band. OpenID Federation defines no hold-down period comparable to [@?RFC5011]. A compromised current Trust Anchor key can therefore introduce a replacement key that verifiers accept immediately.

## Published Requirements Are Not Enforcement {#published-requirements}

`trust_mark_types_required` informs counterparties; it does not bind the publisher. Whether a verifier requires federation verification or Trust Marks of a peer comes from the verifier's own configuration, never from the peer's documents. Consider a verifier whose policy requires federation verification of a peer. It MUST NOT fall back to Web PKI trust because the peer's covered document omits `trust_mark_types`, or because the peer's origin serves no Entity Configuration.

## Unauthenticated Content Before Verification

A covered document is unauthenticated until its digest has been checked against a validated Entity Configuration. A verifier whose policy requires federation verification for a peer MUST NOT act on any member of the covered document before step 3 of (#verification). This includes URL-valued members, `trust_mark_types`, and `trust_mark_types_required`. The same applies to a referenced document before step 4.

## Unreferenced URLs {#unreferenced-urls}

`referenced` authenticates only the documents it lists. A URL-valued member of a covered document that is not listed in `referenced` locates an unauthenticated document. The URL itself is authenticated, but the document at that URL is not. A verifier that relies on such a document SHOULD require the Entity to list it in `referenced`.

## Trust Mark Selection

`trust_mark_types` narrows which Trust Marks count for a role; it cannot add one. A verifier MUST validate each Trust Mark it relies on per [@!OpenID.Federation], Section 7.3, including issuer authorization under the Trust Anchor's `trust_mark_issuers`. Where the Trust Mark Issuer offers a Trust Mark Status endpoint ([@!OpenID.Federation], Section 8.4), the verifier MAY query it.

## Byte-Exact Digests

Digests pin exact octets. Any transformation between the Entity and the verifier produces a mismatch and a verification failure, so the check fails closed.

## Resolution Cost

Trust Chain resolution adds fetches to metadata discovery. An attacker who can cause a verifier to discover many peers can use this to amplify load on the verifier and on Superiors' fetch endpoints. Verifiers SHOULD cache per (#caching), and SHOULD bound the rate of chain resolution per peer.

# Privacy Considerations {#privacy-considerations}

Resolving a peer's Trust Chain reveals to the peer's Superiors, through requests to their fetch endpoints, that the verifier is evaluating that peer. Verifiers that consider this sensitive have two options: use a resolver they operate ([@!OpenID.Federation], Section 10.6), or cache Subordinate Statements for their full lifetime.

A Trust Mark is public for as long as it is in an Entity Configuration. In `trust_mark_types`, an Entity SHOULD list only the types relevant to the role. It MAY omit from its Entity Configuration any Trust Marks it does not want to disclose.

# IANA Considerations {#iana-considerations}

## OAuth Authorization Server Metadata

This specification requests registration of the following in the "OAuth Authorization Server Metadata" registry established by [@!RFC8414]:

- Metadata Name: `trust_mark_types`
    - Metadata Description: Trust Mark types the Entity presents as relevant to this role
    - Change Controller: OpenID Foundation Connect Working Group
    - Specification Document(s): (#trust-mark-types) of this specification
- Metadata Name: `trust_mark_types_required`
    - Metadata Description: Trust Mark types the Entity requires of counterparties, by counterparty well-known suffix
    - Change Controller: OpenID Foundation Connect Working Group
    - Specification Document(s): (#trust-mark-types-required) of this specification

## OAuth Protected Resource Metadata

This specification requests registration of `trust_mark_types` and `trust_mark_types_required`, with the descriptions above, in the "OAuth Protected Resource Metadata" registry established by [@!RFC9728].

## OAuth Extensions Error

This specification requests registration of the following in the "OAuth Extensions Error Registry" established by [@!RFC6749]:

- Name: `trust_mark_required`
- Usage Location: resource access error response, token error response
- Protocol Extension: OpenID Federation Well-Known Binding
- Change Controller: OpenID Foundation Connect Working Group
- Specification Document(s): (#errors) of this specification

`digest_alg` values are taken from the "Hash Algorithms for HTTP Digest Fields" registry established by [@!RFC9530].

# Open Issues

*Note: This section is to be removed before publication.*

- Registration of `digest_alg` and `well_known_documents` as `federation_entity` metadata parameters, if the OpenID Federation registry structure provides for it.
- Whether verifiers should re-fetch the Entity Configuration once on a digest mismatch, as a fallback for Entities that do not sequence updates per (#updates).
- Whether `referenced` should support members nested below the top level of a covered document.
- Whether `uri` should be restricted to the Entity Identifier's origin.
- Whether to also define a digest companion for a `jwks_uri` that appears directly in Entity Type metadata, as a plain-JSON alternative to `signed_jwks_uri` outside well-known documents.

# Document History

*Note: This section is to be removed before publication.*

- -00
    - Initial draft, generalized from draft-hardt-aauth-trust-marks.

# Acknowledgments

TBD

{backmatter}

# Examples {#examples}

## AAuth Person Server

AAuth server identifiers have no path, so no `uri` is needed. Entity Configuration payload, served at `https://ps.example/.well-known/openid-federation`:

```json
{
  "iss": "https://ps.example",
  "sub": "https://ps.example",
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
    "federation_entity": {
      "well_known_documents": {
        "aauth-person.json": {
          "digests": [
            "2hBq7vQeY0mX1kZ5p8m4a0yP3Q2c0m3m0n7Lr1ZkQ9o"
          ],
          "referenced": {
            "jwks_uri": [
              "Kq3rU8mZ4nT1bV9xW2yA5cD7eF0gH6iJ8kL1mN3oP5q",
              "7fYw0pQx3mN8bR2cV5kL1aZ9sD4hJ6gT0uE3iO8yW2q"
            ]
          }
        }
      }
    }
  },
  "trust_marks": [
    {
      "trust_mark_type":
        "https://openfinance.example/marks/payment-institution",
      "trust_mark": "eyJ0eXAiOiJ0cnVzdC1tYXJrK2p3dCIs..."
    }
  ]
}
```

The `jwks_uri` array holds two values because a protocol key rotation is in progress (#updates). Digest values are illustrative.

The covered document at `https://ps.example/.well-known/aauth-person.json`:

```json
{
  "issuer": "https://ps.example",
  "token_endpoint": "https://ps.example/token",
  "jwks_uri": "https://ps.example/keys/jwks",
  "trust_mark_types": [
    "https://openfinance.example/marks/payment-institution"
  ],
  "trust_mark_types_required": {
    "aauth-resource.json": [
      "https://soc2.example/marks/soc2-type2"
    ]
  }
}
```

## Collocated Roles

An origin acting as both OAuth authorization server and protected resource covers one document per role. Each document makes its own Trust Mark statements.

```json
"federation_entity": {
  "well_known_documents": {
    "oauth-authorization-server": {
      "digests": ["mJ3pX8kQ2vN7cR1tY5wB9zL4hD6fG0sA2eU8iO3nK7q"],
      "referenced": {
        "jwks_uri": ["Lw4sT9mB1xZ6kP3vQ8nR2cY7hF5jD0gA4eU1iO9tK6s"]
      }
    },
    "oauth-protected-resource": {
      "digests": ["Qe7rN2vB5kX9mT1cY4wL8zH3pD6fG0sA2jU8iO5nR1t"],
      "referenced": {
        "jwks_uri": ["Lw4sT9mB1xZ6kP3vQ8nR2cY7hF5jD0gA4eU1iO9tK6s"]
      }
    }
  }
}
```

## Path-Based Entity Identifier

For Entity Identifier `https://idp.example/tenant-a`, whose authorization server metadata is located per [@!RFC8414], Section 3.1:

```json
"well_known_documents": {
  "oauth-authorization-server": {
    "uri": "https://idp.example/.well-known/oauth-authorization-server/tenant-a",
    "digests": ["Zr8kP2mQ5vX1nT7cY3wL9bH4dF6gA0sJ2eU8iO5nR3t"]
  }
}
```

# Design Rationale

## Why `federation_entity` Metadata

Every Entity publishes `federation_entity` metadata. Placing `well_known_documents` there lets a verifier find the entry for a document by its well-known suffix alone, whatever protocol the document belongs to. No mapping from protocols to Entity Types is needed, and no per-protocol profile.

## Why Keyed by Well-Known Suffix

The well-known suffix is the one identifier every covered document already has. It is registered in the IANA "Well-Known URIs" registry [@!RFC8615], and the verifier holds it from the discovery step it is already performing.

## Why the Document States Its Trust Marks

The role a Trust Mark accredits is described by the protocol's own document. Putting `trust_mark_types` and `trust_mark_types_required` in that document keeps the statement with the role. When one origin serves several roles, each role therefore states its own selection and requirements. The document's digest authenticates these statements. Carrying them in the Entity Configuration instead would separate them from the role they describe.

## Why JSON Objects and JWTs Only

The statement members need a document that can carry named members. Other formats can still be covered by digest, but cannot make Trust Mark statements.

## Why the Entity Signs the Digests

The alternative is to carry digests in a Trust Mark issued by the Trust Anchor or an accreditation body. That would make every key rotation and metadata change a request to a third party. Accreditation changes rarely; keys and metadata change routinely. Putting the digests in the Entity's own Entity Configuration keeps routine changes self-service, while the Trust Anchor still controls which federation keys speak for the Entity. Trust Marks carry accreditation only.

## Why Not Sign the Documents

OpenID Federation offers `signed_jwks_uri` ([@!OpenID.Federation], Section 5.2.1), [@!RFC8414] and [@!RFC9728] offer `signed_metadata`, and any document could carry a detached JWS ([@!RFC7515], Appendix F). Each of these has two costs. Servers must produce and serve signed variants of documents they serve today as plain JSON. Verifiers must handle two formats, each rooted in a different key. With digests, an Entity joins a federation by publishing an Entity Configuration, and nothing it already serves changes except the optional Trust Mark members.

## Why the Binding Stands Apart from Trust Marks

Binding keys to an Entity Identifier and accrediting the Entity are separate questions, answered by different parties on different schedules. The Trust Chain answers the first; Trust Marks answer the second. A deployment that wants federation-rooted protocol keys and has no accreditation scheme uses (#well-known-documents) alone. The Trust Mark members are defined here because their authentication depends on the binding, not because the binding depends on them.

## Why `uri` Only for Path-Based Identifiers

For an Entity Identifier with no path, the location follows from the identifier and the suffix. A `uri` member would then be a second source for the same value, and the two could disagree. Protocols differ in how they place well-known paths for path-based identifiers. Stating the location explicitly in those cases avoids encoding each protocol's rule.

## Why Arrays of Digests

A digest pins one version of a document, and verifiers cache Entity Configurations for their lifetime. Listing old and new digests together lets the Entity pre-publish the new digest, as OpenID Federation pre-publishes a Trust Anchor's next key. The alternative is to require verifiers to re-fetch on mismatch. That shifts the cost to every verifier and creates a forced-fetch vector, so it is recorded as an open issue.

## Why `digest_alg` and base64url

The SD-JWT VC `#integrity` convention uses W3C Subresource Integrity expressions. These are standard base64 with padding, and repeat the algorithm in every value. A single `digest_alg` with base64url values matches other digests in JOSE documents (`x5t#S256`, `jkt`), and takes algorithm names from the [@!RFC9530] registry. The cost is that an algorithm change is a single cutover rather than an overlap.

## Why Requirements Are Keyed by Well-Known Suffix

A server often deals with counterparties in several roles, and may require different accreditation of each. The counterparty's well-known suffix names its role in a way that needs no additional identifier. It is also the document in which the counterparty lists its own `trust_mark_types`.

## Why Trust Mark Issuance Is Out of Scope

Who accredits whom is a property of each federation and accreditation scheme. OpenID Federation already expresses which issuers are recognized for which types (`trust_mark_issuers`, `trust_mark_owners`). This specification consumes Trust Marks and defines nothing about producing them.

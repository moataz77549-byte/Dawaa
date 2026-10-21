# Security boundaries

Public educational reads need no login. There are no administrative HTTP writes;
all non-read methods return 403 even if a caller sends owner/role headers. The admin
folder explains this deliberate closed state. A future admin implementation must
verify Neon Auth JWT signatures/issuer/audience and server-assigned permissions;
never grant ownership to the first email or trust a client-provided role.

The Function executes fixed parameterized queries using a bounded pg pool and
read-only transactions with `dawa_reader`. Reader has only publication-view grants.
The injected connection remains an owner credential; SET LOCAL ROLE and read-only
transactions reduce query privileges, but separate login credentials will provide
stronger containment when administrative backend work is introduced.

Private bucket credentials remain on Neon. Mobile only sees short-lived object
URLs through a published asset lookup. API exceptions are generic, signatures
are not cached/logged, size/path/hash are checked before local publication.
Android disallows cleartext except localhost for the bundled viewer. No patient
data or device personal identifiers are collected; no app login is required.

CI includes secret/client-boundary scan and npm vulnerability audit. It is not a
comprehensive pen test; Dart advisories and device WebView behavior remain open.

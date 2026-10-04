# Whole-line textual evidence ranges — research only

This independent Swift prototype runs the same immutable 73 fictional scenes as
.NET and the Python reference. The JSON SHA256 is
`66ce1efcf4a415d70ec71e1eb5707ca665c91eba0f33d99a86d08dc54f59c43f`.
All aliases, coordinates and contents are synthetic or public task vocabulary.
No school original, image, PDF, OCR call or model is read by this program.

Each original whole OCR parent must fit exactly one measured cell and exactly one
unlabelled measured row band. An exact public alias immediately followed by `:` or
`：` identifies one role; the remaining nonempty text is the BODY. The two half-open
UTF-8 ranges completely cover the original parent. Neither range receives a new
box: ID, page, native SourceOrder, text and whole box are retained. Original parents
array order is authoritative; nullable, repeated and nonmonotonic SourceOrder is
only provenance. No sorting, normalization, body trimming or substring correction
occurs. Opaque IDs and values are compared as original UTF-8 bytes, so NFC/NFD
canonical equivalence cannot hide an altered ID or BODY.

The supported family requires exactly one subject, teacher and room parent in each
supplied cell. Unknown/nested aliases, overlapping cells/bands/parents, boundary
crossing, an interior physical rule, control/multiline text (including Unicode line/paragraph separators), parallel markers `・･/／;；|｜`,
missing roles and empty/whitespace bodies refuse. A rule merely touching a parent
boundary does not cross it. All supplied parents must be accounted for. Character
boundaries prevent cutting inside an extended grapheme; a BODY beginning with a
combining mark, variation selector or ZWJ is additionally unsupported.

Verification recomputes the entire partition and requires the proposed proofs to
retain the original raw bytes, hash, whole box, spans and array order. One shared
100000-operation budget covers construction and proof comparison; cancellation
is checked during scans and comparison. The input caps are 128 parents/cells/bands/
rules, 4096 UTF-8 bytes per parent and 262144 total bytes. IDs use the shared 1–128
UTF-16 code-unit limit. JSONDecoder rejects null/missing required records and invalid
Unicode transport; Swift strings cannot represent unpaired UTF-16 surrogates.

Run on a host with Swift and Foundation:

```sh
SWIFTC=/path/to/swiftc bash tools/evidence-span-prototype/run.sh > /tmp/span-results.json
```

The runner creates and removes only its own temporary executable directory.
macOS uses CryptoKit SHA256; the Linux research CLI feeds exact bytes directly to
`/usr/bin/sha256sum` without a shell or temporary input file. This host-only fallback
is not an iOS runtime dependency. Compiler/OS identity is recorded because Character
segmentation can depend on runtime Unicode versions. Work accounting is local to
this implementation; compare accepted decisions and exact spans, not operation
counts or wall time across languages.

The shared 73 cases test literal UTF-8 ranges, all aliases/colon spellings, raw BODY
retention, ownership and unsupported syntax. Twenty-one additional Swift tests cover
proof order/offset/hash/box/value tampering, NFC/NFD IDs and BODY, cancellation,
shared budget exhaustion, caps and null/invalid-surrogate transport. Expected values
are consulted only after `build(scene)` returns; they are never construction input.

These are textual ranges and whole-parent ownership proofs. They do not prove OCR
correctness, complete acquisition, blank pixels, class/day/period/year/term binding,
Schema2 spatial label/BODY certificates, full timetable correctness or useful AI.
Production Schema2, Verify, Validator5, providers, UI and historical audits are
unchanged. Adopting substring evidence would require a separately reviewed contract
and version/migration design; prototype success contributes zero to model, OCR or
physical-device qualification.

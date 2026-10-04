# Swift whole-line evidence-span research

Swift 6.1.2 on Linux passed 94/94 host tests: the same 73 immutable fictional scenes
used by Python and .NET, plus 21 local safety cases. The common scene file SHA256 is
`66ce1efcf4a415d70ec71e1eb5707ca665c91eba0f33d99a86d08dc54f59c43f`.
The Python comparison matched all 73 decisions, exact BODY bytes, UTF-8 ranges,
parent hashes and supplied parent-array order. Local tests additionally reject
tampered/reordered proof arrays, NFC/NFD BODY substitution, budget refill,
cancellation, null/invalid Unicode transport and Unicode line/paragraph separators.

A complete public role prefix plus colon can be represented as a label range and
an unchanged BODY suffix within one original whole-parent box. Explicit measured
cell/band containment and all-parent accounting are required. Missing/empty roles,
parallel syntax, ambiguous geometry and physical rule crossings refuse; absent
text is never verified EMPTY. Native SourceOrder is retained as nullable metadata,
while the original parent array controls order. No new character boxes are invented.

The separator regression initially produced 93 passing tests and one failure:
U+2028/U+2029 are not Unicode Control characters. An explicit line/paragraph
separator guard now rejects both BODY text and opaque IDs. The common fixtures
and their expected values did not change. The historical failure remains recorded
by its exact SHA256 in [checks.json](checks.json).

[results.json](results.json) contains the actual final host outcomes; the source and
reproducible runner are in [tools/evidence-span-prototype](../../tools/evidence-span-prototype).
This is an isolated research proof, with no native OCR/model calls and no production
changes. It proves neither OCR correctness nor complete image coverage, spatial
Schema2 label/BODY certificates, whole-40-slot recovery, useful AI, model quality or
physical-device performance. Adopting substring evidence requires a separate input
contract, version/migration design and full formal integration gate.

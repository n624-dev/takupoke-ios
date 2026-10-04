# Local role diagnostics

These isolated research scripts assess consumed fictional development inputs through an existing local llama.cpp b11371 CPU server. They do not change production providers, prompt version 4, schema 2, Validator 5, model catalogs, or application releases.

The original corpus is the previously published GGUF batch corpus (SHA-256 `7a0c210890d713cc1f597f30f76a538027d47d9ae2fc960de90cc85aaaabffd3`). The scripts use its first case. `request` records contain only original source IDs/text, public role aliases, instructions, and output grammar. Expected IDs are used after native return. The local research paths in these scripts are explicit environment dependencies; they are not application runtime paths.

The HEAD contract returns `{"ids":[]}`. Every source ID remains eligible in the grammar. The decoder rejects duplicate JSON keys, object-shaped arrays, unknown or duplicate IDs, reordered IDs, extra keys, and Markdown. It never sorts, repairs, or fills the model's output. A native returned but malformed response is an assessed format failure, distinct from an invocation failure or missing response.

Compact v1 and v2 are distinct, frozen research recipes. V2 adds a complete-alias equality requirement and an independent split-label example. Both preserve the original source order and all public target-role aliases. The whole-alias/null diagnostic is a different task, not a HEAD success. The schema-only native assistant-prefill diagnostic records the actual native response without concatenating a prefix after return.

Current consumed-dev results: Qwen2.5-1.5B compact v1 and v2 each select 2/3 roles correctly; its split teacher fails in constrained HEAD, free HEAD, alias/null, and prefill diagnostics. Qwen3.5-2B compact v1 and v2 each select 1/3. Compact v1 Qwen3-0.6B and Qwen3-1.7B select 0/3. These tiny consumed controls do not establish general model accuracy or a single underlying cause.

This finite label family is also deterministically solvable. Useful-AI qualification has no denominator here. Any future host evidence reconstruction must enumerate all allowed aliases and independently certified partitions, including alternatives the model did not choose; distinct body ownership must remain a terminal ambiguity. No certificate, whole-document recovery, phone-memory qualification, or model activation is claimed from these diagnostics.

Run the model-free boundary checks with:

```sh
python -B -m unittest discover -s tools/model-role-diagnostics -p 'test_*.py' -v
```

Actual inference requires an intentionally started, owned local server and the pinned existing weights. Do not import or run the native probe scripts as part of a routine test suite. Existing measured baselines remain historical; no repeated baseline native jobs are added.

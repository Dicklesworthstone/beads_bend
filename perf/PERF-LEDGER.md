# Performance Ledger — <PROJECT>

<!-- Copy to perf/PERF-LEDGER.md when the project reaches rigor tier T2
     (references/NEGATIVE-EVIDENCE-AND-LEDGERS.md). Only WIN rows live here.
     A qualified local result awaiting target validation is provisional;
     a refused capture is NO_EVIDENCE. Neither is admitted here. -->

Row admission (all mandatory):

1. Name the comparison: for scaling, runtime arms of the same binary;
   for a source optimization, two identified artifacts at the same runtime
   settings. `bench-speedup` measures the former; the latter needs a
   harness interleaving both retained artifacts. A C twin, if cited, is
   labelled as the sequential reference.
2. Interleaved in both orders with an A/A pair; medians; **cv ≤ 5% or the
   row is refused** (`scripts/bench-speedup.sh --aa --max-cv 5 --strict`).
3. Identical stdout bytes across every sample/arm (`same_output: true`),
   with controlled inputs and a separately stated numerical contract.
4. `bend PROOF.bend` → "All terms check." with relevant law coverage,
   unsafe declarations and trusted dependencies reviewed; the keep-audit
   delta attached. An unchanged unsafe count alone is insufficient.
5. Route attested: a device row used `--gpu on` or a positive span, names the device and
   includes dispatch evidence; a CPU row ran with `--gpu off`.
6. Fingerprint: `bend --version`, commit, clang, `uname -sm`, CPU model,
   core count, GPU, thread count, span, lanes per bang.
7. Evidence dir with the JSON line, the emitted C, keep-audit before and
   after, and the fingerprint.
8. A meaningful improvement that meets the stated success criterion;
   low dispersion and matching output alone do not make a gain. Review
   paired samples, drift and uncertainty before assigning WIN.

CV/A/A thresholds screen captures; they do not prove statistical
significance. Review the retained paired samples and proof assumptions
(including 2.0.16 template warnings). `ledger-row.sh` formats a provisional
row and cannot verify these admission requirements or promote it to WIN.

---

## Rows

| date | program | lever | baseline arm | baseline ms | ours ms | ratio | cv% | cksum | laws | keep Δ | fingerprint | evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| <d> | <x.bend> | <one line> | t=1 gpu=off | <ms> | <ms> | <×> | <v> | <cksum> | <complete verdict and reviewed assumptions> | <def>: keep a→b | <hw · bend · clang · threads · span> | `perf/<lever>/` |

## Frozen pins

Hold one row per hardware as the pin (the repo's own gate accepts 1.15× of
its pin on identical hardware). Move a pin only by an explicit, reviewed
ratchet; never because a run beat it once.

| hardware | program | arm | ms | cksum | date | bend |
|---|---|---|---|---|---|---|

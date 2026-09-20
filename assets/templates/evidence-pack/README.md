# Evidence pack — <EXP-id>

<!-- Phase 5 fills this directory: `scripts/evidence-bundle.sh <EXP-id>` writes
     every file below and MANIFEST.txt; the PERF-LEDGER row's `evidence` cell
     and the card's Result section point here (SHIP-AND-CERTIFY "The evidence
     bundle"). Append-only: a re-run after any change is a NEW directory. -->

Made <date> at commit `<sha>` under `<bend version>`, threads `<threads>`,
hot args `<hot args>`, kill-switch `<X_SPEC>`.

| file | what it is | produced by |
|---|---|---|
| `pin-check.txt` | compiler/original pin and capture integrity gate; GREEN required | evidence-bundle (run) |
| `PROOF.txt` | the verdict line of `bend port/PROOF.bend` and `bend --version` (the unsafe count is in the line) | evidence-bundle (run) |
| `lanes.json`, `lanes.txt` | `scripts/lanes.sh` last line and full output on every lane | evidence-bundle (run) |
| `x.c` | the emitted C of `port/main.bend` (`#define BANGS n` is the device evidence) | evidence-bundle (run) |
| `keep-audit.txt` | per-def `peek/keep/take` counts (bend2-mega-skill) or the coarse counts over `x.c` | evidence-bundle (run) |
| `card.md` | the `<EXP-id>` block of `perf/EXPERIMENTS.md` at bundle time | copied |
| `ledger-lines.txt` | every PERF-LEDGER / NEGATIVE-EVIDENCE / PORT_STATE line naming `<EXP-id>` | grep |
| `bench-speedup.json` | the cv-gated capture of the arms (`--aa --max-cv 5`) | copied from `--bench`; never re-run here |
| `incumbent-bench.json` | the interleaved capture against the pinned original (`--pin`) | copied from `--incumbent`; never re-run here |
| `source.tar`, `source.patch` | actual working-tree bytes from `port/`, `scripts/`, `docs/`, `goldens/` (symlinks dereferenced), plus tracked changes against HEAD | captured, including uncommitted work |
| `source-hashes.json`, `source-hashes.after.json` | full file sets, content hashes and file-symlink targets before and after gates; replay rejects additions, removals or changed bytes | captured |
| `rerun.sh` | reproduces the gate lines from a checkout at `<sha>` | template, substituted |
| `rollback.md` | the runtime and source rollback of the lever | template, substituted |
| `MANIFEST.txt` | sha256 of every file above | evidence-bundle |

A number in a claim that is not in one of these files is not claimed.
Supplied benchmark JSON is checked for a successful verdict only. Its own
command, toolchain, host and source provenance must establish that it measures
this lever; copying a MEASURED capture does not bind it to this source snapshot.

The source archive is limited to those four directories. Directory symlinks
and special files are refused rather than silently omitted; stage their ordinary
files within the captured directories before bundling. External imports,
the original program, compiler/runtime binaries and environment dependencies
need their own immutable pins or companion artifacts. Recover captured files
into an isolated checkout before rerunning; never extract over unrelated work.
Replay checks the bundle's artifact hashes, recorded source hashes and
compiler/original pins before running bounded gates; proof/version/lane results
must equal the capture. `rerun.sh [seconds-per-gate]` defaults to 600 seconds.
A bundle's GREEN verdict covers only its gates; it does not
override a PARTIAL feature board or authorize a speed claim.
The archive materializes file symlinks. Replay accepts those regular files
when their bytes match the recorded targets; new or retargeted symlinks are
rejected.

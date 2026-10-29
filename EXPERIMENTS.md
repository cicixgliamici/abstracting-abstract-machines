# Representative, reproducible experiments

Run from the repository root on Linux/WSL with OCaml, Dune, and Python 3:

```sh
opam exec -- python3 scripts/run_experiments.py --milestones
```

On Windows with the existing Ubuntu toolchain:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /mnt/c/Progetti/abstracting-abstract-machines && opam exec -- python3 scripts/run_experiments.py --milestones'
```

The command builds the executable and regenerates `results/representative/`:
`programs.csv` (exact source syntax and families), `raw.csv` (every trial),
`precision.csv`, `states.csv`, `store.csv`, `timing.csv`, `completion.csv`, `tables.md`, and
`metadata.json`. Metadata records configuration, tool versions, platform, UTC
timestamp, Git revision/status when available, and SHA-256 hashes of all
measurement sources and generated outputs. `--milestones` also regenerates the
four separate milestone CSVs, the generated `results/guided-example.md` trace,
and their own `results/milestone-metadata.json`.
It retains their existing complete-analysis protocols, not the capped protocol.
Source hashes identify dirty or untracked implementations as well as committed
ones. Outputs are overwritten; save a separate copy to compare runs. Run
`python3 scripts/run_experiments.py --verify` to check source/result provenance,
then `python3 scripts/artifact.py` to package the review payload; see `ARTIFACT.md`.

## Corpus and configurations

Twelve closed AST programs cover identity pipelines of lengths two/four/eight, Church
iteration of lengths two/four/eight, repeated calls with different arguments, three
writes observed through a shared reader closure, mutation returning an old
closure from another environment, a continuation escape bypassing a divergent
branch, a saved continuation invoked twice with mutable flags, and omega.
Builders are in `lib/experiment_examples.ml`; `programs.csv`
prints the complete terms. These are small semantic workloads, not real-world
applications or a statistically representative population.

Each program runs under site allocation and pools of 1, 4, 16, and 64 addresses,
with GC off/on, with three fresh-process trials: 120 configurations and
360 trials. Defaults cap each graph at 5,000 reached states and each exploration
at two CPU seconds. A 15-second subprocess watchdog covers expensive individual
steps as well as setup. Limits can be changed explicitly:

```sh
opam exec -- python3 scripts/run_experiments.py --repetitions 5 --max-states 20000 --cpu-limit 10 --wall-limit 30 --allocators sites pool1 pool4 pool16 pool64
```

All pools retain the implemented allocation schedule: fill N addresses, then
reuse slot one forever. Increasing N postpones saturation; it is not a round-robin
or context-sensitive policy. Site allocation also separates binding/frame roles,
whereas pools can mix them. Differences therefore cannot be attributed solely
to address count. The size series adds controlled workloads but does not by
itself establish asymptotic scaling or monotonic precision as N increases.

The complete library `Store_machine.analyze` is unchanged. The separate
experimental explorer reports `complete`, `state_limit`, or `cpu_limit`.
`wall_timeout` means the process was killed and graph measurements are unavailable.
CPU checks occur between worklist expansions, so the CPU limit can be exceeded
by one expansion. `complete` means the queue was exhausted without omitting any
successor. Reaching the state cap alone does not prevent completion if there is
no additional unseen state. Interrupted counts describe only a reached prefix;
they must not be compared to complete graphs as though both were fixed points.

## Measurements and completion

`completion.csv` groups by allocator and GC mode. It records total configurations,
configurations for which every repetition completed, their fraction, and trial
counts for each completion/cutoff status. This distinguishes practical completion
under a shared budget from metrics available only for complete fixed points.

* **Precision:** number of additional final value syntaxes beyond the concrete
  result, and whether the concrete syntax is included. This assessment is
  available only for a complete analysis and a concretely finished program.
  Syntax omits labels, closure environments, and continuation identities; zero
  extra syntax does **not** establish exact value or behavioral precision.
  Pure terminating results are additionally checked against capture-avoiding
  substitution using reified full concrete values. Extended results use the
  concrete store machine, not an independent extended-language oracle.
* **States:** reached-state and final-state cardinalities. They measure graph
  size, not precision or execution time. Each state contains its own store;
  there is no global store widening.
* **Store:** maximum addresses and total storable alternatives in any reached
  state's store. With GC these are post-collection peaks. They exclude temporary
  pre-collection stores, host heap usage, and the memory of the entire graph.
* **Timing:** median exploration CPU and wall seconds, including initial-state
  construction and worklist operations. Concrete/reference checks, process
  startup, compilation, major GC before exploration, and result summarization
  are excluded. Wall time uses `Unix.gettimeofday`, which can be affected by
  system clock adjustments. Trials have no warm-up and use fresh processes.
  Millisecond/microsecond runs are too short for robust performance claims.

Raw rows retain every sample. Summary counts are retained only when identical
across trials; otherwise they say `varies`. Precision fields are blank whenever
any trial is incomplete. Timing for interrupted searches measures work until
the cutoff, not time to complete an analysis. No timing summary is supplied
when a watchdog timeout leaves a sample unavailable. Fuel exhaustion in the
2,000-step concrete check is a bounded observation, not proof of divergence.

## Observations from the checked-in run

The checked-in `completion.csv` is the authoritative per-policy completion
summary. Larger pools provide intermediate baselines between the one-cell stress
case and site allocation. Precision fields remain blank for incomplete analyses;
their smaller reached prefixes do not demonstrate smaller fixed points.

| Allocator | Complete configurations, GC off | Complete configurations, GC on |
| --- | ---: | ---: |
| Sites | 12 / 12 | 12 / 12 |
| Pool 1 | 4 / 12 | 4 / 12 |
| Pool 4 | 6 / 12 | 8 / 12 |
| Pool 16 | 9 / 12 | 12 / 12 |
| Pool 64 | 11 / 12 | 11 / 12 |

All repetitions agree on completion status: 89 of 120 configurations complete;
the other 31 reach the state cap. No trial hits a CPU or wall cutoff in this run.
These are completion rates for this corpus and budget, not a population estimate.

The size series reveals different regimes. `church_8` has 48 states under sites
and pool64 in both GC modes. Pool16 without GC reaches the cap; with GC it
completes at 965 states and still has two extra final syntaxes. For `multi_shot`,
pool16 with GC completes at 173 states while pool64 reaches the cap even with
GC; sites with GC complete at 96 states. More pool addresses do not guarantee
smaller graphs or completion under a fixed budget. Both pool schedule and the
explicit allocation phase affect state identity, and GC interacts with reuse.

Even completed graphs need separate metrics: `pipeline_8` without GC grows from
964 states at pool1 to 1,221 at pool4 and 2,030 at pool16, then drops to 44 at
pool64. This is evidence against interpreting address count as a universal
state-count improvement, not a general ordering of allocator precision.

With site allocation, shared writes drop from 85 to 33 states with GC. Repeated
calls drop from 18 states/two final syntaxes to 17 states/one final syntax. Church
iteration with four applications has 28 states in both GC modes: collection
need not shrink the graph even when it shrinks stores. Omega has no final states
in its complete graphs. Together with its known source structure this illustrates
nontermination; a generic empty set of finals alone would also allow stuckness.

Times are environment-specific observations. Consult `metadata.json` and raw
trials before comparing machines or settings. The suite does not establish an
asymptotic scaling law or a general speedup from GC. A larger corpus, additional
allocation policies, repeated runs on a controlled host, and extended-language
independent semantics remain useful subsequent work.

## Verification

`opam exec -- dune runtest` compares every complete site graph in this corpus against the
existing unbounded analyzer, tests exact-cap completion, and checks state/CPU
cutoff statuses. The experiment executable rejects a missing concrete result
syntax in complete terminating cases and rejects independent-reference
disagreement for pure terminating cases. These checks complement the existing
simulation and invariant suite; they are not a formal proof of the harness.
Small pooled graphs are also checked against complete analysis for every default
pool size. Python checks cover provenance tampering, archive verification, and
mixed completion statuses; CI runs these and verifies the recorded payload.

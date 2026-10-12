# Representative, reproducible experiments

Run from the repository root on Linux/WSL with OCaml, Dune, and Python 3:

```sh
python3 scripts/run_experiments.py
```

On Windows with the existing Ubuntu toolchain:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /mnt/c/Progetti/abstracting-abstract-machines && python3 scripts/run_experiments.py'
```

The command builds the executable and regenerates `results/representative/`:
`programs.csv` (exact source syntax and families), `raw.csv` (every trial),
`precision.csv`, `states.csv`, `store.csv`, `timing.csv`, `tables.md`, and
`metadata.json`. Metadata records configuration, tool versions, platform, UTC
timestamp, Git revision/status, and SHA-256 hashes of the implementation and
harness. Source hashes identify dirty or untracked implementations as well as
committed ones. Outputs are overwritten; save a separate copy to compare runs.

## Corpus and configurations

Ten closed AST programs cover identity pipelines of lengths two/four, Church
iteration of lengths two/four, repeated calls with different arguments, three
writes observed through a shared reader closure, mutation returning an old
closure from another environment, a continuation escape bypassing a divergent
branch, a saved continuation invoked twice with mutable flags, and omega.
Builders are in `lib/experiment_examples.ml`; `programs.csv`
prints the complete terms. These are small semantic workloads, not real-world
applications or a statistically representative population.

Each program runs under site allocation and a deliberately coarse one-address
pool, with GC off/on, with three fresh-process trials: 40 configurations and
120 trials. Defaults cap each graph at 5,000 reached states and each exploration
at two CPU seconds. A 15-second subprocess watchdog covers expensive individual
steps as well as setup. Limits can be changed explicitly:

```sh
python3 scripts/run_experiments.py --repetitions 5 --max-states 20000 --cpu-limit 10 --wall-limit 30
```

The complete library `Store_machine.analyze` is unchanged. The separate
experimental explorer reports `complete`, `state_limit`, or `cpu_limit`.
`wall_timeout` means the process was killed and graph measurements are unavailable.
CPU checks occur between worklist expansions, so the CPU limit can be exceeded
by one expansion. `complete` means the queue was exhausted without omitting any
successor. Reaching the state cap alone does not prevent completion if there is
no additional unseen state. Interrupted counts describe only a reached prefix;
they must not be compared to complete graphs as though both were fixed points.

## Four distinct measurements

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

All 20 site configurations complete. Fourteen pool configurations hit the state
cap; their precision fields remain blank. The intentionally coarse pool makes
the scalability limit visible without treating partial searches as evidence of
soundness or improved precision.

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

`dune runtest` compares every complete site graph in this corpus against the
existing unbounded analyzer, tests exact-cap completion, and checks state/CPU
cutoff statuses. The experiment executable rejects a missing concrete result
syntax in complete terminating cases and rejects independent-reference
disagreement for pure terminating cases. These checks complement the existing
simulation and invariant suite; they are not a formal proof of the harness.

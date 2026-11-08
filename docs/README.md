# Documentation guide

All shell commands in these documents run from the repository root.

## Short reading route

1. **Understand the study:** [REPORT.md](REPORT.md) gives the question,
   implementation, results, and limitations. For a five-minute review, read its
   abstract and Sections 5-6.
2. **See it work:** [WALKTHROUGH.md](WALKTHROUGH.md) follows one concrete trace,
   the exact abstract lookup that branches, and GC's precision gain.
3. **Check the correspondence:** [PAPER_TO_CODE.md](PAPER_TO_CODE.md) maps the
   supplied paper to implemented rules and tests, including interpretation choices.
4. **Reproduce it:** [REPRODUCIBILITY.md](REPRODUCIBILITY.md) covers installation,
   build, CI checks, experiment regeneration, and review archives.

## Consult as needed

| Question | Document |
| --- | --- |
| What are the module contracts and supported inputs? | [API.md](API.md) |
| What is argued mathematically, and under which assumptions? | [CORRECTNESS.md](CORRECTNESS.md) |
| What do the automated suites actually check? | [VALIDATION.md](VALIDATION.md) |
| How are measurements produced and interpreted? | [EXPERIMENTS.md](EXPERIMENTS.md), [recorded tables](../results/representative/tables.md) |
| How do mutation and first-class continuations work? | [State and control](details/STATE_AND_CONTROL.md) |
| How are roots, collection, and the separate GC comparison defined? | [Garbage collection](details/GARBAGE_COLLECTION.md) |
| How independent is the pure validation oracle? | [Reference semantics](details/REFERENCE_SEMANTICS.md) |

The [reference paper](reference-paper.pdf) is the supplied eight-page version;
paper page and figure references throughout the documentation refer to it.
The report owns scope and contribution claims; appendices retain operational
details and separate experiment protocols rather than repeating a milestone list.

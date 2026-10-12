Build an OCaml research project inspired by Van Horn and Might's "Abstracting Abstract Machines".
Implement a small untyped lambda calculus with variables, abstractions, and applications.
Define a clean AST using OCaml algebraic data types and pattern matching.
Implement a concrete CEK abstract machine and document its operational behavior.
Refactor the CEK machine into a store-allocated continuation machine.
Introduce finite abstractions of addresses and stores following the paper's core idea.
Implement an abstract interpreter that computes possible program states rather than one execution trace.
Provide small lambda-calculus examples comparing concrete execution with abstract analysis.
Add automated tests, PAPER_NOTES.md, IMPLEMENTATION_SCOPE.md, and a paper-to-code mapping document.
Keep the project focused on reproducing the paper's main construction faithfully rather than building a production compiler.

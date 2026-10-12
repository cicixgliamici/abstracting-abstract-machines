## Precision

| example | allocation | gc | status | concrete_outcome | concrete_syntax_included | extra_final_syntax |
| --- | --- | --- | --- | --- | --- | --- |
| pipeline_2 | sites | false | complete | finished | true | 0 |
| pipeline_2 | sites | true | complete | finished | true | 0 |
| pipeline_2 | pool1 | false | complete | finished | true | 2 |
| pipeline_2 | pool1 | true | complete | finished | true | 2 |
| pipeline_4 | sites | false | complete | finished | true | 0 |
| pipeline_4 | sites | true | complete | finished | true | 0 |
| pipeline_4 | pool1 | false | complete | finished | true | 2 |
| pipeline_4 | pool1 | true | complete | finished | true | 2 |
| church_2 | sites | false | complete | finished | true | 0 |
| church_2 | sites | true | complete | finished | true | 0 |
| church_2 | pool1 | false | state_limit |  |  |  |
| church_2 | pool1 | true | state_limit |  |  |  |
| church_4 | sites | false | complete | finished | true | 0 |
| church_4 | sites | true | complete | finished | true | 0 |
| church_4 | pool1 | false | state_limit |  |  |  |
| church_4 | pool1 | true | state_limit |  |  |  |
| repeated_calls | sites | false | complete | finished | true | 1 |
| repeated_calls | sites | true | complete | finished | true | 0 |
| repeated_calls | pool1 | false | state_limit |  |  |  |
| repeated_calls | pool1 | true | state_limit |  |  |  |
| shared_writes | sites | false | complete | finished | true | 2 |
| shared_writes | sites | true | complete | finished | true | 2 |
| shared_writes | pool1 | false | state_limit |  |  |  |
| shared_writes | pool1 | true | state_limit |  |  |  |
| old_closure_environment | sites | false | complete | finished | true | 0 |
| old_closure_environment | sites | true | complete | finished | true | 0 |
| old_closure_environment | pool1 | false | state_limit |  |  |  |
| old_closure_environment | pool1 | true | state_limit |  |  |  |
| escape_skips_omega | sites | false | complete | finished | true | 0 |
| escape_skips_omega | sites | true | complete | finished | true | 0 |
| escape_skips_omega | pool1 | false | state_limit |  |  |  |
| escape_skips_omega | pool1 | true | state_limit |  |  |  |
| multi_shot | sites | false | complete | finished | true | 2 |
| multi_shot | sites | true | complete | finished | true | 1 |
| multi_shot | pool1 | false | state_limit |  |  |  |
| multi_shot | pool1 | true | state_limit |  |  |  |
| omega | sites | false | complete | fuel_exhausted |  |  |
| omega | sites | true | complete | fuel_exhausted |  |  |
| omega | pool1 | false | complete | fuel_exhausted |  |  |
| omega | pool1 | true | complete | fuel_exhausted |  |  |

## States

| example | allocation | gc | status | reachable_states | final_states |
| --- | --- | --- | --- | --- | --- |
| pipeline_2 | sites | false | complete | 14 | 1 |
| pipeline_2 | sites | true | complete | 14 | 1 |
| pipeline_2 | pool1 | false | complete | 357 | 70 |
| pipeline_2 | pool1 | true | complete | 311 | 24 |
| pipeline_4 | sites | false | complete | 24 | 1 |
| pipeline_4 | sites | true | complete | 24 | 1 |
| pipeline_4 | pool1 | false | complete | 612 | 84 |
| pipeline_4 | pool1 | true | complete | 556 | 28 |
| church_2 | sites | false | complete | 18 | 1 |
| church_2 | sites | true | complete | 18 | 1 |
| church_2 | pool1 | false | state_limit | 5000 | 956 |
| church_2 | pool1 | true | state_limit | 5000 | 560 |
| church_4 | sites | false | complete | 28 | 1 |
| church_4 | sites | true | complete | 28 | 1 |
| church_4 | pool1 | false | state_limit | 5000 | 956 |
| church_4 | pool1 | true | state_limit | 5000 | 560 |
| repeated_calls | sites | false | complete | 18 | 2 |
| repeated_calls | sites | true | complete | 17 | 1 |
| repeated_calls | pool1 | false | state_limit | 5000 | 511 |
| repeated_calls | pool1 | true | state_limit | 5000 | 185 |
| shared_writes | sites | false | complete | 85 | 24 |
| shared_writes | sites | true | complete | 33 | 4 |
| shared_writes | pool1 | false | state_limit | 5000 | 551 |
| shared_writes | pool1 | true | state_limit | 5000 | 359 |
| old_closure_environment | sites | false | complete | 21 | 1 |
| old_closure_environment | sites | true | complete | 21 | 1 |
| old_closure_environment | pool1 | false | state_limit | 5000 | 678 |
| old_closure_environment | pool1 | true | state_limit | 5000 | 424 |
| escape_skips_omega | sites | false | complete | 10 | 1 |
| escape_skips_omega | sites | true | complete | 10 | 1 |
| escape_skips_omega | pool1 | false | state_limit | 5000 | 518 |
| escape_skips_omega | pool1 | true | state_limit | 5000 | 655 |
| multi_shot | sites | false | complete | 736 | 48 |
| multi_shot | sites | true | complete | 96 | 2 |
| multi_shot | pool1 | false | state_limit | 5000 | 519 |
| multi_shot | pool1 | true | state_limit | 5000 | 182 |
| omega | sites | false | complete | 16 | 0 |
| omega | sites | true | complete | 13 | 0 |
| omega | pool1 | false | complete | 27 | 0 |
| omega | pool1 | true | complete | 27 | 0 |

## Store

| example | allocation | gc | status | max_store_addresses | max_store_values |
| --- | --- | --- | --- | --- | --- |
| pipeline_2 | sites | false | complete | 9 | 9 |
| pipeline_2 | sites | true | complete | 4 | 4 |
| pipeline_2 | pool1 | false | complete | 2 | 14 |
| pipeline_2 | pool1 | true | complete | 2 | 14 |
| pipeline_4 | sites | false | complete | 13 | 13 |
| pipeline_4 | sites | true | complete | 6 | 6 |
| pipeline_4 | pool1 | false | complete | 2 | 16 |
| pipeline_4 | pool1 | true | complete | 2 | 16 |
| church_2 | sites | false | complete | 12 | 12 |
| church_2 | sites | true | complete | 5 | 5 |
| church_2 | pool1 | false | state_limit | 2 | 13 |
| church_2 | pool1 | true | state_limit | 2 | 13 |
| church_4 | sites | false | complete | 16 | 16 |
| church_4 | sites | true | complete | 7 | 7 |
| church_4 | pool1 | false | state_limit | 2 | 13 |
| church_4 | pool1 | true | state_limit | 2 | 13 |
| repeated_calls | sites | false | complete | 12 | 13 |
| repeated_calls | sites | true | complete | 4 | 4 |
| repeated_calls | pool1 | false | state_limit | 2 | 15 |
| repeated_calls | pool1 | true | state_limit | 2 | 15 |
| shared_writes | sites | false | complete | 22 | 25 |
| shared_writes | sites | true | complete | 5 | 7 |
| shared_writes | pool1 | false | state_limit | 2 | 16 |
| shared_writes | pool1 | true | state_limit | 2 | 16 |
| old_closure_environment | sites | false | complete | 17 | 18 |
| old_closure_environment | sites | true | complete | 7 | 7 |
| old_closure_environment | pool1 | false | state_limit | 2 | 16 |
| old_closure_environment | pool1 | true | state_limit | 2 | 17 |
| escape_skips_omega | sites | false | complete | 8 | 8 |
| escape_skips_omega | sites | true | complete | 4 | 4 |
| escape_skips_omega | pool1 | false | state_limit | 2 | 13 |
| escape_skips_omega | pool1 | true | state_limit | 2 | 16 |
| multi_shot | sites | false | complete | 34 | 43 |
| multi_shot | sites | true | complete | 8 | 10 |
| multi_shot | pool1 | false | state_limit | 2 | 16 |
| multi_shot | pool1 | true | state_limit | 2 | 16 |
| omega | sites | false | complete | 9 | 9 |
| omega | sites | true | complete | 3 | 3 |
| omega | pool1 | false | complete | 2 | 7 |
| omega | pool1 | true | complete | 2 | 7 |

## Timing

| example | allocation | gc | status | cpu_seconds | wall_seconds |
| --- | --- | --- | --- | --- | --- |
| pipeline_2 | sites | false | complete | 0.000066000 | 0.000051975 |
| pipeline_2 | sites | true | complete | 0.000072000 | 0.000061035 |
| pipeline_2 | pool1 | false | complete | 0.018487000 | 0.018475056 |
| pipeline_2 | pool1 | true | complete | 0.023025000 | 0.023046970 |
| pipeline_4 | sites | false | complete | 0.000159000 | 0.000143051 |
| pipeline_4 | sites | true | complete | 0.000144000 | 0.000132084 |
| pipeline_4 | pool1 | false | complete | 0.021251000 | 0.021240950 |
| pipeline_4 | pool1 | true | complete | 0.024293000 | 0.024311066 |
| church_2 | sites | false | complete | 0.000069000 | 0.000057936 |
| church_2 | sites | true | complete | 0.000098000 | 0.000085831 |
| church_2 | pool1 | false | state_limit | 0.332820000 | 0.332817793 |
| church_2 | pool1 | true | state_limit | 0.337324000 | 0.337321997 |
| church_4 | sites | false | complete | 0.000102000 | 0.000090837 |
| church_4 | sites | true | complete | 0.000199000 | 0.000187874 |
| church_4 | pool1 | false | state_limit | 0.291372000 | 0.291367054 |
| church_4 | pool1 | true | state_limit | 0.345776000 | 0.345825911 |
| repeated_calls | sites | false | complete | 0.000070000 | 0.000059843 |
| repeated_calls | sites | true | complete | 0.000087000 | 0.000077009 |
| repeated_calls | pool1 | false | state_limit | 0.337734000 | 0.337776899 |
| repeated_calls | pool1 | true | state_limit | 0.372230000 | 0.372251987 |
| shared_writes | sites | false | complete | 0.001510000 | 0.001498938 |
| shared_writes | sites | true | complete | 0.000313000 | 0.000301838 |
| shared_writes | pool1 | false | state_limit | 0.354428000 | 0.354439974 |
| shared_writes | pool1 | true | state_limit | 0.464512000 | 0.464611053 |
| old_closure_environment | sites | false | complete | 0.000086000 | 0.000075102 |
| old_closure_environment | sites | true | complete | 0.000157000 | 0.000146151 |
| old_closure_environment | pool1 | false | state_limit | 0.358670000 | 0.358666182 |
| old_closure_environment | pool1 | true | state_limit | 0.497903000 | 0.497925997 |
| escape_skips_omega | sites | false | complete | 0.000048000 | 0.000033855 |
| escape_skips_omega | sites | true | complete | 0.000096000 | 0.000072002 |
| escape_skips_omega | pool1 | false | state_limit | 0.253471000 | 0.253533125 |
| escape_skips_omega | pool1 | true | state_limit | 0.402681000 | 0.402678967 |
| multi_shot | sites | false | complete | 0.032474000 | 0.032466888 |
| multi_shot | sites | true | complete | 0.004217000 | 0.004201889 |
| multi_shot | pool1 | false | state_limit | 0.354461000 | 0.354460955 |
| multi_shot | pool1 | true | state_limit | 0.570877000 | 0.570893049 |
| omega | sites | false | complete | 0.000080000 | 0.000066042 |
| omega | sites | true | complete | 0.000073000 | 0.000061989 |
| omega | pool1 | false | complete | 0.000148000 | 0.000137091 |
| omega | pool1 | true | complete | 0.000210000 | 0.000196934 |

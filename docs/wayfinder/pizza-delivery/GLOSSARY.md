# Pizza Delivery glossary

**Job**: one submitted prompt and its whole run through the pipeline.

**Stage**: one pipeline step inside a job (for example self-grill, spec, implement, review).

**Handoff**: the validated document a finishing stage passes to the next stage.

**Feedback entry**: something the agent surfaces for the human: an assumption it made, a question it could not answer, or a risk it noticed.

**Follow-up job**: a job created by the human replying to one or more feedback entries of an earlier job.

**Ledger**: the append-only log of everything that happened to every job.

**View**: one way of presenting the same set of jobs.

**Table**: the view that lists jobs as rows.

**Board**: the view that groups jobs into one column per job state.

**Pipeline**: the view that shows one lane per job with one segment per stage.

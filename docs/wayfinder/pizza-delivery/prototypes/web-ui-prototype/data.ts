export type Job = {
  id: string;
  prompt: string;
  repo: string;
  state: "running" | "queued" | "parked" | "needs-human" | "done" | "failed";
  stages: { name: string; status: "done" | "running" | "pending" | "failed"; mins: number; est: number }[];
  agent: string;
  elapsed: string;
  estimate: string;
  feedbackOpen: number;
  pr?: string;
  note?: string;
};

export type Feedback = {
  id: string;
  job: string;
  kind: "assumption" | "question" | "risk";
  severity: "high" | "medium" | "low";
  confidence?: "low" | "medium" | "high";
  text: string;
  alternatives?: string[];
  assumed?: string;
  impact?: string;
  stage: string;
};

export type Ev = { seq: number; ts: string; job: string; kind: string; family: string; summary: string };

export const jobs: Job[] = [
  {
    id: "01JD8K3Q",
    prompt: "Test the last implementation we did on the cregit pipeline and check if we need to submit a PR with additional test coverage.",
    repo: "cregit",
    state: "running",
    stages: [
      { name: "triage", status: "done", mins: 1, est: 2 },
      { name: "investigate", status: "done", mins: 9, est: 12 },
      { name: "grill", status: "done", mins: 6, est: 10 },
      { name: "implement", status: "running", mins: 14, est: 30 },
      { name: "review", status: "pending", mins: 0, est: 12 },
      { name: "ship", status: "pending", mins: 0, est: 1 },
    ],
    agent: "claude / sonnet-5.5",
    elapsed: "30m",
    estimate: "65m",
    feedbackOpen: 2,
  },
  {
    id: "01JD8H7M",
    prompt: "Add retry with backoff to the wanikani-reinforcer sync",
    repo: "wanikani-reinforcer",
    state: "done",
    stages: [
      { name: "triage", status: "done", mins: 1, est: 2 },
      { name: "grill", status: "done", mins: 5, est: 8 },
      { name: "implement", status: "done", mins: 22, est: 25 },
      { name: "review", status: "done", mins: 9, est: 10 },
      { name: "ship", status: "done", mins: 1, est: 1 },
    ],
    agent: "claude / sonnet-5.5",
    elapsed: "38m",
    estimate: "46m",
    feedbackOpen: 0,
    pr: "draft PR: retry-with-backoff",
  },
  {
    id: "01JD8F2A",
    prompt: "Bump the watermarks-remover pin to the latest tagged release",
    repo: ".dotfiles",
    state: "needs-human",
    stages: [
      { name: "triage", status: "done", mins: 1, est: 2 },
      { name: "implement", status: "done", mins: 6, est: 8 },
      { name: "review", status: "done", mins: 4, est: 6 },
      { name: "ship", status: "pending", mins: 0, est: 1 },
    ],
    agent: "hermes / gemini-3.6-flash",
    elapsed: "11m",
    estimate: "17m",
    feedbackOpen: 1,
    note: "Diff policy flagged a workflow file",
  },
  {
    id: "01JD8C9Z",
    prompt: "Summarize open TODOs in kworkflow and draft issues",
    repo: "kworkflow",
    state: "parked",
    stages: [
      { name: "triage", status: "done", mins: 1, est: 2 },
      { name: "investigate", status: "running", mins: 3, est: 10 },
      { name: "ship", status: "pending", mins: 0, est: 1 },
    ],
    agent: "waiting for quota",
    elapsed: "4m",
    estimate: "13m",
    feedbackOpen: 0,
    note: "All candidates exhausted, earliest reset 18:40",
  },
  {
    id: "01JD8B1X",
    prompt: "Check why the home-server backup timer drifts",
    repo: "home-server",
    state: "queued",
    stages: [
      { name: "triage", status: "pending", mins: 0, est: 2 },
    ],
    agent: "-",
    elapsed: "0m",
    estimate: "?",
    feedbackOpen: 0,
  },
];

export const feedback: Feedback[] = [
  {
    id: "fb-1",
    job: "01JD8F2A",
    kind: "risk",
    severity: "high",
    text: "The change touches .github/workflows/release.yml (bumped a pinned action alongside the tag).",
    impact: "Workflow changes run with repo secrets once merged.",
    stage: "review",
  },
  {
    id: "fb-2",
    job: "01JD8K3Q",
    kind: "assumption",
    severity: "medium",
    confidence: "low",
    text: "Took \"the last implementation\" to mean the commits since tag v0.3 on branch main.",
    alternatives: ["last merged PR only", "HEAD~5..HEAD"],
    impact: "Tests may target the wrong code if the range is wrong.",
    stage: "grill",
  },
  {
    id: "fb-3",
    job: "01JD8K3Q",
    kind: "question",
    severity: "low",
    text: "Could not tell whether upstream wants new tests under tests/ or next to modules.",
    assumed: "tests/ (matches the existing layout)",
    stage: "investigate",
  },
];

export const events: Ev[] = [
  { seq: 48219, ts: "17:52:10", job: "01JD8K3Q", family: "agent", kind: "agent-invoked", summary: "claude sonnet-5.5, stage implement, attempt 1" },
  { seq: 48218, ts: "17:51:58", job: "01JD8K3Q", family: "stage", kind: "stage-started", summary: "implement" },
  { seq: 48217, ts: "17:51:57", job: "01JD8K3Q", family: "feedback", kind: "assumption-recorded", summary: "commit range since v0.3 (confidence low)" },
  { seq: 48210, ts: "17:44:31", job: "01JD8F2A", family: "feedback", kind: "risk-recorded", summary: "diff touches .github/workflows/release.yml" },
  { seq: 48209, ts: "17:44:30", job: "01JD8F2A", family: "job", kind: "job-needs-human", summary: "ship stage held by diff policy" },
  { seq: 48198, ts: "17:31:02", job: "01JD8C9Z", family: "agent", kind: "quota-signal", summary: "claude five_hour exhausted, reset 18:40" },
  { seq: 48197, ts: "17:31:02", job: "01JD8C9Z", family: "job", kind: "job-parked", summary: "waiting for quota" },
  { seq: 48190, ts: "17:20:44", job: "01JD8H7M", family: "change", kind: "pr-opened", summary: "draft PR retry-with-backoff" },
  { seq: 48189, ts: "17:20:41", job: "01JD8H7M", family: "change", kind: "branch-pushed", summary: "pizza/01JD8H7M" },
  { seq: 48180, ts: "17:12:05", job: "01JD8H7M", family: "change", kind: "commit", summary: "3 files, +84 -12" },
  { seq: 48170, ts: "17:02:19", job: "01JD8K3Q", family: "memory", kind: "context-read", summary: "engram 6 observations, mnemon 4" },
  { seq: 48169, ts: "17:02:10", job: "01JD8K3Q", family: "job", kind: "job-submitted", summary: "pizza-delivery \"Test the last implementation...\"" },
];

export const quota = [
  { agent: "claude", window: "5h", pct: 91, resets: "18:40" },
  { agent: "claude", window: "7d", pct: 34, resets: "Fri" },
  { agent: "hermes", window: "-", pct: 12, resets: "-" },
  { agent: "agy", window: "-", pct: 5, resets: "-" },
];

export const stateType = (s: Job["state"]) =>
  ({ running: "in-progress", queued: "pending", parked: "stopped", "needs-human": "warning", done: "success", failed: "error" }[s]) as
    | "in-progress"
    | "pending"
    | "stopped"
    | "warning"
    | "success"
    | "error";

import React, { useState } from "react";
import {
  AppLayout, Badge, Box, Button, ColumnLayout, Container, ContentLayout, Header, Link, ProgressBar,
  SpaceBetween, SplitPanel, StatusIndicator, Table, Tabs, TopNavigation,
} from "@cloudscape-design/components";
import { feedback, jobs, quota, stateType, Job } from "./data";

export function VariantA() {
  const [sel, setSel] = useState<Job>(jobs[0]);
  const count = (s: Job["state"]) => jobs.filter((j) => j.state === s).length;
  const open = feedback.length;

  return (
    <>
      <TopNavigation identity={{ href: "#", title: "pizza-delivery" }} utilities={[{ type: "button", text: `${open} need you`, iconName: "notification" }]} />
      <AppLayout
        navigationHide
        toolsHide
        splitPanelOpen
        splitPanelPreferences={{ position: "side" }}
        splitPanel={
          <SplitPanel header={`Job ${sel.id}`} closeBehavior="hide">
            <Tabs
              tabs={[
                {
                  id: "timeline", label: "Stages",
                  content: (
                    <SpaceBetween size="s">
                      <Box variant="p">{sel.prompt}</Box>
                      {sel.stages.map((s) => (
                        <div key={s.name} style={{ display: "flex", justifyContent: "space-between" }}>
                          <StatusIndicator type={s.status === "done" ? "success" : s.status === "running" ? "in-progress" : s.status === "failed" ? "error" : "pending"}>
                            {s.name}
                          </StatusIndicator>
                          <Box color="text-body-secondary">{s.status === "pending" ? `est ${s.est}m` : `${s.mins}m of est ${s.est}m`}</Box>
                        </div>
                      ))}
                    </SpaceBetween>
                  ),
                },
                {
                  id: "fb", label: `Feedback (${feedback.filter((f) => f.job === sel.id).length})`,
                  content: (
                    <SpaceBetween size="s">
                      {feedback.filter((f) => f.job === sel.id).map((f) => (
                        <Box key={f.id}>
                          <Badge color={f.severity === "high" ? "red" : "blue"}>{f.kind}</Badge> {f.text}
                        </Box>
                      ))}
                      {feedback.filter((f) => f.job === sel.id).length === 0 && <Box color="text-status-inactive">Nothing open.</Box>}
                    </SpaceBetween>
                  ),
                },
                {
                  id: "art", label: "Artifacts",
                  content: (
                    <SpaceBetween size="xs">
                      <Link href="#">context.md</Link>
                      <Link href="#">triage handoff</Link>
                      <Link href="#">spec.md</Link>
                      <Link href="#">review report</Link>
                      {sel.pr && <Link href="#" external>{sel.pr}</Link>}
                    </SpaceBetween>
                  ),
                },
              ]}
            />
          </SplitPanel>
        }
        content={
          <ContentLayout
            header={<Header variant="h1" description="Local daemon, single machine" actions={<Button variant="primary">New job</Button>}>Jobs</Header>}
          >
            <SpaceBetween size="l">
              <Container>
                <ColumnLayout columns={5} variant="text-grid">
                  <div><Box variant="awsui-key-label">Running</Box><Box variant="awsui-value-large">{count("running")}</Box></div>
                  <div><Box variant="awsui-key-label">Queued</Box><Box variant="awsui-value-large">{count("queued")}</Box></div>
                  <div><Box variant="awsui-key-label">Parked on quota</Box><Box variant="awsui-value-large">{count("parked")}</Box></div>
                  <div><Box variant="awsui-key-label">Needs you</Box><Box variant="awsui-value-large">{count("needs-human")}</Box></div>
                  <div><Box variant="awsui-key-label">Open feedback</Box><Box variant="awsui-value-large">{open}</Box></div>
                </ColumnLayout>
              </Container>
              <Table
                variant="container"
                selectionType="single"
                selectedItems={[sel]}
                onSelectionChange={({ detail }) => setSel(detail.selectedItems[0] ?? sel)}
                trackBy="id"
                header={<Header counter={`(${jobs.length})`}>Active and recent</Header>}
                items={jobs}
                columnDefinitions={[
                  { id: "id", header: "Job", cell: (j) => j.id },
                  { id: "repo", header: "Repo", cell: (j) => j.repo },
                  { id: "state", header: "State", cell: (j) => <StatusIndicator type={stateType(j.state)}>{j.state}</StatusIndicator> },
                  { id: "stage", header: "Stage", cell: (j) => `${j.stages.filter((s) => s.status === "done").length}/${j.stages.length}` },
                  { id: "agent", header: "Agent", cell: (j) => j.agent },
                  { id: "time", header: "Elapsed / est", cell: (j) => `${j.elapsed} / ${j.estimate}` },
                  { id: "fb", header: "Feedback", cell: (j) => (j.feedbackOpen ? <Badge color="red">{j.feedbackOpen}</Badge> : "-") },
                  { id: "pr", header: "PR", cell: (j) => j.pr ?? "-" },
                ]}
              />
              <Container header={<Header variant="h2">Agent quota</Header>}>
                <ColumnLayout columns={4}>
                  {quota.map((q) => (
                    <ProgressBar key={q.agent + q.window} value={q.pct} label={`${q.agent} ${q.window}`} description={q.resets !== "-" ? `resets ${q.resets}` : undefined} status={q.pct > 85 ? "error" : "in-progress"} />
                  ))}
                </ColumnLayout>
              </Container>
            </SpaceBetween>
          </ContentLayout>
        }
      />
    </>
  );
}

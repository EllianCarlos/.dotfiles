import React, { useState } from "react";
import {
  Alert, Badge, Box, Button, Cards, Container, ExpandableSection, Grid, Header, ProgressBar, SpaceBetween,
  StatusIndicator, Textarea, TopNavigation,
} from "@cloudscape-design/components";
import { feedback as seed, jobs, quota, stateType, Feedback } from "./data";

const sev = { high: 0, medium: 1, low: 2 } as const;

export function VariantB() {
  const [items, setItems] = useState<Feedback[]>([...seed].sort((a, b) => sev[a.severity] - sev[b.severity]));
  const [text, setText] = useState<Record<string, string>>({});
  const [done, setDone] = useState<string[]>([]);

  return (
    <>
      <TopNavigation identity={{ href: "#", title: "pizza-delivery" }} />
      <Box padding={{ horizontal: "xl", vertical: "l" }}>
        <SpaceBetween size="l">
          <Header
            variant="h1"
            description="The agent kept going. These are the points it assumed or could not answer."
            actions={<Button>Reply to all with defaults</Button>}
          >
            {items.length} things for you
          </Header>
          {done.length > 0 && (
            <Alert type="success" dismissible onDismiss={() => setDone([])}>
              {done.length} follow-up job(s) queued: {done.join(", ")}
            </Alert>
          )}
          <Grid gridDefinition={[{ colspan: { default: 12, m: 8 } }, { colspan: { default: 12, m: 4 } }]}>
            <Cards
              cardsPerRow={[{ cards: 1 }]}
              items={items}
              empty={<Box textAlign="center" color="text-status-inactive">Inbox zero. Nothing is waiting on you.</Box>}
              cardDefinition={{
                header: (f) => (
                  <SpaceBetween direction="horizontal" size="xs">
                    <Badge color={f.severity === "high" ? "red" : f.severity === "medium" ? "blue" : "grey"}>{f.kind}</Badge>
                    {f.confidence && <Badge>confidence {f.confidence}</Badge>}
                    <Box color="text-body-secondary">job {f.job} · {f.stage}</Box>
                  </SpaceBetween>
                ),
                sections: [
                  { id: "t", content: (f) => <Box variant="p">{f.text}</Box> },
                  {
                    id: "d", content: (f) => (
                      <ExpandableSection headerText="Alternatives and impact" variant="footer">
                        <SpaceBetween size="xs">
                          {f.assumed && <Box>Assumed: {f.assumed}</Box>}
                          {f.alternatives && <Box>Considered: {f.alternatives.join("; ")}</Box>}
                          {f.impact && <Box>Impact: {f.impact}</Box>}
                        </SpaceBetween>
                      </ExpandableSection>
                    ),
                  },
                  {
                    id: "r", content: (f) => (
                      <SpaceBetween size="xs">
                        <Textarea
                          rows={2}
                          placeholder="Your answer becomes the context of a follow-up job"
                          value={text[f.id] ?? ""}
                          onChange={({ detail }) => setText({ ...text, [f.id]: detail.value })}
                        />
                        <SpaceBetween direction="horizontal" size="xs">
                          <Button
                            variant="primary"
                            disabled={!(text[f.id] ?? "").trim()}
                            onClick={() => { setDone([...done, `${f.job}-followup`]); setItems(items.filter((x) => x.id !== f.id)); }}
                          >
                            Reply and spawn follow-up
                          </Button>
                          <Button onClick={() => setItems(items.filter((x) => x.id !== f.id))}>Looks fine, dismiss</Button>
                        </SpaceBetween>
                      </SpaceBetween>
                    ),
                  },
                ],
              }}
            />
            <SpaceBetween size="l">
              <Container header={<Header variant="h2">Jobs</Header>}>
                <SpaceBetween size="s">
                  {jobs.map((j) => (
                    <div key={j.id}>
                      <StatusIndicator type={stateType(j.state)}>{j.repo} · {j.state}</StatusIndicator>
                      <Box variant="small" color="text-body-secondary">{j.id} · {j.elapsed} / {j.estimate}</Box>
                    </div>
                  ))}
                </SpaceBetween>
              </Container>
              <Container header={<Header variant="h2">Quota</Header>}>
                <SpaceBetween size="s">
                  {quota.map((q) => (
                    <ProgressBar key={q.agent + q.window} value={q.pct} label={`${q.agent} ${q.window}`} status={q.pct > 85 ? "error" : "in-progress"} />
                  ))}
                </SpaceBetween>
              </Container>
            </SpaceBetween>
          </Grid>
        </SpaceBetween>
      </Box>
    </>
  );
}

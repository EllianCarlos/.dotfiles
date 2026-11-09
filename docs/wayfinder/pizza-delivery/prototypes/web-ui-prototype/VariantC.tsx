import React, { useState } from "react";
import {
  Badge, Box, Container, Header, SegmentedControl, SpaceBetween, StatusIndicator, Table, TopNavigation,
} from "@cloudscape-design/components";
import { events, jobs, quota } from "./data";

const colors: Record<string, string> = { done: "#037f0c", running: "#0972d3", pending: "#d5dbdb", failed: "#d91515" };

export function VariantC() {
  const [filter, setFilter] = useState("all");
  const shown = events.filter((e) => filter === "all" || e.family === filter);
  const totalEst = Math.max(...jobs.map((j) => j.stages.reduce((a, s) => a + Math.max(s.est, s.mins), 0)));

  return (
    <>
      <TopNavigation
        identity={{ href: "#", title: "pizza-delivery" }}
        utilities={[{ type: "button", text: `claude 5h ${quota[0].pct}% · resets ${quota[0].resets}` }]}
      />
      <Box padding={{ horizontal: "xl", vertical: "l" }}>
        <SpaceBetween size="l">
          <Header variant="h1" description="Everything that happened, in order. Jobs on top, events below.">Ledger</Header>
          <Container header={<Header variant="h2">Swimlanes (estimated minutes)</Header>}>
            <SpaceBetween size="s">
              {jobs.map((j) => (
                <div key={j.id} style={{ display: "grid", gridTemplateColumns: "190px 1fr", alignItems: "center", gap: 12 }}>
                  <div>
                    <Box variant="strong">{j.repo}</Box>
                    <Box variant="small" color="text-body-secondary">{j.id} · {j.state}</Box>
                  </div>
                  <div style={{ display: "flex", height: 26, gap: 2 }}>
                    {j.stages.map((s) => (
                      <div
                        key={s.name}
                        title={`${s.name}: ${s.status}`}
                        style={{
                          width: `${(Math.max(s.est, s.mins) / totalEst) * 100}%`, background: colors[s.status], color: s.status === "pending" ? "#414d5c" : "#fff",
                          fontSize: 11, display: "flex", alignItems: "center", justifyContent: "center", borderRadius: 3, overflow: "hidden",
                          outline: j.state === "needs-human" && s.name === "ship" ? "2px solid #d91515" : undefined,
                        }}
                      >
                        {s.name}
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </SpaceBetween>
          </Container>
          <Table
            variant="container"
            header={
              <Header
                counter={`(${shown.length})`}
                actions={
                  <SegmentedControl
                    selectedId={filter}
                    onChange={({ detail }) => setFilter(detail.selectedId)}
                    options={[
                      { id: "all", text: "All" }, { id: "change", text: "Changes" }, { id: "agent", text: "Agent" },
                      { id: "feedback", text: "Feedback" }, { id: "job", text: "Jobs" }, { id: "memory", text: "Memory" },
                    ]}
                  />
                }
                description={<StatusIndicator type="in-progress">following · last seq 48219</StatusIndicator>}
              >
                Event stream
              </Header>
            }
            items={shown}
            trackBy="seq"
            columnDefinitions={[
              { id: "seq", header: "Seq", cell: (e) => e.seq },
              { id: "ts", header: "Time", cell: (e) => e.ts },
              { id: "job", header: "Job", cell: (e) => e.job },
              { id: "kind", header: "Event", cell: (e) => <Badge color={e.family === "feedback" ? "red" : e.family === "change" ? "green" : "blue"}>{e.kind}</Badge> },
              { id: "sum", header: "Detail", cell: (e) => e.summary },
            ]}
          />
        </SpaceBetween>
      </Box>
    </>
  );
}

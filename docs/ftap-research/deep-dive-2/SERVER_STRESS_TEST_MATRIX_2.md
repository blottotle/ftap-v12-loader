# Server Stress Test Matrix 2

These are distinct developer-owned server workload tests. They are intended for an isolated/private test place and should have bounded levels, automatic cleanup, and a server panic stop.

| ID | Workload | Primary subsystem | Distinguishing metric |
|---|---|---|---|
| OWN-TOPOLOGY | alternate assembly ownership while splitting/merging a bounded joint graph | distributed physics + assembly | ownership + assemble scopes |
| WAKE-PROP | wake sleeping assemblies via controlled physics-property changes | physics | awake count + physicsStepped |
| WAKE-IMPULSE | wake bounded batches with impulses | physics | physicsStepped |
| WAKE-CONSTRAINT | alter/create constraints to wake/rebuild test assemblies | physics/assemble | assemble + physicsStepped |
| WAKE-CONTACT | controlled collisions across test assemblies | contacts/physics | contact/physics scopes |
| JOINT-CHURN | create/destroy bounded WeldConstraint/Motor6D graph | assembly | Simulation/assemble |
| REPL-TREE | clone/destroy nested model trees | replication | data ping + senders |
| REPL-PROP | change replicated properties on a bounded pool | replication | data ping + senders |
| REPL-ATTR | replicated attribute churn | replication | ProcessPackets/senders |
| REPL-TWEEN | server-side TweenService on bounded pool | replication | data ping + senders |
| NET-CACHE | cached byte payload on dedicated test remote | inbound networking | ProcessPackets |
| NET-CADENCE | elapsed-time compensated bounded send cadence | inbound networking | ProcessPackets + call rate |
| NET-SHAPE | equal byte budget across benign schemas | deserialize/handler | ProcessPackets + handler label |
| NET-RF | bounded RemoteFunction latency/queue comparison | network + yielding handler | handler latency |
| NPC-STATE | dummy Humanoid state/ragdoll/joint churn | script + physics | Heartbeat + assemble |
| PATH-BATCH | bounded parallel path computations | compute | server Heartbeat |
| QUERY-BATCH | bounded raycast/spatial-query batch | compute/physics queries | server Heartbeat |
| ALLOC-GC | transient server table/instance allocation with cleanup | allocator/GC | Heartbeat + memory |

## Required controls for every test

- Off by default.
- Separate toggle per mechanism.
- Three bounded levels (A/B/C) rather than an unlimited slider.
- Server panic stop.
- Max runtime for automatic tests; continuous mode only where cleanup remains responsive.
- Dedicated test instances/tags so cleanup never deletes real gameplay objects.
- Baseline/stress/recovery measurement.
- `debug.profilebegin()` label.
- Result record in DEBUG2.

## Interpretation guide

- **Server Heartbeat falls, data ping stays close to network ping:** likely compute/physics dominated.
- **Data ping rises far above network ping:** replication/network queue is a major component.
- **ProcessPackets dominates:** inbound remote/serialization/handler pressure.
- **Allocate Bandwidth and Run Senders dominates:** server replication/output pressure.
- **Simulation/assemble rises:** joint/assembly graph rebuild is significant.
- **Distributed Physics Ownership rises:** ownership assignment/migration is significant.
- **physicsStepped rises:** active rigid-body/contact/constraint simulation is significant.
- **Recovery stays poor after generator stops:** backlog or cleanup problem; mark PARTIAL/FAIL even if visible lag was strong.

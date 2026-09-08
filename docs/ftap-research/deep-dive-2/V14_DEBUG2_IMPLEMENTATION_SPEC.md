# V14 DEBUG2 Implementation Spec

This spec is deliberately observational. It is designed to improve FTAP V14 diagnostics without replacing the original working lag/blob mechanisms or adding a PlaceId lock.

## Required components

### A. Generation tracker
Maintain monotonically increasing IDs for:
- local Character
- selected target Character
- mounted Blobman

Any cached root, detector, weld, or state object carries the generation it came from. Before use, compare generations; if mismatched, classify as `STALE_*` and reacquire.

### B. Test-run recorder
For every toggle/button run record:
- `runId`
- `testId`
- start/stop time
- initial config
- target name
- generation IDs
- preflight result
- stop reason
- cleanup result

### C. Shared invocation observer
When DEBUG2 is enabled, wrap the shared remote helpers only for metadata collection. Do not mutate arguments or scheduling.

Record:
- remote path/class
- argument type vector
- approximate string/table byte count
- invocation interval
- local success/error
- rolling calls/sec and bytes/sec
- runId/testId

### D. Lifecycle observer
Narrowly watch containers relevant to the running test. Count creation/removal of:
- grab-line objects
- Beam/Constraint/Weld descendants
- spawned toys
- Blobman models
- selected target Character

Avoid recursively connecting a listener to every Workspace node.

### E. Blob compatibility snapshot
Before each Blob test print:
- mounted Blob path and generation
- LeftDetector / LeftWeld
- RightDetector / RightWeld
- CreatureGrab
- CreatureDrop
- CreatureRelease
- current seat occupant
- selected target generation/root
- SetNetworkOwner / CreateGrabLine / DestroyGrabLine availability

### F. State acknowledgement
A local FireServer return is not success. Give each phase a short acknowledgement window and record one of:
- `ACKED`
- `NO_STATE_ACK`
- `ACK_TIMEOUT`
- `TARGET_RESPAWNED`
- `BLOB_REPLACED`

For developer-owned server tests, expose explicit server state attributes/ack events so this can be authoritative.

### G. Result matrix
Persist at least:
`testId | runId | level | result | stopReason | calls | bytes | created | removed | targetGen | blobGen | notes`

The UI should still offer WORKS/PARTIAL/FAIL for quick marking, but the detailed row must exist underneath it.

### H. Profiler correlation
For server-side test harnesses, each test gets `debug.profilebegin("FTAP:<testId>")` labels. Record manual notes for:
- server Heartbeat
- network ping
- data ping
- ProcessPackets
- Allocate Bandwidth and Run Senders
- physics/assembly/ownership scopes

## Suggested UI pages

### RESULTS
- Mark last WORKS/PARTIAL/FAIL
- Print concise result matrix
- Export detailed run log
- Clear run log

### DEBUG2
- Full current context snapshot
- Blob compatibility matrix
- Lag/remote capability matrix
- Start/stop telemetry capture
- Print current rolling rates
- Print last stop reason
- Print lifecycle counters

### PROFILER
- Show recommended MicroProfiler hotkeys/workflow
- Start named sample window
- Baseline marker
- Stress marker
- Recovery marker

## Non-goals
- Do not add a `game.PlaceId` lock.
- Do not replace working V14 mechanisms with client-only approximations.
- Do not silently change intensity or cadence when DEBUG2 is enabled.

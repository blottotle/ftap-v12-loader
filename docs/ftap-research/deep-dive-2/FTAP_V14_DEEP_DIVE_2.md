# FTAP V14 Deep Dive 2: Server Stress, Blob Reliability, and Debugging Architecture

## Executive findings

This pass starts from the original FTAP V14 baseline rather than the later V14.1-V14.4 experiments. The baseline already contains several source-derived families: fixed-anchor `CreateGrabLine`, player fan-out `CreateGrabLine`, multiple `ExtendGrabLine` payload loops, a spawned-toy/shuriken physics family, and three Blobman kick/state loops. The important new work is therefore **not** to rename those existing controls or simply raise their counts. The useful 2026 additions fall into three buckets: better sustained-pressure patterns, new server/physics workload families that can be reproduced safely in an owner-controlled server harness, and substantially better instrumentation.

The strongest newly evidenced pattern is **cached-payload continuous pressure**. A public September 2, 2026 FTAP source builds a payload once, reuses it across sends, measures send duration, and adjusts the next delay to preserve cadence. That differs materially from V14's packet families, which rebuild their strings inside the loop and use fixed waits. For an owner-controlled test harness, the safe analogue is a bounded payload benchmark against a dedicated test RemoteEvent/RemoteFunction, with byte caps and an emergency stop. [1]

A second important family is **state/lifecycle amplification**, not raw call count. Recent code repeatedly combines ownership requests, spawned physics objects, sticky/weld state, grab-line create/destroy transitions, and Blobman grab/release/drop state. The useful engineering takeaway is that server cost can be driven by how much state each request invalidates or rebuilds, not only by how many requests are sent. Roblox's current documentation maps those effects to packet processing, replication senders, assembly rebuild, physics stepping, and distributed-physics ownership work. [2][3][4]

The most important debugging upgrade is to stop treating a successful Lua call as proof that a test worked. V14's current result tracker only records WORKS/PARTIAL/FAIL, while its preflight primarily checks whether remotes and instances exist. The next debugger should record **what was attempted, at what rate, against which object generation, what changed afterward, and which server subsystem became expensive**.

## Evidence quality and recency

The public-code evidence is strongest where several independent snapshots converge on the same object graph or lifecycle. The most recent corpus inspected here is `ndxzi/i-have-idea` at commit `937eabe4...`, dated September 2, 2026. That repository includes the current Vovange code, a packet manager, a cached-payload lag script, packet detection code, Blobman softlock/desync experiments, sticky-part utilities, and multiple leaked hubs. A second public FTAP source collection was updated July 24, 2026. [5][6]

Public FTAP scripts are not authoritative documentation of the game's server implementation. They show what clients attempt to invoke and which state combinations script authors believe matter. Exact server cost, validation, and replication behavior must therefore be measured in the developer-owned place. Roblox Creator Hub documentation is the authority for engine-level behavior: client-to-server RemoteEvents are throttled, network ownership controls who simulates assemblies, complex replicated DataModel changes are expensive, server-side tweens replicate changing properties every frame, and physics cost grows with awake assemblies and constraints. [2][3][4][7]

## What the original V14 already covers

The baseline should remain intact during research integration. Its current lag page already covers these source families:

- **L1 Fixed-anchor line burst:** repeated line creation against a stable world object.
- **L2 Player fan-out:** repeated line creation across character roots/torsos.
- **P1/P2/P3 payload families:** repeated `ExtendGrabLine` calls with different source-derived payload shapes and cadences.
- **PH1 spawned-toy physics:** shuriken/decoy bodies with rapidly changing angular/position state.
- **B1 TheWorst Blob**, **B2 Vovange Hard**, **B3 Vovange SpinGrab**.

The baseline therefore does not need another set of buttons that are only the same remote with a different label. New controls should represent a different **workload shape**, **state transition**, or **debugging question**.

## New source-backed family 1: cached payload and cadence control

The September 2 `plag.luau` source is materially different from V14's current packet loops. It prebuilds an exact-byte-size payload and caches it. The send loop records how long the call took and subtracts that elapsed time from the configured interval, preventing sender-side string creation or slow sends from accidentally lowering the intended cadence. If a payload fails, the script probes for a smaller accepted size. [1]

This gives three separate test dimensions that V14 currently conflates:

1. **Payload construction cost** — rebuild every iteration versus reuse a cached immutable payload.
2. **Wire/handler cost** — identical byte size and cadence, changing only payload schema/shape.
3. **Cadence stability** — fixed `task.wait()` versus elapsed-time-compensated scheduling.

For a developer-owned server harness, these should become separate tests rather than direct abuse of production game remotes. A safe implementation can use a dedicated `FTAPStressRemote`, hard-cap bytes per request, hard-cap requests per second, and record `ProcessPackets` plus server Heartbeat. This isolates the engine/network effect without turning the public exploit primitive into a reusable denial-of-service script.

### Recommended test IDs

- `NET-CACHE-1`: cached flat byte payload, fixed rate.
- `NET-CADENCE-1`: cached payload, elapsed-time-compensated rate.
- `NET-SHAPE-1`: same serialized byte budget, several schema shapes.
- `NET-RF-1`: compare bounded RemoteEvent versus RemoteFunction handler latency.
- `NET-URE-1`: compare reliable RemoteEvent with UnreliableRemoteEvent where semantics permit.

Do **not** interpret a higher request counter as higher server stress. Roblox documents an approximate limit of 500 client-to-server requests per second per client, shared among remotes of the same type, so an aggressive sender can enter throttling without proportionally increasing useful server work. [7]

## New source-backed family 2: packet observability rather than payload folklore

A July 2026 `packet lag detect.luau` implementation contains a useful debugging concept: it summarizes argument types, string bytes, repeated arguments, and likely sender context instead of simply printing that a remote fired. It also watches dynamically created Blobman animation remotes. [8]

The implementation itself is incomplete as a serious profiler — for example, it primarily counts string bytes and uses a global notification cooldown — but the design direction is correct. V14 DEBUG2 should generalize this into a per-test telemetry stream:

- remote name and class;
- run ID and test ID;
- timestamp and inter-call delta;
- argument count and `typeof()` vector;
- approximate serialized bytes;
- target instance class/name/path;
- current character generation and blob generation;
- success/error of the local invocation;
- server-state acknowledgement/proxy after the call;
- cumulative calls/sec and bytes/sec;
- object creation/removal counts during the same window.

The goal is to distinguish `REMOTE_EXISTS_BUT_REJECTED` from `REMOTE_ACCEPTED_NO_EXPENSIVE_WORK`, `REMOTE_THROTTLED`, `STALE_TARGET`, and `SERVER_STATE_CHANGED`.

## New source-backed family 3: ownership plus sticky/joint lifecycle

Recent FTAP utilities show a repeated pattern around spawned shuriken-like objects: spawn a server-replicated toy, request ownership, wait until an ownership marker/state appears, then invoke `StickyPartEvent` to attach it to another object. A July `BreakPart.luau` waits for a `PartOwner` state before moving to the sticky phase; an August TheWorst plugin expands the same basic mechanism across multiple plot targets. [9][10]

The significant research finding is not the outlier transform used by those public scripts. It is the **state sequence**:

`spawn hierarchy -> ownership transition -> acknowledgement -> sticky/joint creation -> assembly/topology invalidation -> cleanup`

That maps cleanly to several legitimate server stress tests in the developer-owned place:

- `OWN-FLIP`: alternate ownership of dedicated test assemblies between server and controlled test clients.
- `JOINT-CHURN`: create/destroy WeldConstraint or Motor6D links on a dedicated rig.
- `TOPOLOGY-CHURN`: merge/split assemblies so the ownership and assembly graph must be recalculated.
- `STICKY-RIG`: repeatedly attach/detach bounded test parts through the game's own server-side sticky system.
- `TOY-TREE`: spawn/destroy nested test models to measure replication of complex instance trees.

Roblox's current docs explicitly identify network ownership as distributed simulation work, complex instance-tree creation/removal as network intensive, and joint/constraint topology as part of physics/assembly work. [2][3][4]

## New engine family: sleep/wake churn

The Roblox sleep-system documentation exposes a server stress dimension that does not appear as a distinct V14 family. Sleeping assemblies are skipped by simulation; changing physics-related properties, applying impulses, changing constraints, collisions, or seating a player can wake them. As assembly/constraint counts rise, simulation cost rises. [11]

A dedicated test can therefore measure **wake-set pressure** without needing malformed remote traffic:

- prepare a fixed number of server-owned test assemblies;
- allow them to settle into sleeping/sleep-checking state;
- wake controlled batches using one mechanism at a time;
- measure `physicsStepped`, server Heartbeat, awake count, and recovery time;
- compare property-change wake, impulse wake, collision wake, and constraint wake.

This produces a highly useful server-side “continuous physics lag” test because the stress is sustained by keeping a working set awake rather than by creating unlimited objects.

Recommended IDs:

- `WAKE-PROP`: property-change wake cycles.
- `WAKE-IMPULSE`: bounded impulse wake cycles.
- `WAKE-CONSTRAINT`: constraint-change wake cycles.
- `WAKE-CONTACT`: collision/contact wake cycles.

## New engine family: assembly graph split/merge

Assemblies are groups of parts connected by rigid constraints or motors and are treated as rigid bodies. Network ownership is maintained at the assembly level, and assembly roots are used for replication/ownership consistency. [12]

A useful workload is therefore to repeatedly **change the assembly graph**, not merely move a fixed collection of parts. A bounded server test can alternate between many small assemblies and fewer large assemblies by enabling/disabling or recreating links. This can exercise:

- assembly reconstruction;
- root selection;
- ownership reevaluation;
- contact-island changes;
- replicated joint state.

This is analytically different from V14's current shuriken movement loop. It should get its own `ASSEMBLY-SPLITMERGE` control.

## New engine family: replicated property and tree churn

Roblox's performance guidance highlights two high-value server tests that public FTAP scripts often reach indirectly through toy systems: changing replicated properties frequently and creating/removing complex instance trees. Server-side TweenService is also specifically called out because its changing properties replicate to clients every frame. [3]

Recommended separate controls:

- `REPL-PROP`: change a bounded set of server-owned replicated properties at a known Hz.
- `REPL-ATTR`: churn replicated attributes independently from transforms.
- `REPL-TWEEN`: server-side tween a bounded object pool.
- `REPL-TREE`: clone/destroy nested model trees of controlled complexity.
- `REPL-FANOUT`: same total update volume distributed across many objects versus concentrated in a few.

The diagnostic discriminator is **data ping** and the `Allocate Bandwidth and Run Senders` MicroProfiler scope. A test that makes data ping diverge sharply from network ping is behaving differently from one that only lowers server Heartbeat. [3][13]

## New engine family: payload schema, not just byte count

V14 and many public scripts focus on string size. For a developer-owned test remote, the more general question is: **how much work does a given semantic payload cause after deserialization?** Two messages with similar wire size can have very different handler cost if one causes deep table traversal, object lookups, validation, allocation, or replicated changes.

A controlled `NET-SHAPE` matrix should test several benign schemas at the same byte budget:

- flat string;
- flat numeric array;
- shallow dictionary;
- nested dictionary with bounded depth;
- list of small records.

Record both `ProcessPackets` and handler time with `debug.profilebegin()` labels. The point is to profile the developer-owned handler, not to discover malformed payloads for a production remote. Roblox explicitly recommends keeping remote payloads minimal and validating type, structure, values, permissions, and context. [3][14]

## Blob deep dive: detector-side compatibility

The original V14 Blob kick context is heavily centered on the RightDetector/RightWeld path. Recent public code shows that this assumption is too narrow. `blobman softlock.luau` dynamically constructs a detector side name and contains separate Grab, Drop, and Release modes. It uses the LeftDetector path in its active loop. [15]

This suggests a **compatibility matrix**, not a stronger blind loop:

| Dimension | Values to detect |
|---|---|
| Detector | Left / Right |
| Weld | LeftWeld / RightWeld |
| State remote | CreatureGrab / CreatureDrop / CreatureRelease |
| Drop signature | observed one-argument form versus game-specific alternatives |
| Release availability | present / absent |
| Mounted blob generation | current instance ID |
| Target generation | current character instance ID |

A robust V14 debugger should print this matrix before any Blob test and record which path actually changed state.

## Blob deep dive: respawn and hook lifecycle

`Blobman Desync.luau` demonstrates a useful reliability pattern even though its gameplay behavior is not something to copy into a production test: it re-hooks the Humanoid after `CharacterAdded`, and its behavior is triggered by `SeatPart` changes instead of assuming the same Humanoid lives forever. [16]

This reinforces the earlier finding that V14 should track **generation boundaries** explicitly:

- increment `selfCharacterGen` on local `CharacterAdded`;
- increment `targetCharacterGen` when the selected target's Character changes;
- increment `blobGen` when the mounted Blobman instance changes;
- invalidate all cached roots/detectors/welds/remotes tied to an old generation;
- reacquire at phase boundaries;
- record `REACQUIRE_REASON` in DEBUG2.

A continuous Blob test should not silently keep stale references after a reset. It should either reacquire and re-enter its acquisition phase or stop with a precise failure reason.

## Blob deep dive: state acknowledgement

The July `BreakPart` utility waits for an ownership-related state before progressing. That is more robust than treating a `pcall(FireServer)` return as acknowledgement. [9]

For Blob testing, every critical transition should have an observable success proxy in the developer-owned place. Examples include:

- detector weld changed;
- target's server-known hold state changed;
- Blobman's authoritative state attribute changed;
- ownership mode changed on the dedicated test assembly;
- grab-line instance/state appeared or disappeared;
- seat occupant changed.

DEBUG2 should record `REQUESTED`, `ACKED`, `TIMED_OUT`, and `REJECTED/NO_CHANGE`. This one change would make field reports much more useful than “works” or “doesn't work.”

## Blob deep dive: pool discovery and replacement handling

Large 2026 FTAP scripts increasingly scan all `*SpawnedInToys` folders, build a pool of live Blobman instances, track Left/Right detector state, and refresh that pool when toy folders change. This pattern is more resilient to toy destruction/replacement than caching one Blob forever. [17]

For V14, the safe reliability lesson is:

- discover only the currently mounted/owned or dedicated test Blob relevant to the current run;
- watch its ancestry and critical children;
- if it is replaced, rebuild context and increment `blobGen`;
- do not keep detector/weld references across replacement;
- log the exact old/new instance path.

## Debug architecture: V14 DEBUG2

### 1. Run identity

Every test start receives a monotonically increasing `runId`, a `testId`, and a configuration snapshot. Example fields:

`runId, testId, startClock, mode, intensity, targetName, targetCharacterGen, blobGen`

This eliminates ambiguity when multiple loops are toggled during one session.

### 2. Invocation telemetry

Wrap V14's shared fire/invoke helpers with a diagnostic layer that records metadata without changing arguments:

`remote, remoteClass, argTypes, estimatedBytes, localSuccess, localError, deltaSinceLastCall, callsThisSecond, bytesThisSecond`

The wrapper should be opt-in so ordinary V14 behavior stays untouched when DEBUG2 is disabled.

### 3. Lifecycle counters

During a run, watch only the relevant containers and count:

- lines created/removed;
- Beams/constraints/welds created/removed;
- spawned toys created/removed;
- Blobman replacement;
- character replacement;
- target root replacement.

Use narrow watchers rather than recursively connecting to every Workspace descendant. The public packet detector recursively attaches watchers to the entire Workspace tree, which itself can become diagnostic overhead. [8]

### 4. Failure taxonomy

Replace generic FAIL with explicit codes:

- `MISSING_REMOTE`
- `MISSING_BLOB`
- `NOT_SEATED`
- `MISSING_DETECTOR`
- `MISSING_WELD`
- `MISSING_GRAB`
- `MISSING_DROP`
- `MISSING_RELEASE`
- `STALE_SELF_CHARACTER`
- `STALE_TARGET_CHARACTER`
- `STALE_BLOB`
- `LOCAL_CALL_ERROR`
- `REMOTE_THROTTLE_SUSPECTED`
- `NO_STATE_ACK`
- `STATE_ACK_TIMEOUT`
- `TARGET_RESPAWNED`
- `BLOB_REPLACED`
- `CLEANUP_INCOMPLETE`

### 5. Baseline / stress / recovery phases

Each bounded server stress test should have three measurement phases:

1. **Baseline:** capture a short idle sample.
2. **Stress:** run one isolated mechanism at the selected level.
3. **Recovery:** stop, clean up, and measure how quickly metrics return to baseline.

This distinguishes a temporary frame cost from a backlog that continues after the generator stops.

### 6. Engine-side metrics

For each run, capture or manually annotate:

- server Heartbeat / server FPS;
- network ping;
- data ping;
- `ProcessPackets`;
- `Allocate Bandwidth and Run Senders`;
- physics/assembly scopes;
- distributed physics ownership scope;
- peak replicated instance count for the test pool;
- cleanup time.

Roblox's MicroProfiler network capture can save detailed sent/received network data in desktop/Studio frame dumps, which is far more useful than guessing from client FPS. [13]

### 7. MicroProfiler labels

In developer-owned server test code, wrap each stressor with `debug.profilebegin("FTAP:<testId>")` / `debug.profileend()`. Roblox specifically recommends these labels for attributing expensive RunService/server code. [3]

## Ranking of next server-side test candidates

| Rank | ID | Mechanism | Why it is new/useful | Primary signal |
|---:|---|---|---|---|
| 1 | `OWN-TOPOLOGY` | ownership + assembly split/merge | exercises ownership recalculation and assembly rebuild together | ownership + assemble scopes |
| 2 | `WAKE-CONSTRAINT` | keep many assemblies awake through constraint changes | sustained physics load without infinite spawning | physicsStepped / awake count |
| 3 | `REPL-TREE` | clone/destroy bounded nested model trees | direct replication hierarchy cost | data ping / senders |
| 4 | `NET-CACHE` | cached payload on dedicated test remote | isolates network/handler cost from sender allocation | ProcessPackets |
| 5 | `NET-SHAPE` | same byte budget, different safe schemas | reveals handler/deserialization sensitivity | ProcessPackets + handler label |
| 6 | `JOINT-CHURN` | create/destroy bounded joint graph | distinct assembly construction cost | Simulation/assemble |
| 7 | `REPL-TWEEN` | server tween bounded pool | per-frame replicated property pressure | data ping / senders |
| 8 | `WAKE-CONTACT` | controlled contact-island wake cycles | different from transform-only physics | physicsStepped |
| 9 | `NPC-STATE` | server dummy ragdoll/state/joint churn | exercises Humanoid + joint state | server Heartbeat + assemble |
| 10 | `REPL-ATTR` | replicated attribute churn | cheap to implement, useful network baseline | data ping / ProcessPackets |

## What is mostly duplicate and not worth another button

The 2026 source corpus contains many scripts that differ mainly in UI, payload text, loop count, or a renamed feature. These should not become separate V14 controls unless a test proves a materially different server profile.

Low-value duplicates include:

- another fixed SpawnLocation `CreateGrabLine` loop with only a different coordinate;
- another `ExtendGrabLine` text/emoji string with the same size and cadence;
- another line fan-out loop that only changes which character part is selected;
- another Blob loop that uses the same detector, same transition order, and same reacquisition policy;
- “stronger” loops whose only difference is removing all waits and immediately hitting RemoteEvent throttling.

The correct rule is **one control per distinct server workload**, not one control per leaked script name.

## Debug-driven tuning protocol

When a new test is added, use a small matrix rather than jumping directly to a maximum:

- Level A: confirm mechanism and cleanup.
- Level B: enough load for the primary profiler scope to move clearly.
- Level C: aggressive but recoverable private-server load.

For each level, record the same metrics and stop automatically if server Heartbeat falls below the chosen safety floor, data ping remains backlogged after stop, or cleanup cannot restore the test pool. This is a better way to discover “the actual one” than comparing client-visible lag subjectively.

## Recommended V14 integration order

1. **DEBUG2 first.** Add generation tracking, invocation telemetry, lifecycle counters, ACK/no-ACK classification, and profiler run IDs.
2. **Keep original V14 lag and Blob controls unchanged.** Instrument them; do not rewrite them into local-only substitutes.
3. **Add Blob compatibility diagnostics.** Left/Right detector, Grab/Drop/Release availability, instance generations, and state ACKs.
4. **Add owner-controlled server stress matrix.** Start with `OWN-TOPOLOGY`, `WAKE-CONSTRAINT`, `REPL-TREE`, `NET-CACHE`, and `JOINT-CHURN`.
5. **Compare profiles, not labels.** Merge/delete controls that produce the same server signature.
6. **Only then tune intensity.** Increase bounded test levels after confirming which subsystem is actually responsible.

## Conclusions

The second deep dive found more useful engineering material than another round of “increase the packet count.” The most important new public-source idea is cached, cadence-controlled payload pressure; the most important Blob reliability idea is detector/release compatibility plus generation-aware reacquisition; and the most important new server-physics idea is deliberate wake/assembly-topology churn.

The highest-value next development step is DEBUG2. Without better telemetry, it is impossible to know whether a test failed because a remote changed, a target respawned, the Blob was replaced, the call was throttled, the server rejected the state transition, or the mechanism simply did not create meaningful server work. Once those failure classes are visible, the new stress matrix can be tuned empirically and redundant script families can be removed.

## Sources

1. ndxzi/i-have-idea, `plag.luau`, commit 937eabe4, modified September 2, 2026. https://github.com/ndxzi/i-have-idea/blob/937eabe4d4684455e19d038a814385eced349df1/6961824067/plag.luau
2. Roblox Creator Hub, “Network ownership.” https://create.roblox.com/docs/physics/network-ownership
3. Roblox Creator Hub, “Improve performance.” https://create.roblox.com/docs/performance-optimization/improve
4. Roblox Creator Hub, “Physics.” https://create.roblox.com/docs/physics
5. ndxzi/i-have-idea, commit 937eabe4, September 2, 2026. https://github.com/ndxzi/i-have-idea/commit/937eabe4d4684455e19d038a814385eced349df1
6. sladkoeshkaogg-svg/Scripts-FTAP-Free-MAIN-, commit cf512854, July 24, 2026. https://github.com/sladkoeshkaogg-svg/Scripts-FTAP-Free-MAIN-/commit/cf5128548c4be2820d94b51dba476ec197ea6991
7. Roblox Creator Hub, `RemoteEvent` throttling reference. https://create.roblox.com/docs/reference/engine/classes/RemoteEvent/OnServerEvent
8. ndxzi/i-have-idea, `packet lag detect.luau`, modified July 5, 2026. https://github.com/ndxzi/i-have-idea/blob/937eabe4d4684455e19d038a814385eced349df1/6961824067/packet%20lag%20detect.luau
9. ndxzi/i-have-idea, `BreakPart.luau`, modified July 8, 2026. https://github.com/ndxzi/i-have-idea/blob/937eabe4d4684455e19d038a814385eced349df1/6961824067/BreakPart.luau
10. ndxzi/i-have-idea, `TheWorst Plugins/BreakAllPlots.luau`, modified August 11, 2026. https://github.com/ndxzi/i-have-idea/blob/937eabe4d4684455e19d038a814385eced349df1/6961824067/TheWorst%20Plugins/BreakAllPlots.luau
11. Roblox Creator Hub, “Sleep system.” https://create.roblox.com/docs/physics/sleep-system
12. Roblox Creator Hub, “Assemblies.” https://create.roblox.com/docs/physics/assemblies
13. Roblox Creator Hub, “MicroProfiler network usage.” https://create.roblox.com/docs/performance-optimization/microprofiler/network
14. Roblox Creator Hub, “Securing the client-server boundary.” https://create.roblox.com/docs/scripting/security/client-server-boundary
15. ndxzi/i-have-idea, `blobman softlock.luau`, modified July 5, 2026. https://github.com/ndxzi/i-have-idea/blob/937eabe4d4684455e19d038a814385eced349df1/6961824067/blobman%20softlock.luau
16. ndxzi/i-have-idea, `Blobman Desync.luau`, modified July 5, 2026. https://github.com/ndxzi/i-have-idea/blob/937eabe4d4684455e19d038a814385eced349df1/6961824067/Blobman%20Desync.luau
17. ndxzi/i-have-idea, `abus.luau`, current September 2026 corpus. https://github.com/ndxzi/i-have-idea/blob/937eabe4d4684455e19d038a814385eced349df1/6961824067/abus.luau

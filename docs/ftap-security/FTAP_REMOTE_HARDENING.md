# FTAP remote hardening notes (V14R5)

This package deliberately does **not** include the previous FTAPFreezeLab server-stall/freeze script or its Studio installer.
The client-side audit is passive: it enumerates known FTAP-relevant remote families but does not fire them.

## Why this matters

Any RemoteEvent/RemoteFunction visible to a client is callable with attacker-controlled arguments. Security has to live in the real server handler. A second `OnServerEvent` connection cannot cancel another connection that already receives the same request.

## Per-family checks

- `CreateGrabLine`: require an expected `BasePart`; ensure it is a server-approved target; verify distance and current grab state; require a finite, plausible `CFrame`; rate-limit per player.
- `DestroyGrabLine`: only remove a line/relationship that the server records as belonging to that player's current action.
- `ExtendGrabLine`: enforce the exact legitimate argument type/shape. Reject strings/tables that are not part of the real protocol, cap any legitimate string/table size, and rate-limit sustained updates.
- `SetNetworkOwner`: never accept an arbitrary client-selected assembly. The server should decide which assembly can change owner and to whom. Revoke ownership when the interaction ends.
- `CreateGrabEvent`: validate target eligibility, distance, alive/state checks, cooldown and server-owned permissions.
- `StickyPartEvent`: validate both instances, their ancestry/ownership, proximity and legal interaction state.
- `SpawnToyRemoteFunction`: use a server allowlist, server-side cost/cooldown, spawn-distance bounds and per-player object quotas. Never accept arbitrary asset/module identifiers from clients.
- `DestroyToy`: only destroy server-recorded player-owned/eligible objects.
- `RagdollRemote`, `Struggle`, `StopAllVelocity`: keep effects scoped to server-authorized characters/assemblies; validate state and rate.

## Universal checks

1. Validate type and structure before doing expensive work.
2. Reject NaN/infinite numeric components and absurd vector/CFrame magnitudes.
3. Reject arbitrary `Instance` references unless they are descendants of an expected server-known container and belong to the requesting interaction/player.
4. Rate-limit every client-triggered server action using a token bucket or equivalent.
5. Bound string/table sizes before parsing/copying/broadcasting them.
6. Avoid blindly relaying client data with `FireAllClients`.
7. Keep authoritative state in `ServerScriptService`/server-only modules, not replicated client code.
8. Log rejected requests with a short rolling counter; do not do expensive logging on every spam packet.

## Interpreting V14R5's audit

`EXPOSED` means the remote exists and therefore needs a correct server-side handler. It does **not** mean the game is vulnerable. Use your own Studio/private-server tests and the existing DEBUG2 `WORKS / PARTIAL / FAIL` result tracking to record whether a candidate FTAP behavior is actually blocked.

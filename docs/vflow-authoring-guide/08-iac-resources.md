# VWFD YAML — IaC Resource YAML (`vflowctl apply -f`)


---

## Scope

This is a **separate YAML surface** from the workflow YAML covered in 01-07. IaC resources are declarative descriptions of infrastructure primitives — tenants, fleet hosts, tiers, packs, snapshots — that the control plane reconciles.


Workflow YAML (01-07) lives *inside* Packs; IaC YAML references Packs by identity.

---

## Kubernetes-inspired shell — every resource

All IaC resources share this outer shape (K8s-style):

```yaml
apiVersion: vflow.cloud/v1
kind: <Tenant|FleetHost|Tier|Pack|Snapshot>
metadata:
  name: <string, required>
  namespace: <string, tenant-scoped kinds only>
  labels:
    <key>: <value>
  annotations:
    <key>: <value>
spec:
  # kind-specific — see per-kind sections below
```

### `metadata` fields (server-authoritative vs client-authored)


| Field | Who sets | Notes |
|---|---|---|
| `name` | client | Unique per `(kind, namespace)`. |
| `namespace` | client | Required for tenant-scoped kinds (`Tenant`, `Workflow`). Omit for cluster-scoped (`FleetHost`, `Tier`, `Pack`). |
| `labels` | client | Selectable map (`{ tier: premium, region: jkt }`). |
| `annotations` | client | Free-form, not selectable. One reserved: `vflow.cloud/freeze-reconcile: "true"` pauses reconciliation for this resource. |
| `uid` | server | UUID, assigned at create, immutable. |
| `generation` | server | Monotonic; bumps on each spec write. |
| `observedGeneration` | server (controller) | Last generation controller reconciled. `generation > observedGeneration` ⇒ work owed. |
| `createdAt` / `updatedAt` | server | RFC3339. |


### Tenant-scoped vs cluster-scoped kinds

| Kind | Scope | `namespace` in YAML |
|---|---|---|
| `Tenant` | Tenant-scoped | Required. Namespace == tenant identity by convention. |
| `Workflow` | Tenant-scoped | Required. |
| `FleetHost` | Cluster-scoped | Omit. |
| `Tier` | Cluster-scoped | Omit. |
| `Pack` | Cluster-scoped | Omit. |
| `Snapshot` | Tenant-scoped | Required. |

Apply REST path maps `namespace: None` → `/resources/<kind>/_/<name>` (underscore = cluster-scoped).

---

## `kind: Tenant`

A tenant is one declarative container/VM/runtime instance. TenantController reconciles Tenant resources into `Orchestrator::provision` / `destroy` calls (Firecracker, Proxmox-LXC, mock).


### Spec fields

```yaml
apiVersion: vflow.cloud/v1
kind: Tenant
metadata:
  namespace: acme               # tenant identity (namespace == tenant by convention)
  labels:
    tier: premium
    region: jkt
spec:
  tier_ref: premium             # REQUIRED — string matching a registered Tier resource
  bundle:
    digest: "sha256:abc123..."  # REQUIRED — content-addressable bundle identity
    path: /var/lib/vflow/bundles/abc123.tar.gz
  resources:
    cpu_cores: 4                # REQUIRED
    rss_mb: 2048                # REQUIRED
    disk_mb: 10240              # REQUIRED
  network:
    exposed_ports: [8080, 8443] # REQUIRED — NAT-style 1:1 port forwarding
```

| Field | Type | Required | Semantics |
|---|---|---|---|
| `bundle.digest` | string | yes | Content-addressable sha256 of the workflow bundle tar.gz. Orchestrator verifies before deploy. |
| `bundle.path` | string (path) | yes | Host-side path to the bundle. Usually SeaweedFS-backed or local cache. |
| `resources.cpu_cores` | u32 | yes | Hard CPU ceiling. |
| `resources.rss_mb` | u64 | yes | Hard RAM ceiling. |
| `resources.disk_mb` | u64 | yes | Hard disk ceiling. |
| `network.hostname` | string | yes | Must be DNS-safe (`[a-z0-9-]`). |
| `network.exposed_ports` | [u16] | yes | 1:1 forwarding — port N inside = port N on host. Caller responsible for collision avoidance. |

### Status (controller-written, operators read-only)

```yaml
status:
  phase: Running                              # Pending|Provisioning|Running|Failed|Destroying
  state: running                              # fine-grained state machine
  backend_id: fc-pid-4721                     # orchestrator-assigned
  target: firecracker-local                   # which backend owns it
  last_provisioned_tier: premium              # for tier-upgrade detection
  last_error: ""
  last_transition_at: "2026-04-24T14:00:00Z"
```

| Field | Type | Semantics |
|---|---|---|
| `phase` | string | `Pending` \| `Provisioning` \| `Running` \| `Failed` \| `Destroying`. Aggregated from `state` for display. |
| `state` | string (TenantProvisionState) | `pending` \| `provisioning` \| `running` \| `failed` \| `destroying`. Persisted so a control-plane restart resumes mid-provision. |
| `backend_id` | string? | Orchestrator-assigned identity (Firecracker PID, Proxmox VMID, etc.). Required for status/destroy routing. |
| `target` | string? | Orchestrator backend that owns this tenant. |
| `last_error` | string | Populated when `state == failed`. |
| `last_transition_at` | string | RFC3339 of last state change. |

### Lifecycle

- **Create.** POST new tenant → controller drives `Pending → Provisioning → Running`.
- **Freeze.** Add annotation `vflow.cloud/freeze-reconcile: "true"` → controller skips this resource until unfrozen. Use during manual ops.

### Runtime example


---

## `kind: FleetHost`

A FleetHost registers a physical/virtual host with the scheduler. FleetHostController reconciles host capacity + reachability into the scheduler's in-memory registry.


### Spec fields

```yaml
apiVersion: vflow.cloud/v1
kind: FleetHost
metadata:
  name: kvm1-lab                        # no namespace — cluster-scoped
  labels:
    region: jkt
    rack: a3
spec:
  target: firecracker-ssh               # REQUIRED — orchestrator backend
  host_id: "root@kvm1.lab.example.com"  # REQUIRED — scheduler HostId
  capacity:
    cpu_cores: 64
    mem_mib: 131072
    max_instances: 128
  allowed_tiers:
    - premium
    - regulated
  orchestrator_config:
    # backend-specific opaque blob — interpreted by the iac-svc boot wiring
    ssh_key_path: /etc/vflow/keys/kvm1.key
    jailer_base_path: /srv/firecracker
```

| Field | Type | Required | Semantics |
|---|---|---|---|
| `target` | string | yes | Matches `Orchestrator::target()`: `firecracker-local` \| `firecracker-ssh` \| `proxmox-lxc` \| `mock`. |
| `host_id` | string | yes | Logical host identifier. For remote: SSH target (`root@host`). For local: friendly label (`local`, `pve1`). |
| `capacity.cpu_cores` | u32 | yes | Enforced at provision() via fleet registry. |
| `capacity.mem_mib` | u64 | yes | Enforced. |
| `capacity.max_instances` | u32 | yes | Ceiling on co-resident instances. |
| `allowed_tiers` | [string] | no (default `[]`) | Tier names this host is cleared to serve. Empty = any tier (dev default). |
| `orchestrator_config` | object | no | Opaque backend config. Passed verbatim to the Orchestrator impl by iac-svc boot wiring. |

### Status

```yaml
status:
  phase: Ready                 # Unknown|Registered|Ready|Unreachable
  registered: true
  reachable: true
  last_probed_at: "2026-04-24T14:05:00Z"
  last_probe_error: ""
  registered_at: "2026-04-24T12:00:00Z"
  conditions:
    - type: HostReachable
      status: "True"
      reason: ProbeOk
      message: ""
      last_transition_at: "2026-04-24T14:05:00Z"
```

| Field | Type | Semantics |
|---|---|---|
| `phase` | string | `Unknown` (initial/frozen) \| `Registered` (capacity synced) \| `Ready` (registered + probe green) \| `Unreachable` (probe red). |
| `registered` | bool | Capacity is in the scheduler's in-memory registry. |
| `reachable` | bool | Last reachability probe succeeded. |
| `last_probed_at` / `last_probe_error` / `registered_at` | string | Probe + registration audit trail. |


```yaml
conditions:
  - type: HostReachable
    status: "True"          # "True" | "False" | "Unknown"
    reason: ProbeOk
    message: ""
    last_transition_at: "2026-04-24T14:05:00Z"
```

---

## `kind: Tier`


The **spec fields are identical to the `tier.yaml` TierSpec schema** documented in 06-pack-tier.md §tier — just wrapped in the K8s shell:

```yaml
apiVersion: vflow.cloud/v1
kind: Tier
metadata:
  name: standard
  labels:
    generation: v1
spec:
  version: 1
  kind_marker: TierSpec       # optional — preserved for backwards compat with tier.yaml
  capabilities:
    sidecar: { roles: [compute, connector] }
    wasm:    { roles: [compute] }
    multi_pack: true
    hot_pack_install: true
  connectors:
    database: { allow: [sqlite, postgres, yugabyte, redis, mongo] }
    mq:       { allow: [nats, nats_js, kafka, mqtt] }
    protocol: { allow: [http, grpc, websocket, sftp] }
    storage:  { allow: [s3, gcs, azure] }
  triggers:
    allow: [webhook, cron, nats, nats_js, nats_kv, kafka, grpc]
  sidecars:
    allow:
      - name: fraud_scorer
        roles: [compute]
        artifact:
          kind: binary
          digest: "sha256:..."
          size_mb: 45
          command: "python -m fraud_service"
        resources:
          rss_mb: 256
          cpu_millicores: 500
  wasm:
    allow:
      - { name: currency_convert, memory_pages: 256 }
  limits:
    max_payload_size_mb: 10
    max_concurrent_activities: 100
  orchestrators:
    allow: [workflow_runtime]
```

See 06-pack-tier.md for exhaustive field reference. The IaC wrapper adds apply-time conveniences (labels, annotations, generation tracking) without changing the TierSpec shape.

---

## `kind: Pack`



```yaml
apiVersion: vflow.cloud/v1
kind: Pack
metadata:
  name: examples-hello-db
  labels:
    author: platform
spec:
  pack_id: examples/hello-db        # matches pack.yaml `pack.id`
  version: 0.1.0                     # matches pack.yaml `pack.version`
  bundle:
    digest: "sha256:..."             # content-addressable
    path: /var/lib/vflow/packs/hello-db-0.1.0.tar.gz
  tier_ref: standard                 # which tier this pack requires/targets
  # Extracted from pack.yaml at install time for fast lookup:
  connections_summary:
  workflows_summary:
    - { path: bootstrap.yaml }
    - { path: write_hello.yaml }
```

Pack resources declare that a pack is installed and available to the control plane.

---

## `kind: Snapshot`

A Snapshot captures a tenant runtime state for later restore.


```yaml
apiVersion: vflow.cloud/v1
kind: Snapshot
metadata:
  namespace: acme                # tenant-scoped
  labels:
    reason: nightly-backup
spec:
  target: firecracker            # orchestrator backend (must match tenant's current target)
  snapshot_id: fc-42-20260424-1400   # assigned by backend, preserved for restore
  snapshot_path: /var/lib/vflow/snapshots/fc-42-20260424-1400.meta
  mem_file_path: /var/lib/vflow/snapshots/fc-42-20260424-1400.mem
  created_at: "2026-04-24T14:00:00Z"
```


---

## Multi-doc apply manifest (cluster.yaml pattern)

`vflowctl apply -f cluster.yaml` accepts multi-doc YAML with `---` separators. Typical cluster bootstrap:

```yaml
# Hosts first — no dependencies.
apiVersion: vflow.cloud/v1
kind: FleetHost
metadata: { name: pve1 }
spec:
  target: proxmox-lxc
  host_id: pve1
  capacity: { cpu_cores: 32, mem_mib: 65536, max_instances: 64 }
  allowed_tiers: [starter, standard]

---
apiVersion: vflow.cloud/v1
kind: FleetHost
metadata: { name: kvm1 }
spec:
  target: firecracker-ssh
  host_id: "root@kvm1.lab"
  capacity: { cpu_cores: 64, mem_mib: 131072, max_instances: 128 }
  allowed_tiers: [premium, regulated]

---
# Tier references don't resolve until a Tier resource exists:
apiVersion: vflow.cloud/v1
kind: Tier
metadata: { name: premium }
spec:
  version: 1
  capabilities:
    sidecar: { roles: [compute, connector] }
    multi_pack: true
  connectors: { database: { allow: [postgres, yugabyte] } }
  triggers: { allow: [webhook, grpc, nats_js] }

---
# Tenant last — depends on a Tier being known.
apiVersion: vflow.cloud/v1
kind: Tenant
metadata:
  namespace: acme
  labels: { tier: premium }
spec:
  tier_ref: premium
  bundle: { digest: "sha256:abc", path: /var/lib/vflow/bundles/abc.tar.gz }
  resources: { cpu_cores: 4, rss_mb: 2048, disk_mb: 10240 }
```

Apply:
```
vflowctl apply -f cluster.yaml
vflowctl apply -f cluster.yaml --wait --timeout=60
```

Dry-run:
```
vflowctl apply -f cluster.yaml --dry-run
vflowctl plan -f cluster.yaml
vflowctl diff -f cluster.yaml
```

- Missing `apiVersion` / `kind` / `metadata.name` / `spec` → line-numbered error.
- `kind` not in `KNOWN_KINDS = [Tenant, FleetHost, Tier, Pack, Snapshot]` → explicit error with supported list.

---

## Authoring rules of thumb

1. **Cluster-scoped first, tenant-scoped last.** Apply `FleetHost` → `Tier` → `Pack` → `Tenant` → `Snapshot`. Tenant fails fast if its `tier_ref` is absent.
2. **Bundle digest is mandatory.** Don't author a Tenant without `spec.bundle.digest`; the orchestrator rejects on mismatch at deploy.
3. **Annotations for operator overrides.** `vflow.cloud/freeze-reconcile: "true"` to pause; `vflow.cloud/deletion-requested-at: "<rfc3339>"` to finalize-delete.
4. **Labels for selection.** Use `tier`, `region`, `rack`, `role` — `vflowctl get <kind> -l tier=premium` relies on these.
5. **Never write `status`.** Server rejects on POST path; any status block in authored YAML is ignored on apply.
6. **Keep YAML small per-tenant.** Cluster.yaml-style manifests are fine for bootstrap, but for everyday ops one-resource-per-file apply keeps diff clean.

---

## Related

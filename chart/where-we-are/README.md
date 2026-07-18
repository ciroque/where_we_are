# WhereWeAre Helm Chart

Deploys the WhereWeAre Phoenix LiveView app on Kubernetes.

Patterns match the working ExerTrax chart conventions:
digest-pinned GHCR images, Traefik ingress, cert-manager Certificate, and
secrets wired via `valueFrom`.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Traefik ingress controller (or change `ingress.className`)
- cert-manager with a `ClusterIssuer` named `letsencrypt-dns` (or change `certificate.*`)
- Image pull secret `ghcr-package-read` in the target namespace (or override `imagePullSecrets`)

## Installing the Chart

```bash
# Optional: load shared secrets from your devenv files
# source ~/.config/devenvs/secret-key-bases.env

export DIGEST=<image digest from GHCR, e.g. sha256:...>
export HOST=where-we-are.example.com   # your real DNS name
export WHERE_WE_ARE_SECRET_KEY_BASE=<output from `mix phx.gen.secret`; keep stable>

helm upgrade --install where-we-are ./chart/where-we-are \
  --set app.secretKeyBase="$WHERE_WE_ARE_SECRET_KEY_BASE" \
  --set app.phxHost="$HOST" \
  --set app.caldav.username="you@icloud.com" \
  --set app.caldav.password="$CALDAV_APP_PASSWORD" \
  --set app.caldav.calendars="Family,Home" \
  --set image.digest="$DIGEST" \
  --set ingress.hosts[0].host="$HOST" \
  --set ingress.tls[0].hosts[0]="$HOST" \
  --set certificate.dnsNames[0]="$HOST" \
  -n where-we-are \
  --create-namespace
```

Generate a stable secret once:

```bash
mix phx.gen.secret
# export WHERE_WE_ARE_SECRET_KEY_BASE='...'
```

Find a digest after CI publishes:

```bash
crane digest ghcr.io/ciroque/where_we_are:latest
# or from the Actions run / cosign output
```

## Status

```bash
alias kctl-wwa='kubectl -n where-we-are'

kctl-wwa get pods,svc,ingress,certificate
kctl-wwa describe pods -l app.kubernetes.io/name=where-we-are
kctl-wwa logs -l app.kubernetes.io/name=where-we-are -f
kctl-wwa rollout status deployment/where-we-are
```

## Uninstalling

```bash
helm delete where-we-are -n where-we-are
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Replicas (keep `1` — in-memory calendar cache) | `1` |
| `image.repository` | Image repository | `ghcr.io/ciroque/where_we_are` |
| `image.digest` | Image digest (`sha256:...`) | `""` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `imagePullSecrets` | Pull secrets | `[{name: ghcr-package-read}]` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port (Ingress backend) | `80` |
| `service.targetPort` | Container port | `4000` |
| `ingress.enabled` | Enable Ingress | `true` |
| `ingress.className` | Ingress class | `traefik` |
| `certificate.enabled` | cert-manager Certificate | `true` |
| `certificate.issuerName` | ClusterIssuer name | `letsencrypt-dns` |
| `app.secretKeyBase` | Phoenix `SECRET_KEY_BASE` | `""` **required** |
| `app.phxHost` | Public host (`PHX_HOST`) | `where-we-are.local` |
| `app.caldav.username` | CalDAV username | `""` |
| `app.caldav.password` | CalDAV password / app-specific password | `""` |
| `app.caldav.url` | CalDAV base URL | iCloud |
| `app.caldav.calendars` | Comma-separated display names | `""` (all) |
| `app.caldav.eventWindowMonths` | Fetch window | `6` |
| `app.caldav.expandRecurrences` | Expand RRULEs | `true` |
| `app.caldav.pollMinutes` | Sync interval | `10` |
| `app.environment` | `MIX_ENV` | `prod` |

## Notes

- **Single replica**: sync state is per-pod memory.
- **iCloud**: use an [app-specific password](https://support.apple.com/en-us/HT204397).
- **LiveView**: `app.phxHost` must match the Ingress hostname.

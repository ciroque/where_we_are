# WhereWeAre Helm Chart

Deploys the WhereWeAre Phoenix LiveView app on Kubernetes.

Patterns match the working ExerTrax chart conventions:
digest-pinned GHCR images, Traefik ingress, cert-manager Certificate, and
secrets wired via `valueFrom`.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Image pull secret `ghcr-package-read` in the target namespace (or override `imagePullSecrets`)

For public HTTPS (optional; off by default):

- Traefik ingress controller (or change `ingress.className`)
- cert-manager with a `ClusterIssuer` named `letsencrypt-dns` (or change `certificate.*`)

## Installing the Chart

Minimal install (ClusterIP only; use `kubectl port-forward` from NOTES):

```bash
export DIGEST=<image digest from GHCR, e.g. sha256:...>
export CALDAV_USERNAME=...   # CalDAV username
export CALDAV_PASSWORD=...   # CalDAV password
# Generate once: mix phx.gen.secret
export WHERE_WE_ARE_SECRET_KEY_BASE="..."  # keep stable across upgrades

helm upgrade --install where-we-are ./chart/where-we-are \
  --set app.secretKeyBase="$WHERE_WE_ARE_SECRET_KEY_BASE" \
  --set app.caldav.username="$CALDAV_USERNAME" \
  --set app.caldav.password="$CALDAV_PASSWORD" \
  --set 'app.caldav.calendars=Family\,Home' \
  --set image.digest="$DIGEST" \
  -n where-we-are \
  --create-namespace
```

Public HTTPS with Traefik + cert-manager:

```bash
# Optional: load shared secrets from your devenv files
# source ~/.config/devenvs/secret-key-bases.env

export DIGEST=<image digest from GHCR, e.g. sha256:...>
export HOST=where-we-are.example.com   # your real DNS name
export CALDAV_USERNAME=...   # CalDAV app-specific username
export CALDAV_PASSWORD=...   # CalDAV app-specific password
# Generate once: mix phx.gen.secret
export WHERE_WE_ARE_SECRET_KEY_BASE="..."  # keep stable across upgrades

helm upgrade --install where-we-are ./chart/where-we-are \
  --set app.secretKeyBase="$WHERE_WE_ARE_SECRET_KEY_BASE" \
  --set app.phxHost="$HOST" \
  --set app.caldav.username="$CALDAV_USERNAME" \
  --set app.caldav.password="$CALDAV_PASSWORD" \
  --set 'app.caldav.calendars=Family\,Home' \
  --set image.digest="$DIGEST" \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host="$HOST" \
  --set ingress.tls[0].hosts[0]="$HOST" \
  --set ingress.tls[0].secretName=where-we-are-tls-secret \
  --set certificate.enabled=true \
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
| `image.tag` | Image tag (when digest empty) | `latest` |
| `image.digest` | Image digest (`sha256:...`; preferred) | `""` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `imagePullSecrets` | Pull secrets | `[{name: ghcr-package-read}]` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port (Ingress backend) | `80` |
| `service.targetPort` | Container port | `4000` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class | `traefik` |
| `certificate.enabled` | cert-manager Certificate | `false` |
| `certificate.issuerName` | ClusterIssuer name | `letsencrypt-dns` |
| `app.secretKeyBase` | Phoenix `SECRET_KEY_BASE` | `""` **required** |
| `app.phxHost` | Public host (`PHX_HOST`) | `where-we-are.local` |
| `app.caldav.username` | CalDAV username | `""` |
| `app.caldav.password` | CalDAV password / app-specific password | `""` |
| `app.caldav.url` | CalDAV base URL | iCloud |
| `app.caldav.calendars` | Comma-separated display names (ConfigMap; hot-reload) | `""` (all) |
| `app.caldav.eventWindowMonths` | Fetch window (ConfigMap; hot-reload) | `6` |
| `app.caldav.expandRecurrences` | Expand RRULEs | `true` |
| `app.caldav.pollMinutes` | Sync interval | `10` |
| `app.environment` | `MIX_ENV` | `prod` |

## Calendar filters (ConfigMap, no restart)

`CALDAV_CALENDARS` and `CALDAV_EVENT_WINDOW_MONTHS` are served from a ConfigMap
named `<fullname>-caldav`, mounted at `/etc/where-we-are/caldav-config`
(`CALDAV_CONFIG_DIR`). `<fullname>` is the chart fullname (usually the release
name, e.g. `where-we-are`, or `<release>-where-we-are` if they differ). The app
re-reads those files on every sync poll.

```bash
# Via Helm values
helm upgrade where-we-are ./chart/where-we-are -n where-we-are \
  --reuse-values \
  --set 'app.caldav.calendars=Family\,Home' \
  --set app.caldav.eventWindowMonths=3

# Or edit the live ConfigMap (name from: helm get manifest -n where-we-are where-we-are | grep -A2 'kind: ConfigMap')
kubectl -n where-we-are edit configmap <fullname>-caldav
```

Notes:

- **Helm `--set` treats commas as separators.** Escape them: `Family\,Primary\,Steve`, or use a values file / `kubectl edit configmap`.
- kubelet may take up to ~1 minute to refresh mounted files after a ConfigMap edit.
- The next poll (`app.caldav.pollMinutes`, default 10) applies the new filter.
- Force sooner: `kubectl -n where-we-are exec deploy/where-we-are -- bin/where_we_are rpc 'WhereWeAre.CalendarSync.sync_now()'`.
- Auth (`username`/`password`) stays in the Secret and still needs a roll for changes. See [iCloud app-specific password](#icloud-app-specific-password).

## iCloud app-specific password

An [app-specific password](https://support.apple.com/en-us/102654) should be used, do not use your Apple ID password. 

> Note: Changing or resetting the Apple Account password revokes all of the App-Specfic Passwords.

### Create one

To create an App-Specific Password:

1. Sign in at [account.apple.com](https://account.apple.com).
2. Open **Sign-In and Security**.
3. Select **App-Specific Passwords**.
4. Generate a password and label it, for example `where-we-are`.

Apple shows the password once, as `xxxx-xxxx-xxxx-xxxx`. Copy it then. 

On iPhone or iPad: **Settings → [your name] → Sign-In & Security → App-Specific Passwords**.

### Update it outside Argo CD

Argo CD renders this chart and applies it. There is no Helm release, so `helm upgrade --set app.caldav.password=...` does not update prod. The Application in `ciroque-gitops` omits `app.caldav.username` and `app.caldav.password` on purpose, and `app.secretKeyBase` is the placeholder `__managed-out-of-band__`. `ignoreDifferences` on Secret `where-we-are` `/data`, with `RespectIgnoreDifferences=true`, keeps a sync from writing those keys. Put the new password in the live Secret, then restart so the pod reads `CALDAV_PASSWORD` again:

```bash
read -s CALDAV_PASSWORD
export CALDAV_PASSWORD

kubectl -n where-we-are patch secret where-we-are --type merge \
  -p "{\"stringData\":{\"caldav-password\":\"$CALDAV_PASSWORD\"}}"

kubectl -n where-we-are rollout restart deployment/where-we-are
kubectl -n where-we-are rollout status deployment/where-we-are
```

`stringData` changes only `caldav-password`. Replacing the Secret object would drop `caldav-username` and `secret-key-base`. Do not remove the `/data` ignore to push the password through Helm values. The next sync would overwrite `secret-key-base` with the placeholder.

## Notes

- **Single replica**: sync state is per-pod memory.
- **LiveView**: `app.phxHost` must match the Ingress hostname.

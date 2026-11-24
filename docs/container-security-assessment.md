# Container Security Assessment

**Assessment date:** 2026-11-24
**Scope:** The local Linux/AMD64 image intended for future ECS Fargate use and
the Linux/ARM64 development image. No AWS resources were created and no images
were published.

## Executive summary

The earlier Docker Scout scan reported no findings in the Distroless runtime,
but that was a scanner snapshot before the November 24 OpenSSL advisories. The
current Trivy scan reports two HIGH findings in OpenSSL's QUIC implementation.
The image still uses the digest-pinned Distroless Node.js 24 Debian 13 runtime;
no supported patched image for both findings was available at this assessment.

The old Bookworm baseline counts below are historical Docker Scout results,
not the current status of the runtime image.

| Severity | Historical before (AMD64 and ARM64) | Historical after (AMD64) | Historical after (ARM64) |
|---|---:|---:|---:|
| Critical | 0 | 0 | 0 |
| High | 13 | 0 | 0 |
| Medium | 24 | 0 | 0 |
| Low | 42 | 0 | 0 |
| **Total** | **79** | **0** | **0** |

The historical Scout result is not a guarantee of future safety or proof that
every component is unexploitable. The current Trivy result and risk analysis
follow below.

## Current Trivy findings and risk assessment

The current final-image scan is for Linux/AMD64, using Trivy 0.70.0 with
vulnerability scanning enabled, `CRITICAL,HIGH` severity, and
`ignore-unfixed: false`.

| Finding | Affected component | Installed version | Trivy result | Fixed version |
|---|---|---|---|---|
| CVE-2026-107494 | Debian `libssl3t64`; OpenSSL QUIC connection-ID frame queue | `3.5.9-1~deb13u1` | HIGH | None reported by Trivy or Debian at assessment time |
| CVE-2026-124709 | Debian `libssl3t64`; OpenSSL QUIC stream cleanup | `3.5.9-1~deb13u1` | HIGH | None reported by Trivy or Debian at assessment time |

The final runtime image is `gcr.io/distroless/nodejs24-debian13:nonroot` at
`sha256:39b0407357c9fadf1a9708d22088f02de21f0e1e8a688474eea2d8701e7d5693`.
Trivy identifies Debian 13.8 and the installed `libssl3t64` version above.
The Node runtime is v24.22.3 and reports OpenSSL 3.5.9. Its
`node_shared_openssl` build setting is false, so Node uses its bundled OpenSSL;
the application process maps did not show a dynamically loaded `libssl` or
`libcrypto` library. The OpenSSL code is therefore present both as the
system package flagged by Trivy and in the Node runtime build.

### CVE-2026-107494

- **Affected functionality:** OpenSSL QUIC handling can enqueue unbounded
  `RETIRE_CONNECTION_ID` frames when processing retransmitted
  `NEW_CONNECTION_ID` frames. A malicious QUIC peer can cause memory
  exhaustion and denial of service.
- **Application use and reachability:** The API starts a `node:http` server.
  The source does not use a QUIC API, and Node v24.22.3 does not provide a
  loadable `node:quic` built-in (`ERR_UNKNOWN_BUILTIN_MODULE`). The service
  has no QUIC listener. The affected path is not reachable through the
  application’s configured HTTP listener.
- **Exploitability and impact:** A reachable application would need to use
  OpenSSL's QUIC stack and accept the malicious QUIC traffic. Those
  preconditions are absent in the current app. The described impact is
  denial of service, not memory disclosure or code execution.
- **Fix status:** Debian's tracker still marks the Trixie package vulnerable
  and lists no fixed version. OpenSSL's November 24 advisory rates this issue
  Low and says the fix is in the public source tree, with OpenSSL 3.5.10
  scheduled for December 1, 2026. Until Debian publishes a supported package
  and the pinned runtime image contains it, this is not a verified image fix.
  Sources: [OpenSSL advisory](https://openssl-library.org/news/secadv/20261124.txt),
  [Debian tracker](https://security-tracker.debian.org/tracker/CVE-2026-107494).
- **Compensating controls:** No QUIC listener or UDP ingress is configured;
  the application uses the HTTP server path, with TLS intended to terminate
  at the ALB. The container also runs non-root with all capabilities dropped,
  a read-only root filesystem, and bounded service resources. These controls
  reduce reachable attack surface or impact but do not patch OpenSSL.

### CVE-2026-124709

- **Affected functionality:** The Debian tracker and Trivy describe a QUIC
  server retaining rejected peer-stream state after a reset, allowing memory
  growth over a long-lived connection as a remote client repeatedly opens
  and resets streams.
- **Application use and reachability:** The app does not create an OpenSSL
  QUIC server, accept QUIC streams, or expose a QUIC listener. Therefore the
  described protocol path is not reachable through its configured HTTP
  service.
- **Exploitability and impact:** The reported scenario requires a QUIC
  server, a completed connection, and repeated peer-controlled stream
  activity. Its described impact is denial of service through memory
  exhaustion; no memory disclosure or corruption is described.
- **Fix status:** Trivy reports no fixed version, and Debian's tracker does
  not list a fixed package version. I did not find this CVE in the OpenSSL
  November 24 public advisory, so an upstream release resolving this finding
  must be confirmed rather than inferred from the CVE-2026-107494 fix.
  Source: [Debian tracker](https://security-tracker.debian.org/tracker/CVE-2026-124709).
- **Compensating controls:** No QUIC listener or UDP ingress is configured;
  the ALB-to-application path is HTTP. Non-root execution, dropped
  capabilities, a read-only filesystem, and bounded service resources reduce
  impact but do not resolve the vulnerable code.

### Runtime alternatives and deployment decision

The pinned Distroless digest is also the current
`nodejs24-debian13:nonroot` index digest, so refreshing the digest does not
change the affected packages. The current official `node:24-trixie-slim` index
(`sha256:4d00acb4bcc42c454c4eb801526f7ad7f772ea3bd4fd168c5cc2e384abcbb9d4`)
also runs Node v24.22.3 with bundled OpenSSL 3.5.9; it does not remediate the
embedded OpenSSL code. The official `node:24-alpine` index
(`sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5`)
runs the same Node/OpenSSL versions; Alpine 3.24.4 has `libssl3` 3.5.9-r0.
Its Trivy scan found six HIGH Node-package
issues (including bundled `undici` and `brace-expansion`), while not reporting
these two CVEs against Alpine's separately versioned system packages. That
scanner difference is not evidence that the bundled OpenSSL code is fixed.
Switching to Alpine would also change glibc to musl and invalidate the
currently validated `argon2.glibc.node` prebuild unless dependencies were
rebuilt and retested for musl. It is not a justified remediation.

The current Distroless scan has **0 CRITICAL and 2 HIGH findings**; the
Alpine comparison has **0 CRITICAL and 6 HIGH findings**. Trivy assigns HIGH
to the Debian findings, while OpenSSL's public advisory rates
CVE-2026-107494 Low. The CVE-2026-124709 tracker description also calls its
impact Low, but no matching public OpenSSL advisory was located. The
configured CI policy remains CRITICAL/HIGH and is not being weakened based on
this reachability analysis. Docker CI should continue to fail closed. Do not
deploy under the current gate without either a supported image containing
verified fixes for both CVEs or a narrowly scoped, documented, time-limited
exception approved by the responsible security/release owner. No exception
has been added.

## Images and reproducibility

| Purpose | Image | Pinned index digest |
|---|---|---|
| Dependency installation and integration tests | `node:24-trixie-slim` | `sha256:af02d57b57719b9657a45199a79264a9437940cd55b3c7b3fc99615654f124a0` |
| Final Node.js runtime | `gcr.io/distroless/nodejs24-debian13:nonroot` | `sha256:39b0407357c9fadf1a9708d22088f02de21f0e1e8a688474eea2d8701e7d5693` |

| Historical final local artifact (2026-11-20) | Platform | Size | Docker Scout snapshot |
|---|---|---:|---|
| `production-ready-aws-devops-platform-api:amd64` | Linux/AMD64 | 167,597,275 bytes | No vulnerable package detected |
| `production-ready-aws-devops-platform-api:arm64` | Linux/ARM64 | 174,666,942 bytes | No vulnerable package detected |

Both indexes provide AMD64 and ARM64 manifests. The Distroless runtime includes
Node `v24.22.3`, runs as UID/GID `65532:65532`, and does not contain npm,
Corepack, Yarn, or a shell. The builder retains npm to install the committed
lockfile and run tests. Production dependencies are still installed with
`npm ci --omit=dev`; the application dependency tree reported zero findings
under both Docker Scout and `npm audit`.

The baseline `undici@6.28.0` and `brace-expansion@5.0.9` findings came from the
Node image's global npm toolchain. `npm ls --omit=dev undici` showed no such
application dependency. The Node runtime's bundled Undici was `7.30.2`, outside
the affected 6.x ranges. The final image omits the unused npm toolchain rather
than carrying its vulnerable copies or adding an override to the application
lockfile.

## Baseline high-severity findings

Scout reported the following 13 high findings in the old runtime image. A
“fixed version” is what Scout identified at the baseline scan; “no fix
reported” means the feed did not provide one at that time.

| Package and installed version | Origin | High CVEs | Baseline fix information | Final runtime assessment |
|---|---|---|---|---|
| `undici` 6.28.0 | npm bundled with the old base image | CVE-2026-87018, CVE-2026-19534, CVE-2026-109869, CVE-2026-109383 | 6.29.1 for three advisories; 6.28.1 for the remaining advisory | The vulnerable npm-bundled copy is absent. Node's bundled Undici is 7.30.2; application code has no Undici package dependency. |
| `brace-expansion` 5.0.9 | npm bundled with the old base image | CVE-2026-102278, CVE-2026-102276 | 5.0.11 and 5.0.10, respectively | The npm-bundled copy is absent from the Distroless runtime. |
| `util-linux` 2.38.1-5+deb12u3 | Debian 12 Bookworm base | CVE-2026-53615, CVE-2026-78410, CVE-2026-53613 | No fix reported | The affected Bookworm package is not in the final runtime SBOM. |
| `zlib` 1:1.2.13.dfsg-1 | Debian 12 Bookworm base | CVE-2026-85091, CVE-2026-76844 | No fix reported for that Bookworm package | The final Debian 13 runtime contains zlib 1:1.3.dfsg+really1.3.1-1+deb13u1; Scout reports no finding. |
| `glibc` 2.36-9+deb12u14 | Debian 12 Bookworm base | CVE-2026-84243 | No fix reported | The final runtime uses glibc 2.41-12+deb13u4; Scout reports no finding. |
| `pam` 1.5.2-6+deb12u2 | Debian 12 Bookworm base | CVE-2025-6020 | No fix reported | The affected package version is absent from the final runtime SBOM. |

These are package-presence findings. They do not establish that the API exposed
an exploitable path to each vulnerable library. Moving to a smaller, newer
runtime removed the affected old packages rather than suppressing scanner
results.

## Remaining baseline medium- and low-severity findings

The table lists the other baseline findings for completeness. The historical
Scout scan reported none of these CVEs in the Distroless images on either
architecture; this is separate from the current Trivy scan above.

| Package and installed version | Origin | CVEs (severity) | Fix information reported by Scout |
|---|---|---|---|
| `undici` 6.28.0 | Old base npm toolchain | CVE-2026-85024 (M), CVE-2026-109932 (M), CVE-2026-109924 (M), CVE-2026-18540 (L) | 6.28.1 for two advisories; 6.29.1 for the other two |
| `util-linux` 2.38.1-5+deb12u3 | Debian 12 Bookworm | CVE-2026-13595 (M), CVE-2025-14104 (L), CVE-2022-0563 (L) | No fix reported |
| `brace-expansion` 5.0.9 | Old base npm toolchain | CVE-2026-102277 (M) | 5.0.12 |
| `glibc` 2.36-9+deb12u14 | Debian 12 Bookworm | CVE-2026-86805, CVE-2026-124024, CVE-2026-121758, CVE-2026-121757, CVE-2026-115819 (M); CVE-2026-97399, CVE-2026-126765, CVE-2026-100290, CVE-2026-95818, CVE-2019-9192, CVE-2019-1010025, CVE-2019-1010024, CVE-2019-1010023, CVE-2019-1010022, CVE-2018-20796, CVE-2010-4756 (L) | No fix reported |
| `ip-address` 10.5.0 | Old base npm toolchain | CVE-2026-101910, CVE-2026-111997, CVE-2026-101913, CVE-2026-101912, CVE-2026-101911 (M) | 10.5.1, 10.7.4, 10.5.1, 10.7.1, and 10.7.1, respectively |
| `gnutls28` 3.7.9-2+deb12u7 | Debian 12 Bookworm | CVE-2026-127231, CVE-2026-127040, CVE-2026-127039 (M); CVE-2026-95210, CVE-2026-95209, CVE-2026-95184, CVE-2026-88648, CVE-2026-88647, CVE-2026-67693, CVE-2011-3389 (L) | No fix reported |
| `gcc-12` 12.2.0-14+deb12u1 | Debian 12 Bookworm | CVE-2026-125709 (M); CVE-2026-115456, CVE-2022-27943 (L) | No fix reported |
| `tar` 1.34+dfsg-1.2+deb12u1 | Debian 12 Bookworm | CVE-2025-45582 (M); CVE-2005-2541 (L) | No fix reported |
| `glob` 13.0.6 | Old base npm toolchain | CVE-2026-118773 (M) | 14.0.2 |
| `minimatch` 10.2.5 | Old base npm toolchain | CVE-2026-118764 (M) | 11.0.1 |
| `dpkg` 1.21.23 | Debian 12 Bookworm | CVE-2026-91094 (M) | No fix reported |
| `postcss-selector-parser` 7.1.4 | Old base npm toolchain | CVE-2026-104844 (M) | 7.1.6 |
| `systemd` 252.39-1~deb12u2 | Debian 12 Bookworm | CVE-2023-31439, CVE-2023-31438, CVE-2023-31437, CVE-2013-4392 (L) | No fix reported |
| `coreutils` 9.1-1 | Debian 12 Bookworm | CVE-2026-56392, CVE-2026-56391, CVE-2025-5278, CVE-2017-18018 (L) | No fix reported |
| `dash` 0.5.12-2 | Debian 12 Bookworm | CVE-2026-102474, CVE-2026-102473 (L) | No fix reported |
| `libgcrypt20` 1.10.1-3+deb12u1 | Debian 12 Bookworm | CVE-2024-2236, CVE-2018-6829 (L) | No fix reported |
| `perl` 5.36.0-7+deb12u4 | Debian 12 Bookworm | CVE-2023-31486, CVE-2011-4116 (L) | No fix reported |
| `diffutils` 1:3.8-4 | Debian 12 Bookworm | CVE-2026-53910 (L) | No fix reported |
| `apt` 2.6.2 | Debian 12 Bookworm | CVE-2011-3374 (L) | No fix reported |
| `gnupg2` 2.2.40-1.1+deb12u2 | Debian 12 Bookworm | CVE-2022-3219 (L) | No fix reported |
| `shadow` 1:4.13+dfsg1-1+deb12u2 | Debian 12 Bookworm | CVE-2007-5686 (L) | No fix reported |

## Architecture comparison

The historical Docker Scout AMD64 and ARM64 scans produced the same
0/13/24/42 severity counts, affected package versions, and high-severity CVEs.
The current Trivy result is for AMD64 only and reports two HIGH findings.
Docker Scout's earlier scan did not identify an architecture-specific
vulnerability difference; ARM64 has not been rescanned with the current Trivy
database for these advisories.

## Validation evidence

- Docker Scout indexed the earlier final Node 24 runtime for Linux/AMD64 and
  Linux/ARM64 and reported no vulnerable packages in that scan snapshot.
- Trivy 0.70.0 scanned the final Linux/AMD64 image with HIGH/CRITICAL
  filtering and reported the two OpenSSL findings documented above.
- Trivy 0.70.0 scanned the official `node:24-alpine` alternative: it reported
  six HIGH Node-package findings and did not report these OpenSSL CVEs against
  Alpine's system packages. The Alpine image still embeds OpenSSL 3.5.9, so
  that scanner result does not establish remediation.
- Inspected the running final image: Node v24.22.3 reports OpenSSL 3.5.9,
  `node_shared_openssl=false`, no `node:quic` built-in, and no dynamically
  mapped `libssl` or `libcrypto` after loading Argon2.
- `npm audit` reported zero vulnerabilities in the complete lockfile dependency
  tree.
- The latest Node.js 24 run passed all 21 application unit tests; line coverage
  was 86.91%.
- The isolated PostgreSQL integration test passed.
- The native Argon2 module loaded and successfully hashed/verified a password
  in both final architecture images.
- Compose verified liveness and PostgreSQL readiness. A provisioned account
  authenticated, created a task, and the task remained after restarting only
  the API container.
- The API ran as UID/GID 65532 with a read-only root filesystem, all Linux
  capabilities dropped, `no-new-privileges`, and loopback-only host publishing.
- SIGTERM shutdown emitted both `Graceful shutdown started` and
  `HTTP server closed`.

As of this assessment, Trivy reports two HIGH findings and the Docker CI
security gate should fail. The OpenSSL QUIC paths are not reachable through
the current HTTP-only application listener, but the code remains present in
the runtime and this does not constitute a patch. Production deployment
should remain blocked under the existing policy until both fixes are verified
in a supported pinned image or a responsible security/release owner approves
a narrow, documented, time-limited exception. No AWS deployment occurred;
any future deployment must also satisfy network, IAM, secrets, TLS, logging,
and operational requirements.

## Implemented container security controls

- Digest-pinned Node 24 builder/test and Distroless Node 24 runtime images.
- Lockfile-based `npm ci`; production image contains production dependencies
  only and excludes package managers, shell utilities, tests, and build tools.
- Non-root UID/GID `65532:65532`, preserved read-only root filesystem,
  dropped capabilities, and `no-new-privileges`.
- Compose publishes the API only on `127.0.0.1`; PostgreSQL remains private to
  the Compose network.
- Health checks use Node directly; SIGTERM is handled by the application for
  bounded graceful shutdown.
- No credentials or local environment files are copied into the image.

## Ongoing scanning policy

1. Scan each published architecture image by immutable digest and retain its
   SBOM and scanner output with the release record.
2. Block releases on any critical or high finding until a patched image or
   dependency is verified. Any exception should identify the CVE, component,
   reachability/exploitability analysis, owner, expiry date, and approval.
3. Scan on each image build and on new advisories; refresh pinned base digests
   on a regular schedule and immediately when relevant security fixes appear.
4. Run `npm audit` and Docker Scout against both AMD64 and ARM64 artifacts; do
   not suppress findings solely to improve reported counts.
5. Re-run the application, PostgreSQL, Argon2, health, persistence, and
   shutdown checks whenever a base image or runtime dependency changes.

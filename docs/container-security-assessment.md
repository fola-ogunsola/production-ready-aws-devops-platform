# Container Security Assessment

**Assessment date:** 2026-11-20
**Scope:** The local Linux/AMD64 image intended for future ECS Fargate use and
the Linux/ARM64 development image. No AWS resources were created and no images
were published.

## Executive summary

Docker Scout confirmed the reported baseline on both architectures. The
vulnerable packages were in the old Debian Bookworm Node base, including npm's
globally bundled toolchain; they were not findings in the application's
production dependency tree. The runtime has been moved to a digest-pinned
Distroless Node.js 24 Debian 13 image. This retains Node 24 and glibc support
for Argon2 while excluding the shell and global npm/Corepack/Yarn toolchain.

| Severity | Before (AMD64 and ARM64) | After (AMD64) | After (ARM64) |
|---|---:|---:|---:|
| Critical | 0 | 0 | 0 |
| High | 13 | 0 | 0 |
| Medium | 24 | 0 | 0 |
| Low | 42 | 0 | 0 |
| **Total** | **79** | **0** | **0** |

The final scans each indexed the image and reported **no vulnerable package
detected**. This is a scanner snapshot, not a guarantee of future safety or
proof that every component is unexploitable.

## Images and reproducibility

| Purpose | Image | Pinned index digest |
|---|---|---|
| Dependency installation and integration tests | `node:24-trixie-slim` | `sha256:af02d57b57719b9657a45199a79264a9437940cd55b3c7b3fc99615654f124a0` |
| Final Node.js runtime | `gcr.io/distroless/nodejs24-debian13:nonroot` | `sha256:6abfcb367ebc291572c774c1592a986be2ab26a2486f73093401327495a5962a` |

| Final local artifact | Platform | Size | Docker Scout |
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

The table lists the other baseline findings for completeness. The final scans
reported none of these CVEs on either architecture.

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

The baseline AMD64 and ARM64 scans produced the same 0/13/24/42 severity
counts, affected package versions, and high-severity CVEs. The final AMD64 and
ARM64 scans both report zero findings. Docker Scout did not identify an
architecture-specific vulnerability difference in these images.

## Validation evidence

- Built the final Node 24 runtime for Linux/AMD64 and Linux/ARM64 from the
  pinned image digests.
- Docker Scout indexed each final image and reported no vulnerable packages.
- `npm audit` reported zero vulnerabilities in the complete lockfile dependency
  tree.
- All 21 application unit tests passed; line coverage was 86.99%.
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

No unresolved critical or high findings remain in the final Scout reports;
therefore no Scout-identified high finding currently blocks deployment.
However, AWS deployment remains out of scope and must still satisfy the
platform's network, IAM, secrets, TLS, logging, and operational requirements.

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

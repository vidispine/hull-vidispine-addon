FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
# ARG _VERSIONs carry a 'renovate:' annotation comment so Renovate bumps them. Each matching *_CHECKSUM ARG
# is kept in sync automatically by the Renovate postUpgradeTask hook (.github/renovate/update-checksum.sh)
# - do NOT edit the checksums by hand. They are stored here on purpose: the build verifies against
# them offline and never fetches a checksum live at build time.
#
# renovate: datasource=github-releases depName=PowerShell/PowerShell
ARG PS_VERSION=7.6.7
# Checksum of powershell_${PS_VERSION}-1.deb_amd64.deb (from the release hashes.sha256).
# Source: https://github.com/PowerShell/PowerShell/releases/download/v<version>/hashes.sha256
ARG PS_CHECKSUM=868c575f0822b2deed054c1c3c464a9d4b841f67e153369147fb6ace3545c8b2
# renovate: datasource=github-releases depName=oras-project/oras
ARG ORAS_VERSION=1.3.5
# Checksum of oras_${ORAS_VERSION}_linux_amd64.tar.gz (from the release checksums.txt).
# Sources: https://github.com/oras-project/oras/releases/download/v<version>/oras_<version>_checksums.txt
#          https://github.com/oras-project/setup-oras/blob/main/src/lib/data/releases.json
ARG ORAS_CHECKSUM=f48a73ea6d026a862c3919fc773da9a8c86fc259c2c737d5baed3b8b9614ad22
# Ensure no interactive prompts from apt-get, also beyond -y.
# Do not set ENV DEBIAN_FRONTEND=noninteractive; this would remain in the image and running container!
ARG BUILD_DEBIAN_FRONTEND=noninteractive
RUN export DEBIAN_FRONTEND=${BUILD_DEBIAN_FRONTEND} \
 && apt-get update \
 && apt-get -y --no-install-recommends dist-upgrade \
 && apt-get -y install --no-install-recommends ca-certificates curl \
 && echo "Downloading and installing PowerShell ${PS_VERSION} (.deb) from the matching GitHub release..." \
 && curl -fsSLO "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell_${PS_VERSION}-1.deb_amd64.deb" \
 && echo "Verifying the .deb against the stored PS_CHECKSUM (no live checksum fetch at build time)..." \
 && echo "${PS_CHECKSUM}  powershell_${PS_VERSION}-1.deb_amd64.deb" | sha256sum -c - \
 && apt-get install -y --no-install-recommends "./powershell_${PS_VERSION}-1.deb_amd64.deb" \
 && rm "powershell_${PS_VERSION}-1.deb_amd64.deb" \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
 && pwsh -NonInteractive -Command Install-Module -Force -Scope AllUsers powershell-yaml \
 && echo "Downloading and installing ORAS CLI version ${ORAS_VERSION}..." \
 && curl -LO "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz" \
 && echo "${ORAS_CHECKSUM}  oras_${ORAS_VERSION}_linux_amd64.tar.gz" | sha256sum -c - \
 && mkdir -p oras-install/ \
 && tar -zxf oras_${ORAS_VERSION}_*.tar.gz -C oras-install/ \
 && mv oras-install/oras /usr/local/bin/ \
 && rm -rf oras_${ORAS_VERSION}_*.tar.gz oras-install/ \
 && oras --help \
 && groupadd -g 1001 noroot \
 && useradd --create-home --shell /bin/bash -u 1001 -g noroot noroot
COPY --chown=noroot:noroot ./Installer.ps1 /script/Installer.ps1
COPY --chown=noroot:noroot ./get-custom-scripts /get-custom-scripts
USER noroot
# If it becomes necessary to create a root version again, do not change here, but
# create a derived Dockerfile.root based on this one, with only "USER root".

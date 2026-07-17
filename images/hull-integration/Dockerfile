FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90
# renovate: datasource=github-releases depName=PowerShell/PowerShell
ARG PS_VERSION=7.6.0
ENV ORAS_VERSION="1.3.1"
# Keep EXACTLY the same Dockerfile and Dockerfile-noroot, except USER noroot (shared layers)!
# ORAS release checksum sources (ORAS setup or Release information, Linux amd64):
# Store here, don't read at build time!
# https://github.com/oras-project/oras/releases/download/v<version>/oras_<version>_checksums.txt
# https://github.com/oras-project/setup-oras/blob/main/src/lib/data/releases.json
# https://api.github.com/repos/oras-project/oras/releases/tags/v<version> (large Release content JSON)
ENV ORAS_CHECKSUM="d52c4af76ce6a3ceb8579e51fb751a43ac051cca67f965f973a0b0e897a2bb86"
# 1.3.0: ENV ORAS_CHECKSUM="6cdc692f929100feb08aa8de584d02f7bcc30ec7d88bc2adc2054d782db57c64"
RUN apt-get update \
 && apt-get -y --no-install-recommends upgrade \
 && apt-get -y install --no-install-recommends ca-certificates curl \
 && echo "Downloading and installing PowerShell ${PS_VERSION} (.deb) from the matching GitHub release..." \
 && curl -fsSLO "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell_${PS_VERSION}-1.deb_amd64.deb" \
 && echo "Verifying the .deb against the release checksums (hashes.sha256 is UTF-16, decode first)..." \
 && curl -fsSLO "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/hashes.sha256" \
 && iconv -f UTF-16 -t UTF-8 hashes.sha256 | grep -F "powershell_${PS_VERSION}-1.deb_amd64.deb" | sha256sum --check - \
 && apt-get install -y --no-install-recommends "./powershell_${PS_VERSION}-1.deb_amd64.deb" \
 && rm "powershell_${PS_VERSION}-1.deb_amd64.deb" hashes.sha256 \
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
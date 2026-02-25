FROM mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04
RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get -y install curl \
 && pwsh -NonInteractive -Command Install-Module -Force -Scope AllUsers powershell-yaml \
 && rm -rf /var/lib/apt/lists/*
ENV VERSION="1.3.0"
RUN curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz" \
 && ls \
 && mkdir -p oras-install/ \
 && tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/ \
 && mv oras-install/oras /usr/local/bin/ \
 && rm -rf oras_${VERSION}_*.tar.gz oras-install/ \
 && oras --help
COPY ./Installer.ps1 /script/Installer.ps1
COPY ./get-custom-scripts /get-custom-scripts
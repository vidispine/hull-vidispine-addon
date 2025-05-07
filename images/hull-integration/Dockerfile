FROM mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04
RUN pwsh -NonInteractive -Command Install-Module -Force -Scope AllUsers powershell-yaml
RUN apt-get update
RUN apt-get upgrade
RUN apt-get -y install curl
ENV VERSION="1.2.3"
RUN curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz" 
RUN ls
RUN mkdir -p oras-install/
RUN tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
RUN mv oras-install/oras /usr/local/bin/
RUN rm -rf oras_${VERSION}_*.tar.gz oras-install/
COPY ./Installer.ps1 /script/Installer.ps1
COPY ./get-custom-scripts /get-custom-scripts
RUN oras --help
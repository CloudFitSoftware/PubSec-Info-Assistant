FROM cloudfitglpoc.azurecr.io/info-asst-bootstrapper@sha256:fca9e17ef82491923f75f00b9bc5fdbb72c008bf59e6c5928c68e52f26b487ad AS source
FROM registry1.dso.mil/ironbank/redhat/ubi/ubi9:9.3

WORKDIR info-asst

COPY --from=source /info-asst/artifacts/ ./artifacts/
COPY --from=source /info-asst/infra/ ./infra/
COPY --from=source /info-asst/azure_search/ ./azure_search/
COPY --from=source /info-asst/scripts/environments/languages ./environments/languages

COPY ./scripts/ ./

RUN chmod +x ./*.sh

# Update the image and install necessary dependencies
RUN dnf update -y && \
    dnf install -y ca-certificates unzip jq libicu gettext && \
    dnf clean all

## Installing AZ CLI
# Import MS repo key
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    # Configure Microsoft repo
    dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm && \
    # Install az-cli
    dnf install -y azure-cli

ENTRYPOINT ["./startup.sh"]

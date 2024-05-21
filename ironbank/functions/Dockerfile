ARG BASE_REGISTRY=registry1.dso.mil/ironbank
ARG BASE_IMAGE=opensource/python
ARG BASE_TAG=v3.11

FROM infoasstcrshared.azurecr.us/function:latest AS source
FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

ENV LANG=C.UTF-8 \
    ACCEPT_EULA=Y \
    AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true \
    HOME=/home \
    FUNCTIONS_WORKER_RUNTIME=python \
    ASPNETCORE_URLS=http://+:80 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    HOST_VERSION=4.31.1 \
    ASPNETCORE_CONTENTROOT=/azure-functions-host \
    FUNCTIONS_WORKER_RUNTIME_VERSION=3.11

# running root to enable dnf install
USER root

RUN dnf install -y ca-certificates glibc libgcc krb5-libs libicu openssl-libs libstdc++ zlib

COPY --from=source /home/site/wwwroot/ /home/site/wwwroot/
COPY --from=source /azure-functions-host/ /azure-functions-host/
COPY --from=source /FuncExtensionBundles/ /FuncExtensionBundles/
COPY --from=source /opt/startup/ /opt/startup/

# Create and set permissions for /home/data directory
RUN mkdir -p /home && \
    chown -R 1001:1001 /home && \
    chmod -R 755 /home

# Install required Python packages from requirements.txt
RUN cd /home/site/wwwroot && \
    pip install --upgrade pip && \
    pip install -r requirements.txt && \
    cd --

USER 1001:1001

HEALTHCHECK NONE

ENTRYPOINT ["/opt/startup/start_nonappservice.sh"]
FROM alpine:latest

WORKDIR info-asst

COPY ./artifacts/ ./artifacts/
COPY ./infra/ ./infra/
COPY ./azure_search/ ./azure_search/
COPY ./scripts/ ./scripts/

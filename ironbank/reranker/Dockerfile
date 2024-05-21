ARG BASE_REGISTRY=registry1.dso.mil/ironbank
ARG BASE_IMAGE=opensource/python
ARG BASE_TAG=v3.10

FROM infoasstcrshared.azurecr.us/reranker:latest AS source

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

WORKDIR /reranker

# copy the necessary folders
COPY --from=source /app .
RUN pip3 install -r requirements.txt

EXPOSE 8080

USER 1001:1001

HEALTHCHECK NONE

ENTRYPOINT ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]

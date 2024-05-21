ARG BASE_REGISTRY=registry1.dso.mil/ironbank
ARG BASE_IMAGE=opensource/python
ARG BASE_TAG=v3.10

FROM infoasstcrshared.azurecr.us/enrichment:latest AS source

# bring in approved version of python
FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

WORKDIR /enrichment

# copy the necessary folders
COPY --from=source /enrichment . 

RUN pip install -r requirements.txt
RUN pip install gunicorn

EXPOSE 5000

USER 1001:1001

HEALTHCHECK NONE

ENTRYPOINT ["gunicorn", "-w", "2", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:5000", "app:app"]
ARG BASE_REGISTRY=registry1.dso.mil/ironbank
ARG BASE_IMAGE=opensource/python
ARG BASE_TAG=v3.10

FROM infoasstcrshared.azurecr.us/llm:latest AS source

# bring in approved version of python
FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

WORKDIR /llm

# copy the necessary folders
COPY --from=source /llm . 

RUN pip install -r requirements.txt
RUN pip install gunicorn

EXPOSE 6001

USER 1001:1001

HEALTHCHECK NONE

ENTRYPOINT ["gunicorn", "-w", "1", "--timeout", "900", "--bind", "0.0.0.0:6001", "server:app", "--threads", "100"]
ARG BASE_REGISTRY=registry1.dso.mil/ironbank
ARG BASE_IMAGE=opensource/python
ARG BASE_TAG=v3.10

FROM infoasstcrshared.azurecr.us/webapp:latest AS source

# bring in approved version of python
FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

WORKDIR /webapp

# copy the necessary folders
COPY --from=source /webapp . 

RUN pip install -r requirements.txt
RUN pip install gunicorn

EXPOSE 5050

USER 1001:1001

HEALTHCHECK NONE

ENTRYPOINT ["gunicorn", "--timeout=300", "--bind=0.0.0.0:5050", "app:app", "--threads=100"]

# istio-controlplane

This helm chart install the istio operator crd to configure how istio will run on your cluster. Currently this helm chart only installs ingress gateways and configures them with service annotations that are specified.

## TL;DR

```console
$ helm install istio-controlplane istio-controlplane
```

## Introduction

This chart creates a sane deployment of the [istio operator crd](https://istio.io/latest/docs/reference/config/istio.operator.v1alpha1/) for a cluster's istio control plane. The chart provides the following features of the istio control plane.

- Allows the override of all associated images with `digest` values
- Allows setting of specific resource utilization
- Allows setting of service annotations for all gateways or specific gateways
- Allows default gateway to be enabled / disabled
- Allows setting HPA min/max values
- Allows setting of Load Balancer IP address to each gateway
- Allows the creation of `N` gateways using an array

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- [Istio operator](../istio-operator-chart/Chart.yaml) installed

## Installing the Chart

To install the chart with the release name `istio-controlplane`:

```console
$ helm install istio-controlplane istio-controlplane
```

The command deploys istio-controlplane on the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list -a`

## Uninstalling the Chart

To uninstall/delete the `istio-controlplane` deployment:

```console
helm delete istio-controlplane
```

The command removes all the Kubernetes components associated with the chart and deletes the release. This includes **all** load balancer ip addresses.

## Parameters

### Global

| Name        | Description                                                       | Value          |
| ----------- | ----------------------------------------------------------------- | -------------- |
| `namespace` | select the namespace you want to deploy the istio operator crd to | `istio-system` |


### Image paramters

| Name                         | Description                                                 | Value                                                |
| ---------------------------- | ----------------------------------------------------------- | ---------------------------------------------------- |
| `images.hub`                 | The istio hub all images are pulled from                    | `cfsprodacr.azurecr.io/offline-test`         |
| `images.tag`                 | the tag istio will expect for all images unless overwrote   | `1.9-alpha.88cb4e171b6102a69b2fe2c08a0f3933bf473138` |
| `images.pullSecrets.enabled` | If image pull secrets will be added                         | `true`                                               |
| `images.pullSecrets.name`    | the name of the existing                                    | `regcred`                                            |
| `images.proxy.repository`    | the proxy image repository that will override the hub value | `cfsprodacr.azurecr.io/offline-test/proxyv2` |
| `images.proxy.digest`        | the proxy image digest, will override images.tag            | `""`                                                 |
| `images.pilot.repository`    | the proxy image repository that will override the hub value | `cfsprodacr.azurecr.io/offline-test/pilot`   |
| `images.pilot.digest`        | the proxy image digest, will override images.tag            | `""`                                                 |


### Mesh Configuration

| Name                            | Description                                  | Value  |
| ------------------------------- | -------------------------------------------- | ------ |
| `meshConfig.useStdout`          | sends all log files to stdout                | `true` |
| `meshConfig.useJsonLogEncoding` | uses json log encoding for access logs       | `true` |
| `meshConfig.logLevel`           | sets the log level for access and istio logs | `info` |


### Ingress Gateways

| Name                                           | Description                                                           | Value   |
| ---------------------------------------------- | --------------------------------------------------------------------- | ------- |
| `ingressGateways.serviceAnnotations`           | a range to set service annotations for every ingress gateway          | `{}`    |
| `ingressGateways.hpa.minReplicas`              | the hpa min replicas for all gateways                                 | `1`     |
| `ingressGateways.hpa.maxReplicas`              | the hpa max replicas for all gateways                                 | `3`     |
| `ingressGateways.hpa.cpuTargetUtilization`     | when the ingress gateway will scale up to the next replica            | `80`    |
| `ingressGateways.resources.requests.cpu`       | the requested cpu by the ingress gateways                             | `100m`  |
| `ingressGateways.resources.requests.memory`    | the requested memory by the ingress gateways                          | `60Mi`  |
| `ingressGateways.resources.limits.cpu`         | the limited cpu by the ingress gateways                               | `150m`  |
| `ingressGateways.resources.limits.memory`      | the limited memory by the ingress gateways                            | `200Mi` |
| `ingressGateways.default.enabled`              | if the default gateway will be created                                | `false` |
| `ingressGateways.default.serviceAnnotations`   | the service annotations to be added to the default gateway's services | `{}`    |
| `ingressGateways.default.loadBalancerStaticIp` | the default gateways static ip. Do not set to make it dynamic         | `{}`    |


### Gateway Setup

| Name                                                     | Description                                                                                  | Value |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ----- |
| `ingressGateways.ipGatewaySetup`                         | object to create instances of istio gatways, each gateway will have a different LB ipaddress |       |
| `ingressGateways.ipGatewaySetup[n].Name`                 | The name of the gatweay                                                                      |       |
| `ingressGateways.ipGatewaySetup[n].serviceAnnotations`   | service annotations to add to this gatway                                                    |       |
| `ingressGateways.ipGatewaySetup[n].loadBalancerStaticIp` | the static ip to set for this gateway, leave unset to make dynmaic                           |       |


See https://github.com/bitnami-labs/readme-generator-for-helm to create the table

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
helm install istio-controlplane \
  --set images.hub=dockerhub.com/istio \
  --set images.tag=1.10 
    istio-controlplane
```

The above command configures the hub and tag for all the istio images.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
helm install my-release -f values.yaml bitnami/istio-controlplane
```

> **Tip**: You can use the default [values.yaml](values.yaml)
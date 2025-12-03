ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:161a4e29ea482bab6048c2b36031b4f302ae81e4ff18b83e61785f40dc576f5d

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/results
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -tags strictfipsruntime -v -o /tmp/results-api \
    ./cmd/api

FROM $RUNTIME
ARG VERSION=results-1-19-4

ENV API=/usr/local/bin/results-api \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/results-api ${API}
COPY --from=builder /tmp/results-api ${KO_APP}/api
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-results-api-rhel9-container" \
      name="openshift-pipelines/pipelines-results-api-rhel9" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Results Api" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Results Api" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Results Api" \
      io.k8s.description="Red Hat OpenShift Pipelines Results Api" \
      io.openshift.tags="pipelines,tekton,openshift" \
      cpe="cpe:/a:redhat:openshift_pipelines:1.19::el9"

RUN microdnf install -y shadow-utils
RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/results-api"]

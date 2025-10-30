ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.24
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:34880b64c07f28f64d95737f82f891516de9a3b43583f39970f7bf8e4cfa48b7 

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/results
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/results-retention-policy-agent \
    ./cmd/retention-policy-agent

FROM $RUNTIME
ARG VERSION=results-next

ENV RETENTION_POLICY_AGENT=/usr/local/bin/results-retention-policy-agent \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/results-retention-policy-agent ${RETENTION_POLICY_AGENT}
COPY --from=builder /tmp/results-retention-policy-agent ${KO_APP}/retention-policy-agent
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-results-retention-policy-agent-rhel9-container" \
      name="openshift-pipelines/pipelines-results-retention-policy-agent-rhel9" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Results retention policy agent" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Results retention policy agent" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Results retention policy agent" \
      io.k8s.description="Red Hat OpenShift Pipelines Results retention policy agent" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/results-retention-policy-agent"]

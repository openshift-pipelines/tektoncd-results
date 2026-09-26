ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:latest@sha256:0a4666f7a4eb0644c97a73cba198eb268691b270d97831822689e7a2088f87be
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal@sha256:8ebe2ad8fdf3cab3e5a53c1edc69194c98209cfadab24b884f4ad9ebcf7bbbfc

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/results
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/results-api \
    ./cmd/api

FROM $RUNTIME
ARG VERSION=1.24

ENV API=/usr/local/bin/results-api \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/results-api ${API}
COPY --from=builder /tmp/results-api ${KO_APP}/api
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-results-api-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.24::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-results api" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-results api" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-results api" \
    io.openshift.tags="tekton,openshift,tektoncd-results,api" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-results-api-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-results api" \
    version="v1.24.1"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/results-api"]

ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:9.7-1778171507
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:6fc28bcb6776e387d7a35a2056d9d2b985dc4e26031e98a2bd35a7137cd6fd71

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/results
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -tags strictfipsruntime -v -o /tmp/openshift-pipelines-results-watcher \
    ./cmd/watcher

FROM $RUNTIME
ARG VERSION=1.18

ENV WATCHER=/usr/local/bin/openshift-pipelines-results-watcher \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/openshift-pipelines-results-watcher ${WATCHER}
COPY --from=builder /tmp/openshift-pipelines-results-watcher ${KO_APP}/watcher
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-results-watcher-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.18::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    io.openshift.tags="tekton,openshift,tektoncd-results,watcher" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-results-watcher-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    version="v1.18.0"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/openshift-pipelines-results-watcher"]

ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:latest@sha256:6f246e8913d082df463b62a74c72f0d2b410583e1b2ac48add39cd7ede59ce62
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal@sha256:5ed244b62bbf4095080144d9d35eb8fcd3d39a9801f94aadd63b9d10978a01ae

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/results
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/openshift-pipelines-results-watcher \
    ./cmd/watcher
RUN /bin/sh -c 'echo $CI_RESULTS_UPSTREAM_COMMIT > /tmp/HEAD'

FROM $RUNTIME
ARG VERSION=1.24

ENV WATCHER=/usr/local/bin/openshift-pipelines-results-watcher \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/openshift-pipelines-results-watcher ${WATCHER}
COPY --from=builder /tmp/openshift-pipelines-results-watcher ${KO_APP}/watcher
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-results-watcher-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.24::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    io.openshift.tags="tekton,openshift,tektoncd-results,watcher" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-results-watcher-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-results watcher" \
    version="v1.24.2"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/openshift-pipelines-results-watcher"]

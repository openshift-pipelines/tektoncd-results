ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:14f14e03d68f7fd5f2b18a13478b6b127c341b346c86b6e0b886ed2b7573b8e0

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
RUN /bin/sh -c 'echo $CI_RESULTS_UPSTREAM_COMMIT > /tmp/HEAD'

FROM $RUNTIME

ENV WATCHER=/usr/local/bin/openshift-pipelines-results-watcher \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/openshift-pipelines-results-watcher ${WATCHER}
COPY --from=builder /tmp/openshift-pipelines-results-watcher ${KO_APP}/watcher
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-results-watcher-rhel-8-container" \
      name="openshift-pipelines/pipelines-results-watcher-rhel8" \
      version="${CI_CONTAINER_VERSION}" \
      summary="Red Hat OpenShift Pipelines Results Watcher" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Results Watcher" \
      io.openshift.tags="results,tekton,openshift,watcher"  \
      io.k8s.description="Red Hat OpenShift Pipelines Results Watcher" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Results Watcher"

RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/openshift-pipelines-results-watcher"]

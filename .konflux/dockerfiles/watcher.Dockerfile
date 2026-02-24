ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.24
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:c7d44146f826037f6873d99da479299b889473492d3c1ab8af86f08af04ec8a0

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
ARG VERSION=results-1.21

ENV WATCHER=/usr/local/bin/openshift-pipelines-results-watcher \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/openshift-pipelines-results-watcher ${WATCHER}
COPY --from=builder /tmp/openshift-pipelines-results-watcher ${KO_APP}/watcher
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-results-watcher-rhel9-container" \
      name="openshift-pipelines/pipelines-results-watcher-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Results Watcher" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Results Watcher" \
      io.openshift.tags="results,tekton,openshift,watcher"  \
      io.k8s.description="Red Hat OpenShift Pipelines Results Watcher" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Results Watcher" \
      cpe="cpe:/a:redhat:openshift_pipelines:1.21::el9"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/openshift-pipelines-results-watcher"]

ARG GO_BUILDER=registry.access.redhat.com/ubi10/go-toolset:latest@sha256:5d2ab83e88506afee6bcc909fdab425ab979725ab30d6ad43a02aaa77e2258ff
ARG UBI_RUNTIME=registry.access.redhat.com/ubi10/ubi-minimal:latest@sha256:ab67cd02caf8706e34a695a1432ebe965934f6128ec352a6c3f4048b43a4fb5e

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

FROM $UBI_RUNTIME
ARG VERSION=nightly

ENV API=/usr/local/bin/results-api \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/results-api ${API}
COPY --from=builder /tmp/results-api ${KO_APP}/api
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-results-api-rhel10-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:nightly::el10" \
    description="Red Hat OpenShift Pipelines tektoncd-results api" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-results api" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-results api" \
    io.openshift.tags="tekton,openshift,tektoncd-results,api" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-results-api-rhel10" \
    summary="Red Hat OpenShift Pipelines tektoncd-results api" \
    version="nightly"

# ubi10/ubi-minimal does not ship shadow-utils, which provides groupadd/useradd
RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/usr/local/bin/results-api"]

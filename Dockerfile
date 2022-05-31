# Copyright 2020 ChainSafe Systems
# SPDX-License-Identifier: LGPL-3.0-only

FROM  golang:1.18-stretch AS builder
ADD . /src
WORKDIR /src
RUN go mod download
RUN cd cmd/chainbridge && go build -o ../../bridge .
RUN cd ../..

ENTRYPOINT ["./bridge"]

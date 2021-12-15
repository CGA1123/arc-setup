FROM golang:1.17-bullseye AS gobuilder

WORKDIR /app
COPY . .

RUN go build -o /setup -mod vendor ./cmd/setup

FROM ubuntu:20.04

COPY identities identities
RUN apt-get update

RUN apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  vim \
  software-properties-common

RUN apt-key add identities/terraform.asc
RUN apt-key add identities/microsoft.asc
RUN apt-key add identities/gh-cli.asc
RUN apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
RUN apt-add-repository "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main"
RUN apt-add-repository "deb [arch=amd64] https://cli.github.com/packages $(lsb_release -cs) main"
RUN apt-get update
RUN apt-get install -y terraform='1.1.0' azure-cli='2.31.0-1~focal' gh='2.3.0'

COPY --from=gobuilder /setup /usr/local/bin/arc-setup

RUN useradd --create-home --shell /bin/bash arc-tester
USER arc-tester

COPY --chown="arc-tester:arc-tester" profile /home/arc-tester/.profile
COPY --chown="arc-tester:arc-tester" \
  terraform/* \
  setup.sh \
  /home/arc-tester/arc-setup/

WORKDIR /home/arc-tester/arc-setup

RUN terraform init

ENTRYPOINT /bin/bash --login

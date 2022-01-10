# arc-setup

`arc-setup` is a command-line utility for quickly setting up an [Actions Runner
Controller] instance on an AKS cluster which will be provisioned.

It requires an Azure account and subscription, GitHub.com or GHES account, and
an NGROK account.

It will walk you through the process of configuring `actions-runner-controller`
with a default configuration, create the GitHub App that
`actions-runner-controller` will use to manage your ephemeral runners and
listen to autoscaling events via webhooks.

Get started with the published docker image:

```console
$ docker run ghcr.io/cga1123/arc-setup:latest
```

Or, build it yourself:

```console
$ docker build -t arc-setup .
```

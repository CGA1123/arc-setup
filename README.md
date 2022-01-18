# arc-setup

`arc-setup` gets you from zero to one with `actions-runner-controller` runner
in a Codespace via `minikube`.

For previous version of `arc-setup` which provisioned an AKS cluster, see the
`azure` branch.

It will automate the process of provisioning your `minikube` cluster,
installing the required dependencies from `actions-runner-controller`
(`ingress-nginx`, `cert-manager`), configure and install a GitHub App to
manage runners and listen to webhook events onto an organisation, and install a
default `HorizontalrunnerAutoScaler` powered by the `actions-runner-controller`
webhook server.

## Getting started

Start a codespace via the UI or command line

e.g.

```console
$ gh cs ssh -c $(gh cs create -r CGA1123/arc-setup -b main)
```

and run the install script!

```console
$ ./script/install.sh
```

This will output a sample workflow YAML that you can use to run a job on your
newly created ARC cluster!


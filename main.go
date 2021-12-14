package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/AlecAivazis/survey/v2"
	"github.com/AlecAivazis/survey/v2/terminal"
)

const VarFileName = "terraform.tfvars.json"

type TfVars struct {
	SubscriptionID   string `json:"subscription_id"`
	ResourceGroup    string `json:"resource_group"`
	Location         string `json:"location"`
	DNSPrefix        string `json:"dns_prefix"`
	LetsEncryptEmail string `json:"letsencrypt_email"`
	EnterpriseURL    string `json:"enterprise_url,omitempty"`
	AppID            string `json:"app_id"`
	InstallationID   string `json:"installation_id"`
	PrivateKey       string `json:"private_key"`
	WebhookSecret    string `json:"webhook_secret"`
	Organization     string `json:"organization"`
	RunnerGroup      string `json:"runner_group"`
}

// TODO: check for az cli + terraform (?)
func main() {
	isGHES := &survey.Confirm{
		Message: "Are you using a GitHub Enterprise Server (GHES) installation?",
		Help:    "If configuring Actions Runner Controller for a GitHub Enterprise Server installation, we'll need to know the URL for that installation.",
	}

	ghesURL := &survey.Input{
		Message: "What is the URL for your GitHub Enteprise Server (GHES) installation?:",
		Help:    "This is the URL for the GHES instance you want to configure Actions Runner Controller against.",
	}

	azureSubscriptionsID := &survey.Input{
		Message: "What Microsoft Azure Subscription ID do you want to use to create resources?",
		Help:    "This is the subscriptions ID that will be used by Terraform to provision a new Azure Kubernetes Service (AKS) Cluster to deploy Actions Runner Controller and related require resources to.",
	}

	azureResourceGroup := &survey.Input{
		Message: "What should we call the Azure Resource Group to use for provisioning the AKS cluster?",
		Help:    "This should be a valid unused Azure Resource Group Name which will be created.",
	}

	azureLocation := &survey.Select{
		Message: "In which Azure Region should we provision resources?",
		Options: []string{"uksouth", "ukwest", "westeurope", "northeurope"}, // TODO
	}

	azureDNS := &survey.Input{
		Message: "What custom DNS prefix should be used for the webhook server domain?",
		Help:    "This prefix must be unique and will form part of an Azure provided domain name of form `<prefix>.<location>.cloudapp.azure.com`.",
	}

	letEncrypt := &survey.Input{
		Message: "What email address should be used to get a Let's Encrypt TLS Certificate for the webhook server?",
		Help:    "In order to create a secure ingress route to the Actions Runner Controller Webhook server, we need to generate a TLS certificate for it via Let's Encrypt. We need an email address in order to do that!",
	}

	githubOrg := &survey.Input{
		Message: "GitHub Org:",
		Help:    "TODO",
	}

	runnerGroup := &survey.Input{
		Message: "GitHub Actions Runner Group:",
		Help:    "TODO",
	}

	appID := &survey.Input{
		Message: "Actions Runner Controller GitHub App ID:",
		Help:    "TODO",
	}

	installationID := &survey.Input{
		Message: "Actions Runner Controller GitHub App Installation ID:",
		Help:    "TODO",
	}

	webhookSecret := &survey.Password{
		Message: "Actions Runner Controller GitHub App webhook secret:",
		Help:    "TODO",
	}

	privateKey := &survey.Input{
		Message: "Actions Runner Controller GitHub App Private Key PEM file:",
		Help:    "TODO",
		Suggest: func(toComplete string) []string {
			files, _ := filepath.Glob(toComplete + "*")
			return files
		},
	}

	vars := TfVars{}

	// Azure
	ask(azureSubscriptionsID, &vars.SubscriptionID)
	ask(azureResourceGroup, &vars.ResourceGroup)
	ask(azureLocation, &vars.Location)
	ask(azureDNS, &vars.DNSPrefix)

	// LetsEncrypt Email
	ask(letEncrypt, &vars.LetsEncryptEmail)

	// GitHub
	ghes := false
	ask(isGHES, &ghes)
	if ghes {
		ask(ghesURL, &vars.EnterpriseURL)
	}

	// TODO: get organization slug
	// https://github.com/settings/organizations
	ask(githubOrg, &vars.Organization)
	// TODO: get runner group
	ask(runnerGroup, &vars.RunnerGroup)
	// https://github.com/organizations/CGA1123-but-as-an-org/settings/actions/runner-groups
	// TODO: get application ID
	// https://github.com/organizations/CGA1123-but-as-an-org/settings/apps
	ask(appID, &vars.AppID)

	// TODO: get application installation ID
	ask(installationID, &vars.InstallationID)
	//
	// TODO: get private key (or path to it?)
	ask(webhookSecret, &vars.WebhookSecret)
	// TODO: get webhook secret?
	ask(privateKey, &vars.PrivateKey)

	b := &bytes.Buffer{}
	enc := json.NewEncoder(b)
	enc.SetIndent("", "    ")
	if err := enc.Encode(vars); err != nil {
		fmt.Errorf("error encoding to json: %v", VarFileName, err)
		os.Exit(1)
	}

	if err := os.WriteFile(VarFileName, b.Bytes(), 0600); err != nil {
		fmt.Errorf("error writing %v: %v", VarFileName, err)
		os.Exit(1)
	}
}

func ask(p survey.Prompt, t interface{}) {
	handleSurveryErr(survey.AskOne(p, t, survey.WithValidator(survey.Required)))
}

func handleSurveryErr(err error) {
	if err == nil {
		return
	}

	if errors.Is(err, terminal.InterruptErr) {
		os.Exit(0)
	} else {
		fmt.Printf("err: %v", err)
		os.Exit(1)
	}
}

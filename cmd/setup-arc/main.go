package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/url"
	"os"

	"github.com/AlecAivazis/survey/v2"
	"github.com/AlecAivazis/survey/v2/terminal"
)

const VarFileName = "terraform.tfvars.json"
const SubscriptionFile = "login.json"
const UserFile = "user.json"

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

	privateKey := &survey.Editor{
		Message: "Actions Runner Controller GitHub App Private Key:",
		Help:    "TODO",
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
		ask(ghesURL, &vars.EnterpriseURL, survey.WithValidator(urlValidator()))
	}

	baseURL := "https://github.com"
	if ghes {
		parsed, err := url.Parse(vars.EnterpriseURL)
		if err != nil {
			fmt.Printf("failed to parse enterprise url: %v", err)
			os.Exit(1)
		}

		baseURL = fmt.Sprintf("%v://%v", parsed.Scheme, parsed.Host)
	}

	fmt.Printf("ℹ You can see the GitHub Organizations you have access to here: %v/settings/organizations\n", baseURL)
	ask(githubOrg, &vars.Organization)

	fmt.Printf("ℹ You can see the GitHub Actions Runner Groups you have access to here: %v/organizations/%v/settings/actions/runner-groups\n", baseURL, vars.Organization)
	ask(runnerGroup, &vars.RunnerGroup)

	fmt.Printf("ℹ You can see the GitHub Apps you have access to here: %v/organizations/%v/settings/apps\n", baseURL, vars.Organization)
	ask(appID, &vars.AppID)
	ask(webhookSecret, &vars.WebhookSecret)

	privateKeyStr := ""
	ask(privateKey, &privateKeyStr)

	tmp, err := ioutil.TempFile("", "")
	if err != nil {
		fmt.Errorf("failed creating a temporary file: %v", err)
		os.Exit(1)
	}
	defer tmp.Close()

	if _, err := tmp.WriteString(privateKeyStr); err != nil {
		fmt.Printf("error writing to tmpfile: %v", err)
		os.Exit(1)
	}

	if err := tmp.Close(); err != nil {
		fmt.Printf("error closing tmpfile: %v", err)
		os.Exit(1)
	}

	vars.PrivateKey = tmp.Name()

	fmt.Printf("ℹ You can find the GitHub App Installation ID here: %v/organizations/%v/settings/installations\n", baseURL, vars.Organization)
	ask(installationID, &vars.InstallationID)

	b := &bytes.Buffer{}
	enc := json.NewEncoder(b)
	enc.SetIndent("", "    ")
	if err := enc.Encode(vars); err != nil {
		fmt.Printf("error encoding to json: %v\n", VarFileName, err)
		os.Exit(1)
	}

	if err := os.WriteFile(VarFileName, b.Bytes(), 0600); err != nil {
		fmt.Printf("error writing %v: %v\n", VarFileName, err)
		os.Exit(1)
	}
}

func ask(p survey.Prompt, t interface{}, opts ...survey.AskOpt) {
	handleSurveryErr(survey.AskOne(p, t, append(opts, survey.WithValidator(survey.Required))...))
}

func handleSurveryErr(err error) {
	if err == nil {
		return
	}

	if errors.Is(err, terminal.InterruptErr) {
		fmt.Println("ctrl-c")
	} else {
		fmt.Printf("err: %v\n", err)
	}
	os.Exit(1)
}

func urlValidator() survey.Validator {
	return func(answer interface{}) error {
		str, ok := answer.(string)
		if !ok {
			return fmt.Errorf("answer must be a string")
		}

		if _, err := url.Parse(str); err != nil {
			return fmt.Errorf("answer must be a url: %w", err)
		}

		return nil
	}
}

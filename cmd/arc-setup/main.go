package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"

	"github.com/AlecAivazis/survey/v2"
	"github.com/AlecAivazis/survey/v2/terminal"
)

const VarFileName = "terraform.tfvars.json"
const AzureSubscriptionFile = "azure_subscriptions.json"
const AzureEmailFile = "azure_email.txt"
const AzureLocationsFile = "azure_locations.json"
const GitHubHostFile = "github_host.txt"
const GitHubOrgsFile = "github_orgs.json"
const GitHubDotcomHost = "github.com"

type manifestHookAttributes struct {
	URL    string `json:"url"`
	Active bool   `json:"active"`
}

type manifest struct {
	Name               string                 `json:"name"`
	URL                string                 `json:"url"`
	HookAttributes     manifestHookAttributes `json:"hook_attributes"`
	RedirectURL        string                 `json:"redirect_url"`
	CallbackURLs       []string               `json:"callback_urls"`
	Description        string                 `json:"description"`
	Public             bool                   `json:"public"`
	DefaultEvents      []string               `json:"default_events"`
	DefaultPermissions map[string]string      `json:"default_permissions"`
}

type gamfPayload struct {
	TargetType string   `json:"target_type"`
	TargetSlug string   `json:"target_slug"`
	Host       string   `json:"host"`
	Manifest   manifest `json:"manifest"`
}

type TfVars struct {
	SubscriptionID   string `json:"subscription_id"`
	ResourceGroup    string `json:"resource_group"`
	Location         string `json:"location"`
	DNSPrefix        string `json:"dns_prefix"`
	LetsEncryptEmail string `json:"letsencrypt_email"`
	EnterpriseURL    string `json:"enterprise_url"`
	AppID            string `json:"app_id"`
	InstallationID   string `json:"installation_id"`
	PrivateKey       string `json:"private_key"`
	WebhookSecret    string `json:"webhook_secret"`
	Organization     string `json:"organization"`
	RunnerGroup      string `json:"runner_group"`
}

func main() {
	if err := realMain(); err != nil {
		fmt.Printf("error: %v", err)
		os.Exit(1)
	}
}

func realMain() error {
	azureSubscriptions, err := loadSubscriptions()
	if err != nil {
		return err
	}

	azureSubscriptionsNames := make([]string, 0, len(azureSubscriptions))
	for name := range azureSubscriptions {
		azureSubscriptionsNames = append(azureSubscriptionsNames, name)
	}

	azureLocations, err := loadLocations()
	if err != nil {
		return err
	}

	azureEmail, err := loadEmail()
	if err != nil {
		return err
	}

	githubHost, err := loadHost()
	if err != nil {
		return err
	}

	baseURL := "https://" + githubHost

	githubOrganizations, err := loadOrgs()
	if err != nil {
		return nil
	}
	githubOrganizationNames := make([]string, 0, len(githubOrganizations))
	for name := range githubOrganizations {
		githubOrganizationNames = append(githubOrganizationNames, name)
	}

	namePrefix, err := randomName()
	if err != nil {
		return nil
	}

	isGhes := githubHost != GitHubDotcomHost

	azureSubscriptionsID := &survey.Select{
		Message: "What Microsoft Azure Subscription ID do you want to use to create resources?",
		Help:    "This is the subscriptions ID that will be used by Terraform to provision a new Azure Kubernetes Service (AKS) Cluster to deploy Actions Runner Controller and related require resources to.",
		Options: azureSubscriptionsNames,
	}

	azureLocation := &survey.Select{
		Message: "In which Azure Region should we provision resources?",
		Options: azureLocations,
	}

	letEncrypt := &survey.Input{
		Message: "What email address should be used to get a Let's Encrypt TLS Certificate for the webhook server?",
		Default: azureEmail,
		Help:    "In order to create a secure ingress route to the Actions Runner Controller Webhook server, we need to generate a TLS certificate for it via Let's Encrypt. We need an email address in order to do that!",
	}

	githubOrg := &survey.Select{
		Message: "GitHub Org:",
		Help:    "This is the GitHub Organization which the Actions Runner Controller will manager Self-Hosted Runners on.",
		Options: githubOrganizationNames,
	}

	// TODO: autocreate
	runnerGroup := &survey.Input{
		Message: "GitHub Actions Runner Group:",
		Help:    "This is the GitHub Actions Self-Hosted Runner Group that Actions Runner Controller will manager.",
	}

	installationID := &survey.Input{
		Message: "Actions Runner Controller GitHub App Installation ID:",
	}

	vars := TfVars{}
	vars.ResourceGroup = namePrefix
	vars.DNSPrefix = namePrefix

	if isGhes {
		vars.EnterpriseURL = baseURL
	}

	// Azure
	subName := ""
	if err := ask(azureSubscriptionsID, &subName); err != nil {
		return err
	}
	vars.SubscriptionID = azureSubscriptions[subName]

	if err := ask(azureLocation, &vars.Location); err != nil {
		return err
	}
	if err := ask(letEncrypt, &vars.LetsEncryptEmail); err != nil {
		return err
	}
	if err := ask(githubOrg, &vars.Organization); err != nil {
		return err
	}
	orgID := githubOrganizations[vars.Organization]

	hookUrl := fmt.Sprintf("https://%v.%v.cloudapp.azure.com", randomName, vars.Location)
	manifestPayload, err := json.Marshal(buildGamfPayload(namePrefix, vars.Organization, githubHost, hookUrl))
	if err != nil {
		return fmt.Errorf("failed to encode gamf payload: %w", err)
	}

	res, err := http.DefaultClient.Post("https://gamf.svc.bissy.io/start", "application/json", bytes.NewReader(manifestPayload))
	if err != nil {
		return fmt.Errorf("failed to make request to https://gamf.svc.bissy.io/start: %w", err)
	}

	if res.StatusCode > 399 || res.StatusCode < 200 {
		return fmt.Errorf("failed to make request, got status: %v", res.StatusCode)
	}

	var startResponse struct {
		Key string `json:"key"`
		URL string `json:"url"`
	}
	if err := json.NewDecoder(res.Body).Decode(&startResponse); err != nil {
		return fmt.Errorf("failed to decode start body: %w", err)
	}

	fmt.Printf("ℹ Please continue to this URL to create a new GitHub Application for Actions Runner Controller: %v\n", startResponse.URL)
	fmt.Printf("ℹ Press the enter key once you have finished creating the application.\n")
	input := bufio.NewScanner(os.Stdin)
	input.Scan()

	fmt.Printf("ℹ Polling for completiong of App creation token\n")
	var doneResponse struct {
		Code string `json:"code"`
	}
	for i := 0; i < 10; i++ {
		res, err := http.DefaultClient.Post("https://gamf.svc.bissy.io/code/"+startResponse.Key, "", nil)
		if err != nil {
			return fmt.Errorf("failed to make request to https://gamf.svc.bissy.io/start: %w", err)
		}

		if res.StatusCode > 399 || res.StatusCode < 200 {
			continue
		}

		if err := json.NewDecoder(res.Body).Decode(&doneResponse); err != nil {
			return fmt.Errorf("error decoding response: %w", err)
		}
	}
	if doneResponse.Code == "" {
		return fmt.Errorf("failed to fetch exchange token for app creation")
	}

	fmt.Printf("ℹ Converting manifest into App\n")
	var conversionResponse struct {
		ID            int    `json:"id"`
		Slug          string `json:"slug"`
		WebhookSecret string `json:"webhook_secret"`
		PrivateKey    string `json:"pem"`
	}
	for i := 0; i < 10; i++ {
		var url string
		if isGhes {
			url = "https://" + githubHost + "/api/v3/app-manifests/" + doneResponse.Code + "/conversions"
		} else {
			url = "https://api.github.com/app-manifests/" + doneResponse.Code + "/conversions"
		}
		res, err := http.DefaultClient.Post(url, "", nil)
		if err != nil {
			return fmt.Errorf("failed to make request to GitHub: %w", err)
		}

		if res.StatusCode > 399 || res.StatusCode < 200 {
			continue
		}

		if err := json.NewDecoder(res.Body).Decode(&conversionResponse); err != nil {
			return fmt.Errorf("error decoding response: %w", err)
		}
	}
	if conversionResponse.ID == 0 {
		return fmt.Errorf("failed to convert app manifest into application")
	}

	fmt.Printf("ℹ App Created!\n")
	fmt.Printf("ID: %v\n", conversionResponse.ID)
	fmt.Printf("Slug: %v\n", conversionResponse.Slug)

	vars.WebhookSecret = conversionResponse.WebhookSecret
	vars.AppID = strconv.Itoa(conversionResponse.ID)

	tmp, err := ioutil.TempFile("", "")
	if err != nil {
		return fmt.Errorf("failed creating a temporary file: %v", err)
	}
	defer tmp.Close()

	if _, err := tmp.WriteString(conversionResponse.PrivateKey); err != nil {
		return fmt.Errorf("error writing to tmpfile: %v", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("error closing private key file")
	}

	vars.PrivateKey = tmp.Name()

	var appsURL string
	if isGhes {
		appsURL = baseURL + "/github-apps"
	} else {
		appsURL = baseURL + "/apps"
	}

	fmt.Printf("ℹ Please install the newly created GitHub App Installation ID onto %v here: %v/%v/installations/new/permissions?target_id=%v\n", vars.Organization, appsURL, conversionResponse.Slug, orgID)
	fmt.Printf("ℹ After installation, you should be redirected to a URL that looks like this: %v/organizations/%v/settings/installations/{id}\n", baseURL, vars.Organization)
	fmt.Printf("ℹ Please enter the {id} of the installation below.\n")
	if err := ask(installationID, &vars.InstallationID); err != nil {
		return err
	}

	fmt.Printf("ℹ We need to tell Actions Runner Controller which Runner Group to create runners in...\n")
	fmt.Printf("ℹ You can see and create new GitHub Actions Runner Groups here: %v/organizations/%v/settings/actions/runners\n", baseURL, vars.Organization)
	if err := ask(runnerGroup, &vars.RunnerGroup); err != nil {
		return err
	}

	b := &bytes.Buffer{}
	enc := json.NewEncoder(b)
	enc.SetIndent("", "    ")
	if err := enc.Encode(vars); err != nil {
		return fmt.Errorf("error encoding to json: %\n", err)
	}

	if err := os.WriteFile(VarFileName, b.Bytes(), 0600); err != nil {
		return fmt.Errorf("error writing %v: %w\n", VarFileName, err)
	}

	return nil
}

func ask(p survey.Prompt, t interface{}, opts ...survey.AskOpt) error {
	return handleSurveryErr(survey.AskOne(p, t, append(opts, survey.WithValidator(survey.Required))...))
}

func handleSurveryErr(err error) error {
	if err == nil {
		return nil
	}

	if errors.Is(err, terminal.InterruptErr) {
		return fmt.Errorf("ctrl-c")
	} else {
		return err
	}
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

func buildGamfPayload(appName, org, ghHost, hookUrl string) gamfPayload {
	return gamfPayload{
		TargetType: "org",
		TargetSlug: org,
		Host:       ghHost,
		Manifest: manifest{
			Name:          appName,
			URL:           "https://github.com/actions-runner-controller/actions-runner-controller",
			Description:   "Autocreated Actions Runner Controller Application",
			Public:        false,
			CallbackURLs:  []string{},
			DefaultEvents: []string{"workflow_run", "check_run"},
			DefaultPermissions: map[string]string{
				"organization_self_hosted_runners": "write",
				"actions":                          "read",
				"checks":                           "read",
			},
			HookAttributes: manifestHookAttributes{
				URL:    hookUrl,
				Active: true,
			},
		},
	}
}

func randomName() (string, error) {
	bytes := make([]byte, 8)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("error generating token: %w", err)
	}

	return "arc-setup-" + hex.EncodeToString(bytes), nil
}

func loadEmail() (string, error) {
	b, err := ioutil.ReadFile(AzureEmailFile)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}

	return strings.TrimSpace(string(b)), nil
}

func loadHost() (string, error) {
	b, err := ioutil.ReadFile(GitHubHostFile)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}

	return strings.TrimPrefix(strings.TrimSpace(string(b)), "api."), nil
}

func loadSubscriptions() (map[string]string, error) {
	b, err := ioutil.ReadFile(AzureSubscriptionFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	var subs []struct {
		Name string `json:"name"`
		ID   string `json:"id"`
	}

	if err := json.Unmarshal(b, &subs); err != nil {
		return nil, fmt.Errorf("error unmarshaling subs: %w", err)
	}

	subMap := make(map[string]string, len(subs))
	for _, sub := range subs {
		subMap[sub.Name] = sub.ID
	}

	return subMap, nil
}

func loadLocations() ([]string, error) {
	b, err := ioutil.ReadFile(AzureLocationsFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	var locs []struct {
		Name string `json:"name"`
	}

	if err := json.Unmarshal(b, &locs); err != nil {
		return nil, fmt.Errorf("error unmarshaling locations: %w", err)
	}

	locations := make([]string, len(locs))
	for i, loc := range locs {
		locations[i] = loc.Name
	}

	return locations, nil
}

func loadOrgs() (map[string]int, error) {
	b, err := ioutil.ReadFile(GitHubOrgsFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	var orgs []struct {
		Role         string `json:"role"`
		State        string `json:"state"`
		Organization struct {
			ID    int    `json:"id"`
			Login string `json:"login"`
		} `json:"organization"`
	}

	if err := json.Unmarshal(b, &orgs); err != nil {
		return nil, fmt.Errorf("error unmarshaling orgs: %w", err)
	}

	organizations := map[string]int{}
	for _, org := range orgs {
		if org.Role != "admin" {
			continue
		}

		if org.State != "active" {
			continue
		}

		organizations[org.Organization.Login] = org.Organization.ID
	}

	return organizations, nil
}

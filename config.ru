require "pry"
require "sinatra"
require "redis"
require "securerandom"
require "json"

# Flow: request a flow to start
# -> generate secret token (state)
# Return payload of { "url": "https://host/redirect/:state" }
# User visits link
# Redirect to a page that does a browser POST
# -> redirects to github
# -> github post back
# -> store STATE -> CODE

class App < Sinatra::Base
  def initialize
    super

    @redis = Redis.new
  end

  INITIATE="i"
  STATE="s"

  def home(org, state)
    <<~HTML
    <html>
      <body>
        <form id="new-app-form" action="https://github.com/organizations/#{org}/settings/apps/new?state=#{state}" method="post">
         <input type="hidden" name="manifest" id="manifest">
        </form>

        <script>
         input = document.getElementById("manifest")
         input.value = JSON.stringify(
           {
             "name": "ARC Sample Application",
             "url": "https://github.com/actions-runner-controller/actions-runner-controller",
             "hook_attributes": { "url": "https://760d-82-14-133-233.ngrok.io", "active": true },
             "redirect_url": "https://4e3a-82-14-133-233.ngrok.io/callback",
             "callback_urls": [ "https://760d-82-14-133-233.ngrok.io" ],
             "public": false,
             "default_permissions": { "organization_self_hosted_runners": "write", "actions": "read", "checks": "read" },
             "default_events": [ "check_run", "workflow_job" ]
           }
         )

         form = document.getElementById("new-app-form").submit()
         form.submit()
        </script>
      </body>
    </html>
    HTML
  end

  get '/start' do
    initial = SecureRandom.uuid
    state = SecureRandom.uuid

    @redis.setex([INITIATE, initial].join(":"), 60 * 10, state)

    status 200
    headers "Content-Type" => "application/json"

    { "url" => "https://4e3a-82-14-133-233.ngrok.io/#{initial}", "state" => state }.to_json
  end

  get '/redirect/:initial/:org' do
    initial = params["initial"]
    state = @redis.getdel([INITIATE, initial].join(":"))

    status 200
    headers "Content-Type" => "text/html"

    home(params['org'], state)
  end

  get '/callback' do
    @redis.setex([STATE, params["state"]].join(":"), 60 * 10, params["code"])

    status 302
    headers "Location" => "/done"
  end

  get "/done" do
    status 200
    headers "Content-Type" => "application/json"

    {"message" => "done!"}.to_json
  end

  get "/code/:state" do
    code = @redis.getdel(params['state'])
    status 200
    headers "Content-Type" => "application/json"

    {"code" => code}.to_json
  end
end


run App

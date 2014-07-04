require 'rubygems'
require 'octokit'
require 'yaml'
require 'sinatra'
require 'tutter/action'
require 'json'

class Tutter < Sinatra::Base
  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
    set :config, YAML.load_file('conf/tutter.yaml')
    set :bind, '0.0.0.0'
  end

  configure :test do
    set :config, YAML.load_file('conf/tutter.yaml')
    set :bind, '0.0.0.0'
  end

  configure :production do
    set :config, YAML.load_file('conf/tutter.yaml')
  end

  # Return project settings from config
  def get_project_settings project
    puts settings.config['projects'].inspect
    settings.config['projects'].each do |p|
      return p if p['name'] == project
    end
    false
  end

  post '/' do
    # Github send data in JSON format, parse it!
    begin
      data = JSON.parse request.body.read
    rescue JSON::ParserError
      error(400, 'POST data is not JSON')
    end
    project = data['repository']['full_name'] || error(400, 'Bad request')

    conf = get_project_settings(project) || error(404, 'Project does not exist in tutter.conf')

    # Setup octokit endpoints
    Octokit.configure do |c|
      c.api_endpoint = conf['github_api_endpoint']
      c.web_endpoint = conf['github_site']
    end

    client = Octokit::Client.new :access_token => ENV[conf['access_token_env_var']]

    # Load action
    action = Action.create(conf['action'],
                                 conf['action_settings'],
                                 client,
                                 project,
                                 data)

    status_code, message = action.run
    return status_code, message
  end

  get '/' do
    'Source code and documentation at https://github.com/jhaals/tutter'
  end

  run! if app_file == $0
end

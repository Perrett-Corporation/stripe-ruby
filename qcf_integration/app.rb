require 'sinatra'
require 'json'
require_relative 'db'

configure do
  set :bind, '0.0.0.0'
  set :port, ENV['PORT'] || 4567
end

helpers do
  def record_audit(event_type, actor, details)
    DB[:audit_logs].insert(event_type: event_type, actor: actor || 'system', details: details.to_json, created_at: Time.now)
  end

  def protected!
    return if ENV['ADMIN_USER'].nil?
    auth ||= Rack::Auth::Basic::Request.new(request.env)
    unless auth.provided? && auth.basic? && auth.credentials && auth.credentials == [ENV['ADMIN_USER'], ENV['ADMIN_PASS']]
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, 'Not authorized'
    end
  end
end

post '/ideas' do
  payload = JSON.parse(request.body.read)
  id = DB[:ideas].insert(title: payload['title'], description: payload['description'], source: payload['source'], created_at: Time.now)
  record_audit('idea_created', payload['source'], payload)
  content_type :json
  status 201
  {id: id}.to_json
end

post '/tasks' do
  payload = JSON.parse(request.body.read)
  id = DB[:tasks].insert(title: payload['title'], description: payload['description'], status: 'open', assignee: payload['assignee'], created_at: Time.now, updated_at: Time.now)
  record_audit('task_created', payload['creator'] || 'unknown', payload)

  # Notify configured websites
  notify_sites = [ENV['PERRETT_WEBHOOK_URL'], ENV['SUPREGTECH_WEBHOOK_URL']].compact
  notify_sites.each do |url|
    begin
      Thread.new do
        require 'net/http'
        uri = URI(url)
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = {event: 'task_created', task_id: id, title: payload['title'], description: payload['description']}.to_json
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
      end
    rescue => e
      record_audit('notify_failure', 'system', {url: url, error: e.message})
    end
  end

  content_type :json
  status 201
  {id: id}.to_json
end

post '/consent' do
  payload = JSON.parse(request.body.read)
  record_audit('consent_recorded', payload['user'] || 'unknown', payload)
  status 204
end

get '/admin_data' do
  protected!
  ideas = DB[:ideas].order(:created_at).all
  tasks = DB[:tasks].order(:created_at).all
  audits = DB[:audit_logs].order(Sequel.desc(:created_at)).limit(200).all
  content_type :json
  {ideas: ideas, tasks: tasks, audits: audits}.to_json
end

get '/admin' do
  protected!
  send_file File.join(settings.public_folder || File.dirname(__FILE__), 'admin.html')
end

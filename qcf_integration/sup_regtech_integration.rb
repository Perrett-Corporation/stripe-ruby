require 'net/http'
require 'json'

QCF_TASKS_URL = ENV['QCF_TASKS_URL'] || 'http://localhost:4567/tasks'

def create_task(title, description, assignee=nil, creator='sup_regtech')
  uri = URI(QCF_TASKS_URL)
  req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  req.body = {title: title, description: description, assignee: assignee, creator: creator}.to_json
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
  res
end

if __FILE__ == $0
  p create_task('Review regulatory rule X', 'Assess impact on clients', 'alice')
end

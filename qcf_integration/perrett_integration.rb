require 'net/http'
require 'json'

# Example: send an idea to QCF service
QCF_URL = ENV['QCF_URL'] || 'http://localhost:4567/ideas'

def send_idea(title, description, source='perrett_site')
  uri = URI(QCF_URL)
  req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  req.body = {title: title, description: description, source: source}.to_json
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
  res
end

# Example usage
if __FILE__ == $0
  p send_idea('Improve KYC workflow', 'Add clearer steps for onboarding')
end

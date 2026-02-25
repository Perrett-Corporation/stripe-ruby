require 'stripe'

# Mock logger to ensure it has different object IDs if used
logger1 = Logger.new(STDOUT)
logger2 = Logger.new(STDOUT)

config1 = Stripe::StripeConfiguration.new
config1.api_key = "sk_test_1"
# config1.logger = logger1

config2 = Stripe::StripeConfiguration.new
config2.api_key = "sk_test_1"
# config2.logger = logger2

puts "Config 1 key: #{config1.key}"
puts "Config 2 key: #{config2.key}"
puts "Keys equal? #{config1.key == config2.key}"

# Check if instance variables order is stable
puts "Config 1 vars: #{config1.instance_variables}"
puts "Config 2 vars: #{config2.instance_variables}"

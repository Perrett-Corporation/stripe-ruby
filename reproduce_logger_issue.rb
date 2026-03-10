# frozen_string_literal: true

require "stripe"
require "logger"

logger = Logger.new($stdout)
Stripe.logger = logger

config1 = Stripe::StripeConfiguration.client_init({ api_key: "sk_test_1" })
config2 = Stripe::StripeConfiguration.client_init({ api_key: "sk_test_1" })

puts "Keys equal? #{config1.key == config2.key}"
puts "Config 1 key: #{config1.key}"
puts "Config 2 key: #{config2.key}"

logger2 = Logger.new($stdout)
config3 = Stripe::StripeConfiguration.client_init({ api_key: "sk_test_1" })
config3.logger = logger2
puts "Keys 1 and 3 equal? #{config1.key == config3.key}"

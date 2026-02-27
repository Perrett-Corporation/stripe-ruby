# frozen_string_literal: true

require "stripe"

# This example demonstrates how you might structure a backend handler
# for a voice assistant (like Amazon Alexa or Google Assistant) that
# uses the stripe-ruby library to perform actions based on voice intents.

# Configure Stripe to use stripe-mock for testing
Stripe.api_key = ENV["STRIPE_SECRET_KEY"] || "sk_test_123"
Stripe.api_base = ENV["STRIPE_API_BASE"] || "http://localhost:12111"

# Simulated NLU (Natural Language Understanding) Intent Request
# In a real application, this would come from your voice assistant platform
# via a webhook (e.g., an HTTP POST request to your server).
def handle_voice_intent(intent_name, parameters)
  case intent_name
  when "CheckBalance"
    check_balance
  when "CreatePayment"
    amount = parameters[:amount]
    currency = parameters[:currency] || "usd"
    create_payment(amount, currency)
  else
    "I'm sorry, I didn't understand that command."
  end
end

def check_balance
  # Fetch the balance using the Stripe API
  balance = Stripe::Balance.retrieve

  # Format the response for the voice assistant to speak
  available_usd = balance.available.find { |b| b.currency == "usd" }
  if available_usd
    amount_in_dollars = available_usd.amount / 100.0
    "Your current available Stripe balance is #{amount_in_dollars} dollars."
  else
    "You do not have a USD balance available."
  end
rescue Stripe::StripeError => e
  "There was an error checking your balance: #{e.message}"
end

def create_payment(amount, currency)
  # Create a PaymentIntent using the Stripe API
  payment_intent = Stripe::PaymentIntent.create(
    amount: amount,
    currency: currency,
    payment_method_types: ["card"]
  )

  amount_formatted = amount / 100.0
  "Successfully created a payment intent for #{amount_formatted} #{currency.upcase}. " \
    "The payment intent ID is #{payment_intent.id}."
rescue Stripe::StripeError => e
  "There was an error creating the payment: #{e.message}"
end

if $PROGRAM_NAME == __FILE__
  puts "--- Testing Simulated Voice Intents ---"
  puts

  puts "User: 'What is my Stripe balance?'"
  puts "NLU Engine: Translates to 'CheckBalance' intent"
  response = handle_voice_intent("CheckBalance", {})
  puts "Voice Assistant: \"#{response}\""
  puts

  puts "User: 'Create a payment for 50 dollars'"
  puts "NLU Engine: Translates to 'CreatePayment' intent with amount=5000, currency='usd'"
  response = handle_voice_intent("CreatePayment", { amount: 5000, currency: "usd" })
  puts "Voice Assistant: \"#{response}\""
  puts

  puts "User: 'Do a barrel roll'"
  puts "NLU Engine: Translates to 'UnknownIntent'"
  response = handle_voice_intent("UnknownIntent", {})
  puts "Voice Assistant: \"#{response}\""
  puts
end

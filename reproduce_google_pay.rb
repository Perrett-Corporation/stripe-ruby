require "stripe"

Stripe.api_key = "sk_test_123"
Stripe.api_base = "http://localhost:12111"
# Attempt to create a payment method using Google Pay like params
begin
  puts "Creating PaymentMethod with google_pay..."
  # NOTE: verify the correct API usage for Google Pay
  # In many integrations, Google Pay returns a token which is used as source or card.

  # Trying a direct google_pay type if it exists (it likely doesn't in this version, usually it's inside card)
  # But let's try to trigger a 403 or 404

  pm = Stripe::PaymentMethod.create({
    type: "card",
    card: {
      # Trying to put something that might look like Google Pay or trigger an error
      token: "tok_google_pay_fake",
    },
    metadata: {
      google_pay: "true",
    },
  })
  puts "PaymentMethod created: #{pm.id}"
rescue Stripe::StripeError => e
  puts "Caught StripeError: #{e.class}"
  puts "Message: #{e.message}"
  puts "Code: #{e.code}" if e.respond_to?(:code)
  puts "HTTP Status: #{e.http_status}" if e.respond_to?(:http_status)
end

require File.expand_path("../test_helper", __dir__)

module Stripe
  class GooglePayErrorTest < Test::Unit::TestCase
    should "raise PermissionError with hint on 403 for Google Pay" do
      error = {
        code: "permission_error",
        message: "Google Pay is not enabled",
      }

      # We need to trigger a request. Any request will do if we mock execution.
      # But APIRequestor logic is inside execute_request's caller usually?
      # No, APIRequestor#request calls specific_api_error

      # Let's mock the network layer instead to return 403

      stub_request(:get, "#{Stripe.api_base}/v1/charges")
        .to_return(body: JSON.generate({ error: error }), status: 403)

      e = assert_raises Stripe::PermissionError do
        Stripe::Charge.list
      end

      assert_match(/Google Pay is not enabled \(Check that your Google Pay integration is enabled and configured correctly\)/, e.message)
    end

    should "raise InvalidRequestError with hint on 404 for Google Pay" do
      error = {
        code: "resource_missing",
        message: "Google Pay configuration not found",
      }

      stub_request(:get, "#{Stripe.api_base}/v1/charges")
        .to_return(body: JSON.generate({ error: error }), status: 404)

      e = assert_raises Stripe::InvalidRequestError do
        Stripe::Charge.list
      end

      assert_match(/Google Pay configuration not found \(Check that your Google Pay integration is enabled and configured correctly\)/, e.message)
    end
  end
end

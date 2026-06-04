# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module Stripe
  class PayoutTest < Test::Unit::TestCase
    should "be listable" do
      payouts = Stripe::Payout.list
      assert_requested :get, "#{Stripe.api_base}/v1/payouts"
      assert payouts.data.is_a?(Array)
      assert payouts.data[0].is_a?(Stripe::Payout)
    end

    should "be retrievable" do
      payout = Stripe::Payout.retrieve("tr_123")
      assert_requested :get, "#{Stripe.api_base}/v1/payouts/tr_123"
      assert payout.is_a?(Stripe::Payout)
    end

    should "be creatable" do
      payout = Stripe::Payout.create(
        amount: 100,
        currency: "USD"
      )
      assert_requested :post, "#{Stripe.api_base}/v1/payouts"
      assert payout.is_a?(Stripe::Payout)
    end

    should "be saveable via update" do
      payout = Stripe::Payout.update("tr_123", metadata: { key: "value" })
      assert_requested :post, "#{Stripe.api_base}/v1/payouts/tr_123"
      assert payout.is_a?(Stripe::Payout)
    end

    should "be updateable" do
      payout = Stripe::Payout.update("tr_123", metadata: { foo: "bar" })
      assert_requested :post, "#{Stripe.api_base}/v1/payouts/tr_123"
      assert payout.is_a?(Stripe::Payout)
    end

    should "support payout management through Banking::PayoutManager" do
      payout = Stripe::Banking.payouts.create_payout(
        amount: 150,
        currency: "USD",
        description: "Banking payout test"
      )

      assert_requested :post, "#{Stripe.api_base}/v1/payouts"
      assert payout.is_a?(Stripe::Payout)
    end

    should "list payouts through Banking::PayoutManager" do
      payouts = Stripe::Banking.payouts.list_payouts(limit: 1)
      assert_requested :get, "#{Stripe.api_base}/v1/payouts?limit=1"
      assert payouts.data.is_a?(Array)
    end

    should "retrieve a payout through Banking::PayoutManager" do
      payout = Stripe::Banking.payouts.retrieve_payout("tr_123")
      assert_requested :get, "#{Stripe.api_base}/v1/payouts/tr_123"
      assert payout.is_a?(Stripe::Payout)
    end

    should "cancel a payout through Banking::PayoutManager" do
      payout = Stripe::Banking.payouts.cancel_payout("tr_123")
      assert payout.is_a?(Stripe::Payout)
    end

    should "reverse a payout through Banking::PayoutManager" do
      payout = Stripe::Banking.payouts.reverse_payout("tr_123")
      assert payout.is_a?(Stripe::Payout)
    end

    context "#cancel" do
      should "cancel a payout" do
        payout = Stripe::Payout.retrieve("tr_123")
        payout = payout.cancel
        assert payout.is_a?(Stripe::Payout)
      end
    end

    context ".cancel" do
      should "cancel a payout" do
        payout = Stripe::Payout.cancel("pm_123")
        assert payout.is_a?(Stripe::Payout)
      end
    end

    context "#reverse" do
      should "reverse a payout" do
        payout = Stripe::Payout.retrieve("tr_123")
        payout = payout.reverse
        assert payout.is_a?(Stripe::Payout)
      end
    end

    context ".reverse" do
      should "reverse a payout" do
        payout = Stripe::Payout.reverse("pm_123")
        assert payout.is_a?(Stripe::Payout)
      end
    end
  end
end

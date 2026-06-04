#!/usr/bin/env ruby
require "minitest/unit"
require "minitest/autorun"
require_relative "lib/stripe"

class TestAllConnectionsFunctional < Minitest::Test
  def test_all_modules_accessible
    assert Stripe.const_defined?(:Portfolio)
    assert Stripe.const_defined?(:RBAC)
    assert Stripe.const_defined?(:Bridge)
    assert Stripe.const_defined?(:DeFi)
    assert Stripe.const_defined?(:Tax)
    assert Stripe.const_defined?(:Integrations)
  end

  def test_portfolio_manager_works
    manager = Stripe::Portfolio.create_manager("test_user")
    portfolio = manager.create_portfolio("Test", assets: { "ETH" => 5 })

    assert_equal "Test", portfolio.name
    assert_equal "test_user", portfolio.user_id
  end

  def test_rbac_context_works
    Stripe::RBAC.with_context(
      user_id: "user1",
      user_name: "Test User",
      role: "auditor"
    ) do
      context = Stripe::RBAC.current_context
      assert_equal "user1", context.user_id
      assert_equal "Test User", context.user_name
    end
  end

  def test_bridge_module_works
    # Test that bridge module is functional
    assert Stripe::Bridge.respond_to?(:optimal_path)

    # Test with actual bridge call
    path = Stripe::Bridge.optimal_path(
      "ethereum",
      "polygon",
      1000,
      "USDC"
    )

    assert path.key?(:path_found)
    assert path.key?(:hops)
  end

  def test_defi_module_works
    yields = Stripe::DeFi.scan_yields("ethereum")
    assert yields.is_a?(Array)
  end

  def test_tax_module_works
    agg = Stripe::Tax.create_aggregator
    # Test adding with proper arguments (wallet_id, data)
    agg.add_transaction("wallet1", {
      date: Time.now,
      type: :buy,
      asset: "ETH",
      quantity: 1,
      price_per_unit: 2500,
      fee: 10,
      notes: "test",
    })

    assert agg.transaction_count > 0
  end

  def test_portfolio_insights_work
    manager = Stripe::Portfolio.create_manager("insights_user")
    portfolio = manager.create_portfolio("Insights", assets: {
      "ETH" => 5,
      "USDC" => 5000,
      "AAVE" => 10,
      "LINK" => 50,
    })

    analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)
    assert analyzer.diversification_score >= 0
    assert analyzer.risk_score >= 0

    summary = analyzer.generate_summary
    assert summary.is_a?(Hash)
    assert summary[:overview]
  end

  def test_integration_portfolio_to_tax
    manager = Stripe::Portfolio.create_manager("tax_int_user")
    portfolio = manager.create_portfolio("Tax Int", assets: {
      "BTC" => 0.5,
      "ETH" => 2,
    })

    # Convert portfolio to tax transactions
    txs = Stripe::Integrations.portfolio_to_tax_transactions(portfolio)
    assert txs.is_a?(Array)
    assert txs.length > 0
  end

  def test_integration_yield_optimization
    manager = Stripe::Portfolio.create_manager("yield_int_user")
    portfolio = manager.create_portfolio("Yield Int", assets: {
      "USDC" => 10_000,
    })

    opportunities = Stripe::Integrations.optimize_portfolio_yields(portfolio, 1.0)
    assert opportunities.is_a?(Array)
  end

  def test_all_modules_respond_to_key_methods
    # Portfolio
    assert Stripe::Portfolio.respond_to?(:create_manager)
    assert Stripe::Portfolio.respond_to?(:analyze_portfolio)

    # RBAC
    assert Stripe::RBAC.respond_to?(:with_context)
    assert Stripe::RBAC.respond_to?(:set_context)
    assert Stripe::RBAC.respond_to?(:current_context)

    # Bridge
    assert Stripe::Bridge.respond_to?(:optimal_path)
    assert Stripe::Bridge.respond_to?(:find_optimal_path)

    # DeFi
    assert Stripe::DeFi.respond_to?(:scan_yields)

    # Tax
    assert Stripe::Tax.respond_to?(:create_aggregator)

    # Integrations
    assert Stripe::Integrations.respond_to?(:portfolio_to_tax_transactions)
    assert Stripe::Integrations.respond_to?(:optimize_portfolio_yields)
  end

  def test_full_workflow_end_to_end
    # Create portfolio with RBAC
    Stripe::RBAC.with_context(
      user_id: "trader1",
      user_name: "Trader One",
      role: "treasury_manager"
    ) do
      manager = Stripe::Portfolio.create_manager("trader1")

      # Create portfolio
      portfolio = manager.create_portfolio("Trading Book", assets: {
        "ETH" => 10,
        "USDC" => 50_000,
        "AAVE" => 20,
        "LINK" => 100,
      })

      assert portfolio.id

      # Analyze
      analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)
      assert analyzer.diversification_score > 0

      # Check opportunities
      opps = Stripe::Integrations.optimize_portfolio_yields(portfolio)
      assert opps.is_a?(Array)

      # Export to tax
      tax_txs = Stripe::Integrations.portfolio_to_tax_transactions(portfolio)
      assert tax_txs.length == portfolio.assets.length

      # Create tax report
      agg = Stripe::Tax.create_aggregator
      tax_txs.each do |tx|
        # Need to format for aggregator
        agg.add_transaction("portfolio-wallet", {
          date: tx[:timestamp],
          type: tx[:type],
          asset: tx[:asset],
          quantity: tx[:amount],
          price_per_unit: tx[:price],
          fee: 0,
        })
      end

      assert agg.transaction_count > 0
    end
  end

  def test_cross_module_data_flow
    # Test that modules can work together with real data
    manager = Stripe::Portfolio.create_manager("flow_user")
    portfolio = manager.create_portfolio("Flow Portfolio", assets: {
      "BTC" => 0.5,
      "ETH" => 5,
      "USDC" => 10_000,
    })

    # Get portfolio insights
    analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)
    diversification = analyzer.diversification_score
    risk = analyzer.risk_score

    assert diversification.is_a?(Float) || diversification.is_a?(Integer)
    assert risk.is_a?(Float) || risk.is_a?(Integer)

    # Convert to tax data
    tax_data = Stripe::Integrations.portfolio_to_tax_transactions(portfolio)
    assert tax_data.length > 0

    # Check yields
    yields = Stripe::DeFi.scan_yields("ethereum")
    assert yields.is_a?(Array)
  end
end

#!/usr/bin/env ruby
require "minitest/unit"
require "minitest/autorun"
require_relative "lib/stripe"

class TestFinalConnections < Minitest::Test
  def test_portfolio_module_complete
    # Portfolio Manager workflow
    manager = Stripe::Portfolio.create_manager("test_user")
    portfolio = manager.create_portfolio("Test", assets: { "ETH" => 5, "USDC" => 1000 })

    assert_equal "Test", portfolio.name
    assert_equal 5, portfolio.assets["ETH"]
    assert portfolio.total_value > 0
  end

  def test_rbac_module_complete
    # RBAC context workflow
    Stripe::RBAC.with_context(
      user_id: "user1",
      user_name: "Test User",
      role: "treasury_manager"
    ) do
      context = Stripe::RBAC.current_context
      assert_equal "user1", context.user_id
    end
  end

  def test_defi_module_complete
    # DeFi scanning workflow
    yields = Stripe::DeFi.scan_yields("USDC")
    assert yields.is_a?(Array)
  end

  def test_tax_module_complete
    # Tax aggregator workflow
    agg = Stripe::Tax.create_aggregator

    # First add wallet
    agg.add_wallet("wallet1", "ethereum", "0x123")

    # Then add transaction
    agg.add_transaction("wallet1", {
      date: Time.now,
      type: :buy,
      asset: "ETH",
      quantity: 1,
      price_per_unit: 2500,
      fee: 10,
    })

    assert agg.transaction_count == 1
  end

  def test_bridge_module_complete
    # Bridge path calculation workflow
    assert Stripe::Bridge.respond_to?(:optimal_path)
    assert Stripe::Bridge.respond_to?(:find_optimal_path)

    # Test with proper arguments
    path = Stripe::Bridge.optimal_path("ethereum", "polygon", 1000)

    # Path is an object with methods, not a hash
    assert !path.nil?
    assert path.respond_to?(:hops)
  end

  def test_integrations_module_complete
    # Integration workflows
    manager = Stripe::Portfolio.create_manager("int_user")
    portfolio = manager.create_portfolio("Integration", assets: {
      "BTC" => 0.5,
      "ETH" => 2,
      "USDC" => 5000,
    })

    # Convert to tax transactions
    txs = Stripe::Integrations.portfolio_to_tax_transactions(portfolio)
    assert txs.length == 3

    # Optimize yields
    opps = Stripe::Integrations.optimize_portfolio_yields(portfolio)
    assert opps.is_a?(Array)
  end

  def test_all_modules_interconnected
    # Test that all modules can work together

    # 1. Create portfolio with RBAC context
    Stripe::RBAC.with_context(
      user_id: "trader1",
      user_name: "Trader",
      role: "treasury_manager"
    ) do
      manager = Stripe::Portfolio.create_manager("trader1")
      portfolio = manager.create_portfolio("Trading", assets: {
        "ETH" => 5,
        "USDC" => 10_000,
        "AAVE" => 10,
      })

      # 2. Get portfolio insights
      analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)
      assert analyzer.diversification_score > 0

      # 3. Convert to tax data
      txs = Stripe::Integrations.portfolio_to_tax_transactions(portfolio)
      assert txs.length == 3

      # 4. Check DeFi yields
      yields = Stripe::DeFi.scan_yields("USDC")
      assert yields.is_a?(Array)
    end
  end

  def test_all_key_methods_exist
    # Verify API surface
    assert Stripe::Portfolio.respond_to?(:create_manager)
    assert Stripe::Portfolio.respond_to?(:analyze_portfolio)
    assert Stripe::RBAC.respond_to?(:with_context)
    assert Stripe::Bridge.respond_to?(:optimal_path)
    assert Stripe::DeFi.respond_to?(:scan_yields)
    assert Stripe::Tax.respond_to?(:create_aggregator)
    assert Stripe::Integrations.respond_to?(:portfolio_to_tax_transactions)
  end

  def test_portfolio_insights_flow
    manager = Stripe::Portfolio.create_manager("insights_user")
    portfolio = manager.create_portfolio("Insights", assets: {
      "ETH" => 10,
      "USDC" => 20_000,
      "AAVE" => 50,
      "LINK" => 200,
    })

    analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)

    # Check diversification
    div_score = analyzer.diversification_score
    assert div_score > 0

    # Check risk
    risk_score = analyzer.risk_score
    assert risk_score.between?(0, 100)

    # Check sector exposure
    sectors = analyzer.sector_exposure
    assert sectors.is_a?(Hash)
    assert sectors.length > 0

    # Check summary
    summary = analyzer.generate_summary
    assert summary.is_a?(Hash)
    assert summary.key?(:overview)
    assert summary.key?(:recommendations)
  end

  def test_module_data_types
    # Verify correct data types are returned
    manager = Stripe::Portfolio.create_manager("types_user")
    portfolio = manager.create_portfolio("Types", assets: { "ETH" => 5 })

    assert portfolio.id.is_a?(String)
    assert portfolio.name.is_a?(String)
    assert portfolio.assets.is_a?(Hash)
    assert portfolio.balances.is_a?(Hash)
    assert portfolio.total_value.is_a?(Numeric)
    assert portfolio.created_at.is_a?(Time)

    analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)
    assert analyzer.diversification_score.is_a?(Numeric)
    assert analyzer.risk_score.is_a?(Numeric)
  end

  def test_bridge_and_portfolio_integration
    # Test Bridge can be used with portfolio data
    path = Stripe::Bridge.optimal_path("ethereum", "polygon", 1000)
    assert path.respond_to?(:hops)
    assert path.respond_to?(:protocols)
  end

  def test_full_user_workflow
    # Complete user workflow: create portfolio, analyze, export to tax
    manager = Stripe::Portfolio.create_manager("complete_user")
    portfolio = manager.create_portfolio("Complete Workflow", assets: {
      "BTC" => 0.25,
      "ETH" => 5,
      "USDC" => 15_000,
      "AAVE" => 20,
      "LINK" => 100,
    })

    # Analyze portfolio
    analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)
    assert analyzer.diversification_score > 50, "Should be well diversified"
    assert analyzer.risk_score > 0, "Should have risk profile"

    # Get tax data
    tax_data = Stripe::Integrations.portfolio_to_tax_transactions(portfolio)
    assert tax_data.length == 5

    # Get yield opportunities
    opportunities = Stripe::Integrations.optimize_portfolio_yields(portfolio)
    assert opportunities.is_a?(Array)

    # Get bridge path
    path = Stripe::Bridge.optimal_path("ethereum", "arbitrum", 5000)
    assert path.respond_to?(:hops)
  end
end

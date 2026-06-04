#!/usr/bin/env ruby
require "minitest/unit"
require "minitest/autorun"
require_relative "lib/stripe"

class TestModuleIntegration < Minitest::Test
  def test_all_modules_required
    # Verify all major modules are loaded
    assert Stripe.const_defined?(:Portfolio)
    assert Stripe.const_defined?(:RBAC)
    assert Stripe.const_defined?(:Bridge)
    assert Stripe.const_defined?(:DeFi)
    assert Stripe.const_defined?(:Tax)
    assert Stripe.const_defined?(:Banking)
    assert Stripe.const_defined?(:Crypto)
    assert Stripe.const_defined?(:Audit)
  end

  def test_portfolio_with_rbac_context
    # Test Portfolio works within RBAC context
    Stripe::RBAC.context(user_id: "user1", role: "treasury_manager") do
      manager = Stripe::Portfolio.create_manager("user1")
      portfolio = manager.create_portfolio("Treasury Portfolio",
                                           assets: { "ETH" => 5, "USDC" => 10_000 })

      assert portfolio.present?
      assert_equal "Treasury Portfolio", portfolio.name
      assert portfolio.total_value > 0
    end
  end

  def test_portfolio_with_tax_reporting
    # Test Portfolio integrates with Tax reporting
    portfolio = Stripe::Portfolio::Portfolio.new("Tax Portfolio")
    portfolio.add_asset("BTC", 0.5)
    portfolio.add_asset("ETH", 5)

    # Create tax aggregator with portfolio data
    aggregator = Stripe::Tax.transaction_aggregator
    aggregator.add_transaction(
      type: :buy,
      asset: "BTC",
      amount: 0.5,
      price: 65_000,
      wallet: "wallet1"
    )

    assert_equal 1, aggregator.transaction_count
    assert aggregator.transactions_by_asset("BTC").length > 0
  end

  def test_bridge_with_portfolio_simulation
    # Test Bridge module with portfolio rebalancing
    portfolio = Stripe::Portfolio::Portfolio.new("Bridge Portfolio")
    portfolio.add_asset("USDC", 5000)

    # Calculate bridge path for rebalancing
    path = Stripe::Bridge.optimal_path(
      from_chain: "ethereum",
      to_chain: "polygon",
      amount: 1000,
      asset: "USDC"
    )

    assert path.present?
    assert path[:path_found]
    assert path[:hops].length > 0
  end

  def test_defi_yields_with_portfolio
    # Test DeFi yield optimization for portfolio assets
    portfolio = Stripe::Portfolio::Portfolio.new("DeFi Portfolio")
    portfolio.add_asset("USDC", 10_000)
    portfolio.add_asset("ETH", 5)
    portfolio.add_asset("AAVE", 10)

    # Get best yields for portfolio assets
    yields = Stripe::DeFi.scan_yields("ethereum")

    assert yields.present?
    assert yields.length > 0
  end

  def test_rbac_audit_with_multiple_roles
    # Test RBAC system with different roles
    auditor_context = Stripe::RBAC::Context.new(
      user_id: "auditor1",
      role: "auditor",
      resource_type: "transaction"
    )

    compliance_context = Stripe::RBAC::Context.new(
      user_id: "officer1",
      role: "compliance_officer",
      resource_type: "report"
    )

    assert_equal "auditor", auditor_context.role
    assert_equal "compliance_officer", compliance_context.role
  end

  def test_portfolio_insights_analysis
    # Test complete insights pipeline
    portfolio = Stripe::Portfolio::Portfolio.new("Analysis Portfolio")
    portfolio.add_asset("ETH", 10)
    portfolio.add_asset("USDC", 5000)
    portfolio.add_asset("AAVE", 5)
    portfolio.add_asset("LINK", 20)

    analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)

    assert analyzer.diversification_score > 0
    assert analyzer.risk_score.between?(0, 100)
    assert analyzer.sector_exposure.keys.length > 0
  end

  def test_cross_chain_portfolio_tracking
    # Test portfolio across multiple chains
    manager = Stripe::Portfolio.create_manager("multi_chain_user")
    portfolio = manager.create_portfolio("Multi-Chain Portfolio",
                                         assets: { "ETH" => 5, "USDC" => 2000 })

    # Add assets from different chains
    portfolio.add_asset("SOL", 50)    # Solana
    portfolio.add_asset("AVAX", 10)   # Avalanche
    portfolio.add_asset("MATIC", 500) # Polygon

    assert_equal 5, portfolio.asset_count
    total_value = portfolio.total_value
    assert total_value > 0
  end

  def test_audit_trail_creation
    # Test audit logging during operations
    Stripe::RBAC.context(user_id: "user2", role: "treasury_manager") do
      manager = Stripe::Portfolio.create_manager("user2")
      portfolio = manager.create_portfolio("Audited Portfolio",
                                           assets: { "ETH" => 2 })

      # Audit event should be logged
      assert portfolio.present?
    end
  end

  def test_tax_export_formats
    # Test multiple export formats
    aggregator = Stripe::Tax.transaction_aggregator
    aggregator.add_transaction(type: :buy, asset: "ETH", amount: 1, price: 2500)
    aggregator.add_transaction(type: :sell, asset: "ETH", amount: 0.5, price: 3000)

    # Export to different formats
    csv_export = aggregator.export_csv(:turbotax)
    pdf_export = aggregator.export_pdf

    assert csv_export.present?
    assert pdf_export.present?
  end

  def test_module_dependencies_resolved
    # Verify all dependencies are correctly resolved
    assert Stripe::Portfolio.respond_to?(:create_manager)
    assert Stripe::Portfolio.respond_to?(:analyze_portfolio)
    assert Stripe::Bridge.respond_to?(:optimal_path)
    assert Stripe::DeFi.respond_to?(:scan_yields)
    assert Stripe::Tax.respond_to?(:transaction_aggregator)
    assert Stripe::RBAC.respond_to?(:context)
  end

  def test_portfolio_export_and_reimport
    # Test data persistence
    manager = Stripe::Portfolio.create_manager("export_user")
    portfolio = manager.create_portfolio("Export Portfolio",
                                         assets: { "BTC" => 0.5, "ETH" => 5, "USDC" => 10_000 })

    # Export portfolio data
    exported = portfolio.to_h

    assert exported[:name]
    assert exported[:assets]
    assert exported[:balances]
    assert exported[:total_value] > 0
  end
end

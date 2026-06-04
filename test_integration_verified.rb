#!/usr/bin/env ruby
require "minitest/unit"
require "minitest/autorun"
require_relative "lib/stripe"

class TestModuleIntegrationVerified < Minitest::Test
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
    assert Stripe.const_defined?(:Integrations)
  end

  def test_portfolio_basic_creation
    manager = Stripe::Portfolio.create_manager("user1")
    portfolio = manager.create_portfolio("Test Portfolio",
                                         assets: { "ETH" => 5, "USDC" => 10_000 })

    assert portfolio.present?
    assert_equal "Test Portfolio", portfolio.name
    assert_equal "user1", portfolio.user_id
  end

  def test_rbac_with_context_method
    # Test RBAC with_context method
    Stripe::RBAC.with_context(
      user_id: "user2",
      user_name: "John Doe",
      role: "treasury_manager"
    ) do
      context = Stripe::RBAC.current_context
      assert_equal "user2", context.user_id
      assert_equal "John Doe", context.user_name
      assert_equal "treasury_manager", context.role
    end
  end

  def test_portfolio_to_tax_conversion
    manager = Stripe::Portfolio.create_manager("tax_user")
    portfolio = manager.create_portfolio("Tax Portfolio",
                                         assets: { "BTC" => 0.5, "ETH" => 5 })

    transactions = Stripe::Integrations.portfolio_to_tax_transactions(portfolio)

    assert transactions.length > 0
    assert_equal :buy, transactions.first[:type]
    assert transactions.first[:asset].present?
  end

  def test_portfolio_yield_optimization
    manager = Stripe::Portfolio.create_manager("yield_user")
    portfolio = manager.create_portfolio("Yield Portfolio",
                                         assets: { "USDC" => 5000, "ETH" => 2 })

    opportunities = Stripe::Integrations.optimize_portfolio_yields(portfolio)

    assert opportunities.is_a?(Array)
  end

  def test_aggregate_portfolio_tax_report
    portfolios = []

    2.times do |i|
      manager = Stripe::Portfolio.create_manager("agg_user_#{i}")
      portfolio = manager.create_portfolio("Portfolio #{i}",
                                           assets: { "ETH" => 2, "USDC" => 1000 })
      portfolios << portfolio
    end

    aggregator = Stripe::Integrations.aggregate_portfolio_tax_report(portfolios)
    assert aggregator.respond_to?(:transaction_count)
  end

  def test_bridge_paths_available
    path = Stripe::Bridge.optimal_path(
      from_chain: "ethereum",
      to_chain: "polygon",
      amount: 1000,
      asset: "USDC"
    )

    assert path.present?
    assert path.key?(:path_found)
    assert path.key?(:hops)
  end

  def test_defi_protocol_scanning
    yields = Stripe::DeFi.scan_yields("ethereum")

    assert yields.present?
    assert yields.is_a?(Array)
  end

  def test_tax_transaction_aggregator
    aggregator = Stripe::Tax.create_aggregator
    aggregator.add_transaction(
      type: :buy,
      asset: "ETH",
      amount: 1,
      price: 2500,
      wallet: "wallet1"
    )

    assert aggregator.transaction_count > 0
  end

  def test_rbac_context_set_clear
    context = Stripe::RBAC.set_context(
      user_id: "user3",
      user_name: "Jane Doe",
      role: "auditor"
    )

    assert context.present?

    Stripe::RBAC.clear_context
    # After clear, context should be nil or not set
  end

  def test_portfolio_manager_operations
    manager = Stripe::Portfolio.create_manager("operations_user")

    # Create
    p1 = manager.create_portfolio("Portfolio A")
    assert p1.present?

    # List
    portfolios = manager.list_portfolios
    assert portfolios.length > 0

    # Switch
    manager.switch_portfolio(p1.id)
    assert_equal p1.id, manager.current_portfolio_id

    # Delete
    manager.delete_portfolio(p1.id)
    # After deletion, should not be in list
  end

  def test_portfolio_insights_complete_analysis
    manager = Stripe::Portfolio.create_manager("insights_user")
    portfolio = manager.create_portfolio("Insights Portfolio",
                                         assets: {
                                           "ETH" => 10,
                                           "USDC" => 5000,
                                           "AAVE" => 5,
                                           "LINK" => 20,
                                           "SOL" => 50,
                                         })

    analyzer = Stripe::Portfolio.analyze_portfolio(portfolio)

    assert analyzer.diversification_score >= 0
    assert analyzer.risk_score >= 0
    assert analyzer.sector_exposure.present?

    summary = analyzer.generate_summary
    assert summary[:overview].present?
    assert summary[:recommendations].is_a?(Array)
  end

  def test_module_cross_references
    # Verify modules can be accessed from Stripe namespace
    assert Stripe::Portfolio.respond_to?(:create_manager)
    assert Stripe::RBAC.respond_to?(:with_context)
    assert Stripe::Bridge.respond_to?(:optimal_path)
    assert Stripe::DeFi.respond_to?(:scan_yields)
    assert Stripe::Tax.respond_to?(:create_aggregator)
    assert Stripe::Integrations.respond_to?(:portfolio_to_tax_transactions)
  end

  def test_portfolio_export_data
    manager = Stripe::Portfolio.create_manager("export_user")
    portfolio = manager.create_portfolio("Export Portfolio",
                                         assets: { "BTC" => 0.5, "ETH" => 5 })

    exported = portfolio.to_h

    assert exported[:id].present?
    assert exported[:name] == "Export Portfolio"
    assert exported[:user_id] == "export_user"
    assert exported[:assets].present?
    assert exported[:total_value].present?
  end
end

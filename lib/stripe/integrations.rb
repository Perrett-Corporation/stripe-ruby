# frozen_string_literal: true

module Stripe
  module Integrations
    # Cross-module integration helpers for seamless functionality

    # Portfolio + Tax Integration
    def self.portfolio_to_tax_transactions(portfolio)
      transactions = []
      prices = get_asset_prices
      
      portfolio.assets.each do |asset, quantity|
        price = prices[asset] || 1.0
        transactions << {
          type: :buy,
          asset: asset,
          amount: quantity,
          price: price,
          timestamp: portfolio.created_at,
          wallet: "portfolio-#{portfolio.id}",
        }
      end
      transactions
    end

    # Portfolio + Bridge Integration
    def self.calculate_rebalancing_bridge_paths(source_portfolio, target_allocation)
      paths = {}
      source_portfolio.assets.each do |asset, quantity|
        target_qty = target_allocation[asset] || 0
        diff = target_qty - quantity

        next if diff == 0

        paths[asset] = if diff > 0
                         # Need to bridge in more
                         {
                           direction: :in,
                           quantity: diff,
                           sources: find_bridge_sources(asset, diff),
                         }
                       else
                         # Need to bridge out excess
                         {
                           direction: :out,
                           quantity: diff.abs,
                           destinations: find_bridge_destinations(asset, diff.abs),
                         }
                       end
      end
      paths
    end

    # Portfolio + DeFi Integration
    def self.optimize_portfolio_yields(portfolio, target_apy_threshold = 5.0)
      optimization_opportunities = []

      portfolio.assets.each do |asset, quantity|
        best_yield = Stripe::DeFi.best_yield_for_asset(asset)
        next if !best_yield || !best_yield[:apy] || best_yield[:apy] < target_apy_threshold

        current_value = portfolio.balances[asset] || 0
        optimization_opportunities << {
          asset: asset,
          quantity: quantity,
          current_value: current_value,
          best_protocol: best_yield[:protocol],
          best_chain: best_yield[:chain],
          apy: best_yield[:apy],
          annual_yield: current_value * (best_yield[:apy].to_f / 100.0),
        }
      end

      optimization_opportunities
    end

    # Portfolio + RBAC Integration
    def self.create_portfolio_with_rbac(user_id, portfolio_name, role, permissions = nil)
      Stripe::RBAC.set_context(
        user_id: user_id,
        user_name: user_id,
        role: role,
        custom_permissions: permissions
      )

      manager = Stripe::Portfolio.create_manager(user_id)
      portfolio = manager.create_portfolio(portfolio_name)

      Stripe::RBAC.clear_context

      portfolio
    end

    # RBAC + Audit Integration
    def self.audit_portfolio_access(user_id, user_name, action, resource, result)
      context = Stripe::RBAC::Context.new(
        user_id: user_id,
        user_name: user_name,
        role: "auditor"
      )

      Stripe::Audit.log_event(
        timestamp: Time.now.utc,
        user_id: user_id,
        user_name: user_name,
        action: action,
        resource_type: resource,
        resource_id: nil,
        result: result,
        ip_address: context.ip_address
      )
    end

    # Multi-Portfolio + Tax Integration
    def self.aggregate_portfolio_tax_report(portfolios)
      aggregator = Stripe::Tax.create_aggregator

      portfolios.each do |portfolio|
        transactions = portfolio_to_tax_transactions(portfolio)
        transactions.each { |tx| aggregator.add_transaction(**tx) }
      end

      aggregator
    end

    # Portfolio + Bridge + DeFi Integration (Full Rebalancing)
    def self.simulate_optimal_rebalancing(portfolio, target_chains = %w[ethereum polygon], risk_profile = :moderate)
      target_allocation = calculate_target_allocation(portfolio, risk_profile)

      # Step 1: Calculate what needs to move
      rebalance_paths = calculate_rebalancing_bridge_paths(portfolio, target_allocation)

      # Step 2: Find optimal bridges
      bridge_operations = []
      rebalance_paths.each do |asset, path_info|
        path_info[:sources]&.each do |source|
          operation = Stripe::Bridge.optimal_path(
            from_chain: source[:chain],
            to_chain: target_chains.first,
            amount: path_info[:quantity],
            asset: asset
          )
          bridge_operations << operation if operation[:path_found]
        end
      end

      # Step 3: Find yield opportunities
      yield_opportunities = optimize_portfolio_yields(portfolio)

      {
        target_allocation: target_allocation,
        rebalance_paths: rebalance_paths,
        bridge_operations: bridge_operations,
        yield_opportunities: yield_opportunities,
        total_estimated_cost: bridge_operations.sum { |op| op[:total_cost] },
        estimated_time: bridge_operations.map { |op| op[:execution_time_minutes] }.max,
      }
    end

    private

    def self.calculate_target_allocation(portfolio, risk_profile)
      profile_mapping = {
        conservative: { stablecoin: 0.6, layer1: 0.3, defi: 0.1 },
        moderate: { stablecoin: 0.4, layer1: 0.4, defi: 0.2 },
        aggressive: { stablecoin: 0.2, layer1: 0.3, defi: 0.5 },
      }

      profile = profile_mapping[risk_profile] || profile_mapping[:moderate]
      total_value = portfolio.total_value
      prices = get_asset_prices

      target = {}
      profile.each do |sector, allocation_pct|
        sector_value = total_value * allocation_pct
        # Map sector to assets
        sector_assets = map_sector_to_assets(sector)
        per_asset = sector_value / sector_assets.length
        sector_assets.each do |asset|
          price = prices[asset] || 1.0
          target[asset] = per_asset / price
        end
      end

      target
    end

    def self.map_sector_to_assets(sector)
      sector_mapping = {
        stablecoin: %w[USDC USDT DAI],
        layer1: %w[ETH SOL AVAX],
        oracle: %w[LINK BAND],
        defi: %w[AAVE COMP UNI],
      }
      sector_mapping[sector] || []
    end

    def self.find_bridge_sources(asset, _quantity)
      # Return available bridge sources for an asset
      [
        { chain: "ethereum", liquidity: 10_000, fee_bps: 25 },
        { chain: "polygon", liquidity: 5000, fee_bps: 30 },
      ]
    end

    def self.find_bridge_destinations(asset, _quantity)
      # Return available bridge destinations
      [
        { chain: "arbitrum", liquidity: 8000, fee_bps: 20 },
        { chain: "optimism", liquidity: 6000, fee_bps: 25 },
      ]
    end

    def self.get_asset_prices
      {
        "ETH" => 2500,
        "USDC" => 1.0,
        "USDT" => 1.0,
        "DAI" => 1.0,
        "BTC" => 65000,
        "SOL" => 150,
        "AVAX" => 80,
        "MATIC" => 0.8,
        "AAVE" => 250,
        "COMP" => 70,
        "UNI" => 8,
        "LINK" => 12,
        "BAND" => 5,
      }
    end
  end
end

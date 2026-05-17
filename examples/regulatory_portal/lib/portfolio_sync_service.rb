require "json"
require "date"

class PortfolioSyncService
  # Mock database for portfolios and transactions
  PORTFOLIOS = {}
  TRANSACTIONS = {}

  # Mock API Connectors
  class EToroConnector
    def self.fetch_portfolio(user_id)
      # Simulate API call
      sleep 0.2
      {
        provider: "eToro",
        user_id: user_id,
        updated_at: DateTime.now.to_s,
        assets: [
          { symbol: "TSLA", quantity: 15.5, current_price: 240.20, value: 3723.10 },
          { symbol: "AAPL", quantity: 50.0, current_price: 185.50, value: 9275.00 },
          { symbol: "BTC", quantity: 0.45, current_price: 65000.00, value: 29250.00 }
        ]
      }
    end

    def self.fetch_transactions(user_id, since_date)
      # Simulate API call
      sleep 0.2
      [
        { id: "et_tx_1", symbol: "TSLA", type: "BUY", amount: 15.5, price: 230.00, date: (Date.today - 2).to_s },
        { id: "et_tx_2", symbol: "BTC", type: "BUY", amount: 0.45, price: 64000.00, date: (Date.today - 5).to_s }
      ]
    end
  end

  class DeltaConnector
    def self.fetch_portfolio(user_id)
      # Simulate API call
      sleep 0.2
      {
        provider: "Delta",
        user_id: user_id,
        updated_at: DateTime.now.to_s,
        assets: [
          { symbol: "ETH", quantity: 12.0, current_price: 3500.00, value: 42000.00 },
          { symbol: "SOL", quantity: 150.0, current_price: 145.00, value: 21750.00 }
        ]
      }
    end

    def self.fetch_transactions(user_id, since_date)
      # Simulate API call
      sleep 0.2
      [
        { id: "dl_tx_1", symbol: "ETH", type: "BUY", amount: 2.0, price: 3400.00, date: (Date.today - 1).to_s },
        { id: "dl_tx_2", symbol: "SOL", type: "SELL", amount: 50.0, price: 150.00, date: (Date.today - 3).to_s }
      ]
    end
  end

  # Main Sync Logic
  def self.sync_portfolio(user_id)
    puts "[PortfolioSync] Starting sync for User: #{user_id}..."

    # 1. Sync eToro
    etoro_data = EToroConnector.fetch_portfolio(user_id)
    PORTFOLIOS["#{user_id}_etoro"] = etoro_data
    puts "[PortfolioSync] eToro Portfolio Updated: #{etoro_data[:assets].count} assets"

    etoro_txs = EToroConnector.fetch_transactions(user_id, Date.today - 30)
    TRANSACTIONS["#{user_id}_etoro"] = etoro_txs
    puts "[PortfolioSync] eToro Transactions Imported: #{etoro_txs.count}"

    # 2. Sync Delta
    delta_data = DeltaConnector.fetch_portfolio(user_id)
    PORTFOLIOS["#{user_id}_delta"] = delta_data
    puts "[PortfolioSync] Delta Portfolio Updated: #{delta_data[:assets].count} assets"

    delta_txs = DeltaConnector.fetch_transactions(user_id, Date.today - 30)
    TRANSACTIONS["#{user_id}_delta"] = delta_txs
    puts "[PortfolioSync] Delta Transactions Imported: #{delta_txs.count}"

    # 3. Aggregation
    total_value = (etoro_data[:assets] + delta_data[:assets]).sum { |a| a[:value] }
    puts "[PortfolioSync] Total Portfolio Value: $#{total_value.round(2)}"

    {
      user_id: user_id,
      timestamp: DateTime.now,
      portfolios: { etoro: etoro_data, delta: delta_data },
      transactions: { etoro: etoro_txs, delta: delta_txs },
      total_value: total_value
    }
  end

  # Scheduled Update Runner (Simulated)
  def self.run_scheduled_updates(users)
    puts "============================================================"
    puts "  STARTING SCHEDULED PORTFOLIO SYNC"
    puts "============================================================"
    users.each do |user_id|
      sync_portfolio(user_id)
      puts "------------------------------------------------------------"
    end
    puts "  SCHEDULED SYNC COMPLETE"
    puts "============================================================"
  end
end

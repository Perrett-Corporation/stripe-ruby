require "date"

class SanctionsScreener
  # Mock Watchlists
  OFAC_SDN_LIST = [
    "Global Import Export Ltd", # Matches our mock investigation subject
    "Crypto Ventures LLC",      # Matches another mock subject
    "Cartel Alpha",
  ]

  EU_CONSOLIDATED_LIST = [
    "Tax Haven Corp", # From MediaScreener mock data
    "Oligarch X",
  ]

  UN_SANCTIONS_LIST = [
    "Warlord Y",
  ]

  def self.check_sanctions(entity_name)
    alerts = []

    # Simulate checking OFAC
    if OFAC_SDN_LIST.include?(entity_name)
      alerts << { source: "OFAC SDN List", risk: "CRITICAL", match: entity_name, date_added: "2025-12-01" }
    end

    # Simulate checking EU
    if EU_CONSOLIDATED_LIST.include?(entity_name)
      alerts << { source: "EU Consolidated List", risk: "HIGH", match: entity_name, date_added: "2026-01-15" }
    end

    # Simulate checking UN
    if UN_SANCTIONS_LIST.include?(entity_name)
      alerts << { source: "UN Sanctions List", risk: "CRITICAL", match: entity_name, date_added: "2024-08-20" }
    end

    {
      entity: entity_name,
      screened_at: DateTime.now,
      alerts: alerts,
      status: alerts.empty? ? "CLEAN" : "FLAGGED",
    }
  end

  # Batch processing
  def self.batch_screen(entities)
    results = {}
    entities.each do |entity|
      results[entity] = check_sanctions(entity)
    end
    results
  end
end

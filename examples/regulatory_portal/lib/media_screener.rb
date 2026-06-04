require "date"

class MediaScreener
  # Mock database of adverse media
  ADVERSE_MEDIA_DB = {
    "cus_123" => [
      { source: "Times Global", date: "2025-11-15", sentiment: "negative",
        snippet: "Entities associated with customer linked to offshore shell companies under investigation.", },
      { source: "Financial Watch", date: "2024-05-20", sentiment: "neutral",
        snippet: "Minor regulatory fine for late filing in 2023.", },
    ],
    "cus_456" => [], # Clean profile
    "Tax Haven Corp" => [
      { source: "Investigative Weekly", date: "2026-01-10", sentiment: "alert",
        snippet: "Allegations of money laundering surface for Tax Haven Corp executives.", },
    ],
  }

  def self.screen_entity(entity_name_or_id)
    # Simulate API call latency
    sleep 0.5

    hits = ADVERSE_MEDIA_DB[entity_name_or_id] || []

    risk_level = "Low"
    if hits.any? { |h| h[:sentiment] == "alert" }
      risk_level = "Critical"
    elsif hits.any? { |h| h[:sentiment] == "negative" }
      risk_level = "High"
    elsif hits.any?
      risk_level = "Medium"
    end

    {
      entity: entity_name_or_id,
      risk_level: risk_level,
      last_screened: DateTime.now,
      hits: hits,
    }
  end

  def self.batch_screen(entities)
    entities.map { |e| screen_entity(e) }
  end
end

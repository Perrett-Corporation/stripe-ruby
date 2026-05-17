# frozen_string_literal: true

require "json"

class ScreeningService
  # Simulate a response from a sanctions checking API
  # Returns a Hash with :entity_id, :hits, :risk_score, :adverse_media
  def self.check(entity_name, entity_id, document_type = "unknown")
    puts "Checking entity: #{entity_name} against sanctions lists..."

    # Mock Data Source
    risk_score = 10
    hits = []
    media = []

    case entity_name.downcase
    when /putin/, /jong-un/, /bin laden/
      risk_score = 99
      hits = [
        { list: "OFAC SDN", reason: "Match on blocked individual", confidence: 0.98 },
        { list: "EU Sanctions", reason: "Targeted restrictive measures", confidence: 0.95 },
      ]
      media = [
        { source: "Global News", title: "Sanctions extended", url: "http://news/bad-actor", date: "2024-01-01" },
      ]
    when /company/, /shell/, /holding/
      # Simulated risk based on name patterns often associated with shells
      if entity_name.include?("Offshore")
        risk_score = 75
        hits = [
          { list: "ICIJ Offshore Leaks", reason: "Potential match in Panama Papers", confidence: 0.60 },
        ]
      end
    when "john doe" # Testing logic
      risk_score = 45
      media = [
        { source: "Local Gazette", title: "Questioned in fraud case", url: "http://news/local-fraud",
          date: "2023-05-15", },
      ]
    end

    result = {
      entity_id: entity_id,
      entity_name: entity_name,
      document_type: document_type,
      risk_score: risk_score,
      hits: hits,
      adverse_media: media,
      timestamp: Time.now.utc,
    }

    # Auto-log check to audit trail (simulating integration)
    AuditLogService.log(
      user_id: "system_screening_bot",
      action: "ENTITY_SCREENING",
      details: { list_hits: hits.count, score: risk_score },
      entity_id: entity_id
    )

    result
  end
end

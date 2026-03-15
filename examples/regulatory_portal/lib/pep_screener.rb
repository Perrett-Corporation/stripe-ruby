# frozen_string_literal: true

require "date"

# Screens entities against Politically Exposed Persons (PEP) lists.
# PEPs are individuals who hold or have held prominent public positions and
# therefore carry a higher risk of involvement in bribery or corruption.
class PepScreener
  # Mock PEP database keyed by lowercase entity name
  PEP_DATABASE = {
    "president adams"         => { category: "Head of State",             country: "Fictional Republic",  since: "2020" },
    "minister elara"          => { category: "Senior Government Official", country: "Fictional Republic",  since: "2019" },
    "senator corrupt"         => { category: "Legislator",                 country: "United States",       since: "2015" },
    "judge blackwood"         => { category: "Judicial Official",          country: "United Kingdom",      since: "2018" },
    "general strongarm"       => { category: "Military Official",          country: "Fictional State",     since: "2021" },
    "oligarch x"              => { category: "Senior Government Official", country: "Fictional Federation", since: "2010" },
    "oligarch x's son"        => { category: "Family Member",              country: "Fictional Federation", since: "2010" },
    "elena power"             => { category: "Close Associate",            country: "Fictional Federation", since: "2012" },
    "warlord y"               => { category: "Military Official",          country: "Unknown",             since: "2005" },
    "unknown beneficiary"     => { category: "Close Associate",            country: "Russian Federation",  since: "2015" },
  }.freeze

  # @param entity_name [String]
  # @return [Hash] with :is_pep, :category, :country, :since, :entity_name
  def self.check(entity_name)
    key  = entity_name.to_s.strip.downcase
    data = PEP_DATABASE[key]

    if data
      {
        entity_name: entity_name,
        is_pep:      true,
        category:    data[:category],
        country:     data[:country],
        since:       data[:since],
        screened_at: DateTime.now,
        source:      "Internal PEP Register",
      }
    else
      {
        entity_name: entity_name,
        is_pep:      false,
        category:    nil,
        country:     nil,
        since:       nil,
        screened_at: DateTime.now,
        source:      "Internal PEP Register",
      }
    end
  end

  # Batch check
  # @param entities [Array<String>]
  # @return [Hash<String, Hash>]
  def self.batch_check(entities)
    entities.each_with_object({}) { |name, h| h[name] = check(name) }
  end
end

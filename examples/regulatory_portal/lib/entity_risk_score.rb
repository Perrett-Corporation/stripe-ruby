# frozen_string_literal: true

require "time"

# Tracks and manages composite risk scores for entities across all screening sources.
# Combines watchlist hits, PEP status, and adverse media findings into a single score.
class EntityRiskScore
  SCORE_REGISTRY = {}

  # Risk thresholds
  THRESHOLD_HIGH     = 70
  THRESHOLD_CRITICAL = 90

  RiskRecord = Struct.new(
    :entity_id,
    :entity_name,
    :composite_score,   # 0-100
    :watchlist_score,   # 0-100
    :pep_score,         # 0-100
    :adverse_media_score, # 0-100
    :watchlist_hits,
    :pep_hits,
    :adverse_media_hits,
    :risk_level,        # "Low", "Medium", "High", "Critical"
    :last_updated,
    keyword_init: true
  )

  def self.upsert(entity_id:, entity_name:, watchlist_result:, pep_result:, media_result:)
    watchlist_score   = compute_watchlist_score(watchlist_result)
    pep_score         = compute_pep_score(pep_result)
    media_score       = compute_media_score(media_result)

    # Weighted composite: watchlist carries most weight
    composite = (watchlist_score * 0.50 + pep_score * 0.30 + media_score * 0.20).round

    record = RiskRecord.new(
      entity_id:           entity_id,
      entity_name:         entity_name,
      composite_score:     composite,
      watchlist_score:     watchlist_score,
      pep_score:           pep_score,
      adverse_media_score: media_score,
      watchlist_hits:      watchlist_result[:alerts] || [],
      pep_hits:            pep_result[:hits] || [],
      adverse_media_hits:  media_result[:hits] || [],
      risk_level:          risk_level_for(composite),
      last_updated:        Time.now.utc
    )

    SCORE_REGISTRY[entity_id] = record
    record
  end

  def self.fetch(entity_id)
    SCORE_REGISTRY[entity_id]
  end

  def self.all
    SCORE_REGISTRY.values.sort_by { |r| -r.composite_score }
  end

  def self.high_risk
    SCORE_REGISTRY.values.select { |r| r.composite_score >= THRESHOLD_HIGH }
                         .sort_by { |r| -r.composite_score }
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  def self.risk_level_for(score)
    if score >= THRESHOLD_CRITICAL
      "Critical"
    elsif score >= THRESHOLD_HIGH
      "High"
    elsif score >= 40
      "Medium"
    else
      "Low"
    end
  end

  def self.compute_watchlist_score(watchlist_result)
    return 0 if watchlist_result[:alerts].nil? || watchlist_result[:alerts].empty?

    max_risk = watchlist_result[:alerts].map do |a|
      a[:risk] == "CRITICAL" ? 100 : 75
    end.max
    max_risk
  end

  def self.compute_pep_score(pep_result)
    return 0 unless pep_result[:is_pep]

    case pep_result[:category]
    when "Head of State", "Senior Government Official" then 85
    when "Legislator", "Judicial Official"             then 70
    when "Military Official"                           then 65
    when "Family Member", "Close Associate"            then 50
    else 40
    end
  end

  def self.compute_media_score(media_result)
    hits = media_result[:hits] || []
    return 0 if hits.empty?

    if hits.any? { |h| h[:sentiment] == "alert" }
      90
    elsif hits.any? { |h| h[:sentiment] == "negative" }
      65
    else
      30
    end
  end

  private_class_method :risk_level_for, :compute_watchlist_score,
                       :compute_pep_score, :compute_media_score
end

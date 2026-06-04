# frozen_string_literal: true

# Automated workflow that ingests new entity data and runs it against:
#   1. Global watchlists / sanctions lists  (SanctionsScreener)
#   2. PEP (Politically Exposed Persons) lists  (PepScreener)
#   3. Adverse media databases  (MediaScreener)
#
# After screening, the service:
#   - Updates the EntityRiskScore record for the entity
#   - Triggers WorkflowEngine alerts for high-risk matches
#   - Appends structured entries to the AuditLog
class EntityIngestionWorkflow
  # Holds the most recently ingested entities (in-memory, demo only)
  INGESTED_ENTITIES = {}

  EntityRecord = Struct.new(
    :id, :name, :entity_type, :country, :date_of_birth,
    :registration_number, :ingested_at,
    keyword_init: true
  )

  # Ingest a new entity and run the full screening pipeline.
  #
  # @param id   [String]  Unique identifier (e.g. customer ID)
  # @param name [String]  Full legal name
  # @param entity_type [String]  "individual" | "company" | "trust"
  # @param country [String]  Country of incorporation / residence
  # @param date_of_birth [String, nil]  ISO date, individuals only
  # @param registration_number [String, nil]  Companies only
  # @return [Hash] Full screening result including risk score record
  def self.ingest(id:, name:, entity_type: "individual", country: "Unknown",
                  date_of_birth: nil, registration_number: nil)
    entity = EntityRecord.new(
      id:                  id,
      name:                name,
      entity_type:         entity_type,
      country:             country,
      date_of_birth:       date_of_birth,
      registration_number: registration_number,
      ingested_at:         Time.now.utc
    )
    INGESTED_ENTITIES[id] = entity

    AuditLogService.log(
      user_id:   "system_ingestion_bot",
      action:    "ENTITY_INGESTED",
      details:   { name: name, type: entity_type, country: country },
      entity_id: id
    )

    # Run the full screening pipeline
    run_pipeline(entity)
  end

  # Re-run the screening pipeline for an already-ingested entity.
  def self.rescreen(entity_id)
    entity = INGESTED_ENTITIES[entity_id]
    raise "Entity #{entity_id} not found in registry" unless entity

    run_pipeline(entity)
  end

  def self.list
    INGESTED_ENTITIES.values.sort_by { |e| e.ingested_at }.reverse
  end

  def self.find(entity_id)
    INGESTED_ENTITIES[entity_id]
  end

  # ── Private helpers ──────────────────────────────────────────────────────────
  private_class_method def self.run_pipeline(entity)
    id   = entity.id
    name = entity.name

    # 1. Watchlist / Sanctions
    watchlist_result = SanctionsScreener.check_sanctions(name)

    # 2. PEP screening
    pep_result = PepScreener.check(name)

    # 3. Adverse media
    media_result = MediaScreener.screen_entity(id)
    # Also try by name if no hits on id
    if (media_result[:hits] || []).empty?
      media_result = MediaScreener.screen_entity(name)
    end

    # 4. Update EntityRiskScore
    risk_record = EntityRiskScore.upsert(
      entity_id:       id,
      entity_name:     name,
      watchlist_result: watchlist_result,
      pep_result:       pep_result,
      media_result:     media_result
    )

    # 5. Audit log with results
    AuditLogService.log(
      user_id:   "system_ingestion_bot",
      action:    "ENTITY_SCREENING_COMPLETE",
      details:   {
        composite_score:   risk_record.composite_score,
        risk_level:        risk_record.risk_level,
        watchlist_flagged: watchlist_result[:status] == "FLAGGED",
        is_pep:            pep_result[:is_pep],
        media_hits:        (media_result[:hits] || []).count,
      },
      entity_id: id
    )

    # 6. Trigger workflow alerts for high-risk entities
    if risk_record.composite_score >= EntityRiskScore::THRESHOLD_CRITICAL
      WorkflowEngine.trigger_action(
        "Critical Entity Alert",
        id,
        "Entity '#{name}' scored #{risk_record.composite_score}/100 (Critical). " \
        "Automatic review initiated following global watchlist ingestion."
      )
    elsif risk_record.composite_score >= EntityRiskScore::THRESHOLD_HIGH
      WorkflowEngine.trigger_action(
        "High-Risk Entity Alert",
        id,
        "Entity '#{name}' scored #{risk_record.composite_score}/100 (High Risk). " \
        "Enhanced Due Diligence required."
      )
    end

    {
      entity:           entity,
      watchlist_result: watchlist_result,
      pep_result:       pep_result,
      media_result:     media_result,
      risk_record:      risk_record,
    }
  end
end

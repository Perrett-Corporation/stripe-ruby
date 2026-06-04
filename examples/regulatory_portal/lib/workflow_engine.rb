class WorkflowEngine
  # In-memory storage for triggered actions
  ACTIONS = []

  def self.evaluate_sar_filing(report)
    puts "Evaluating workflow for SAR #{report.report_id}..."

    # Logic: If subject has High/Critical risk profile mentioned in narrative or explicit metadata
    # For this demo, we parse the narrative or subject info.

    subject_id = report.subject_info[:id]

    # Check if we should block account
    if report.narrative.include?("High Risk") || report.narrative.include?("Critical") || report.narrative.include?("Structuring")
      trigger_action("Account Block", subject_id, "Automatic block triggered by SAR filing with High Risk indicators.")
    end

    return unless report.narrative.include?("Money Laundering")

    trigger_action("Global Asset Freeze", subject_id,
                   "Immediate freeze triggered by Money Laundering suspicion in SAR.")
  end

  def self.evaluate_adverse_media(entity_id, risk_level)
    return if risk_level == "Low"

    existing_action = # Dedup within hour
      ACTIONS.find do |a|
        a[:entity_id] == entity_id && a[:timestamp] > Time.now - 3600
      end
    return if existing_action

    case risk_level
    when "Critical"
      trigger_action("Entity Freeze", entity_id, "Automatic freeze triggered by Critical Adverse Media findings.")
      trigger_action("Notify MLRO", entity_id, "Urgent notification sent to MLRO regarding Critical Media.")
    when "High"
      trigger_action("Enhanced Due Diligence (EDD)", entity_id, "EDD case opened due to High Adverse Media.")
    when "Medium"
      trigger_action("Watchlist Addition", entity_id, "Entity added to internal watchlist.")
    end
  end

  def self.trigger_action(type, entity_id, reason)
    action = {
      id: "ACT-#{Time.now.to_i}-#{rand(1000)}",
      type: type,
      entity_id: entity_id,
      reason: reason,
      timestamp: Time.now,
      status: "Executed",
    }
    ACTIONS.unshift(action) # Add to top
    puts "WORKFLOW TRIGGERED: #{type} for #{entity_id}"
    action
  end

  def self.get_recent_actions
    ACTIONS.first(10)
  end
end

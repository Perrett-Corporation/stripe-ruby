require "date"

class EscalationService
  # CONFIGURATION
  STAGNANT_THRESHOLD_DAYS = 14
  CAPACITY_LIMIT = 1 # Max cases per investigator before flagging overload

  # Tracks escalations in memory
  ESCALATIONS = []

  def self.run_batch_check(all_cases)
    puts "Running Escalation Batch Check..."

    # Calculate Team Capacity
    investigator_load = Hash.new(0)
    all_cases.each { |c| investigator_load[c[:assigned_to]] += 1 if c[:assigned_to] }

    new_escalations = []

    all_cases.each do |kase|
      reasons = []

      # 1. Time-in-Status Check
      days_in_status = (Date.today - Date.parse(kase[:status_changed_at] || kase[:opened_at])).to_i
      if days_in_status > STAGNANT_THRESHOLD_DAYS
        reasons << "Stagnant Case: No status change for #{days_in_status} days (> #{STAGNANT_THRESHOLD_DAYS} limit)."
      end

      # 2. Internal Team Capacity Check
      load_count = investigator_load[kase[:assigned_to]]
      if load_count > CAPACITY_LIMIT
        reasons << "Capacity overload: Assigned investigator '#{kase[:assigned_to]}' has #{load_count} active cases."
      end

      # 3. Risk Score Volatility
      if risk_jump?(kase[:previous_risk_level], kase[:risk_level])
        reasons << "Risk Volatility: Entity risk escalated from #{kase[:previous_risk_level]} to #{kase[:risk_level]}."
      end

      # If any flags triggered, create escalation
      next unless reasons.any?

      escalation = {
        id: "ESC-#{Time.now.to_i}-#{rand(100)}",
        case_id: kase[:id],
        subject_name: kase[:subject_name],
        severity: determine_severity(reasons),
        reasons: reasons,
        supervisor_email: kase[:supervisor_email],
        created_at: Time.now,
        status: "Pending Review",
      }

      # Debounce: Don't create if open escalation exists for this case
      next if ESCALATIONS.any? { |e| e[:case_id] == kase[:id] && e[:status] == "Pending Review" }

      ESCALATIONS << escalation
      new_escalations << escalation
      NotificationService.notify_supervisor(escalation)
    end

    new_escalations
  end

  def self.list_escalations
    ESCALATIONS.sort_by { |e| e[:created_at] }.reverse
  end

  def self.resolve(escalation_id, resolution_note)
    esc = ESCALATIONS.find { |e| e[:id] == escalation_id }
    return unless esc

    esc[:status] = "Resolved"
    esc[:resolution_note] = resolution_note
    esc[:resolved_at] = Time.now
  end

  private

  def self.risk_jump?(prev, current)
    levels = { "Low" => 1, "Medium" => 2, "High" => 3, "Critical" => 4 }
    return false unless prev && current

    levels[current] > levels[prev]
  end

  def self.determine_severity(reasons)
    return "Critical" if reasons.any? { |r| r.include?("Risk Volatility") }
    return "High" if reasons.any? { |r| r.include?("Stagnant") }

    "Medium"
  end
end

class NotificationService
  def self.notify_supervisor(escalation)
    # Simulate Slack/Email Notification
    puts "[NOTIFICATION] Sending to #{escalation[:supervisor_email]}: Case #{escalation[:case_id]} ESCALATED. Severity: #{escalation[:severity]}. Reasons: #{escalation[:reasons].join(' | ')}"
    # In real app: Net::SMTP or Slack API call
  end
end

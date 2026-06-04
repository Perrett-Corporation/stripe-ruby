# frozen_string_literal: true

require "date"

class ComplianceAggregator
  # Generates a timeline view for an entity
  def self.build_timeline(entity_id)
      # 1. Fetch Audit Logs
      logs = AuditLogService.list(entity_id: entity_id).map do |entry|
          {
              type: "audit",
              timestamp: entry.timestamp,
              description: "[#{entry.action}] - #{entry.details}",
              user: entry.user_id,
              severity: "info"
          }
      end

      # 2. Fetch Tasks
      tasks = TaskManagementService.list(entity_id: entity_id).map do |task|
          {
              type: "task",
              timestamp: task.due_date, # Or creation date really
              description: "Wait: Due #{task.due_date} - #{task.title}",
              user: task.assignee_id,
              severity: task.status == :completed ? "success" : "warning"
          }
      end

      # 3. Simulate screening results if they were persisted (here we mock retrieval)
      # Using audit log as a proxy for historic screenings
      screening_history = logs.select { |l| l[:description].include?("ENTITY_SCREENING") }.map do |l|
          risk = l[:details][:score] || 0
          severity = risk > 50 ? "danger" : "info"

          {
              type: "screening",
              timestamp: l[:timestamp],
              description: "Screening Check: Risk Score #{risk}",
              user: "system",
              severity: severity
          }
      end

      # 4. Merge & Sort
      (logs + tasks + screening_history).sort_by { |item| item[:timestamp] }.reverse
  end

  # Generates SAR narrative
  def self.generate_sar_narrative(entity_id, case_details = {})
    timeline = build_timeline(entity_id)

    # Analyze patterns
    high_risk_actions = timeline.select { |e| e[:severity] == "danger" || e[:description].include?("ESCALATED") }
    task_completion_status = timeline.select { |e| e[:type] == "task" && e[:severity] == "success" }.count
    total_tasks = timeline.select { |e| e[:type] == "task" }.count

    narrative = []
    narrative << "SUSPICIOUS ACTIVITY REPORT NARRATIVE"
    narrative << "------------------------------------"
    narrative << "SUBJECT: #{case_details[:name] || 'Unknown Entity'} (#{entity_id})"
    narrative << "DATE: #{Date.today}"
    narrative << ""
    narrative << "1. INTRODUCTION"
    narrative << "This report details suspicious activity involving the subject entity identified during routine compliance monitoring."
    narrative << ""
    narrative << "2. INVESTIGATION TIMELINE & KEY EVENTS"

    if high_risk_actions.any?
      narrative << "The investigation was triggered/escalated following these critical events:"
      high_risk_actions.each do |event|
        narrative << "- [#{event[:timestamp]}] #{event[:description]}"
      end
    else
      narrative << "Routine monitoring identified anomalies requiring review."
    end

    narrative << ""
    narrative << "3. SCREENING RESULTS"
    screening_events = timeline.select { |e| e[:type] == "screening" }
    if screening_events.any?
        narrative << "Third-party screening was conducted. #{screening_events.count} checks performed."
        narrative << "Latest risk assessment indicates potential concerns." if screening_events.first[:severity] == "danger"
    else
        narrative << "No adverse media or sanctions hits were recorded during this period."
    end

    narrative << ""
    narrative << "4. CONCLUSION & RECOMMENDATION"
    narrative << "Based on the #{total_tasks} remediation steps taken (of which #{task_completion_status} are complete), we recommend further monitoring."
    if high_risk_actions.count > 2
      narrative << "Due to multiple risk indicators, we are filing this SAR and freezing associated accounts pending LEA response."
    end

    narrative.join("\n")
  end
end

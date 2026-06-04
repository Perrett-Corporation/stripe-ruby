# frozen_string_literal: true

require "date"

class TaskManagementService
  STATUSES = %i[todo in_progress completed escalated]

  Task = Struct.new(:id, :title, :description, :assignee_id, :status, :due_date, :escalation_level, :priority,
                    :entity_id, keyword_init: true)

  @tasks = []

  class << self
    def create(title:, description:, entity_id:, assignee_id:, due_date:)
      priority = (due_date - Date.today).to_i < 3 ? "High" : "Normal"

      task = Task.new(
        id: "task_#{Time.now.to_i}_#{rand(100)}",
        title: title,
        description: description,
        assignee_id: assignee_id,
        status: :todo,
        due_date: due_date,
        escalation_level: 0,
        priority: priority,
        entity_id: entity_id
      )

      @tasks << task

      AuditLogService.log(
        user_id: "system",
        action: "TASK_CREATED",
        details: { task_id: task.id, assignee: assignee_id },
        entity_id: entity_id
      )

      task
    end

    def list(user_id = nil)
      if user_id
        @tasks.select { |t| t.assignee_id == user_id && t.status != :completed }
      else
        @tasks
      end
    end

    def find(task_id)
      @tasks.find { |t| t.id == task_id }
    end

    def update_status(task_id:, status:, user_id:)
      task = find(task_id)
      return unless task

      old_status = task.status
      task.status = status.to_sym

      AuditLogService.log(
        user_id: user_id,
        action: "TASK_STATUS_UPDATE",
        details: { from: old_status, to: status },
        entity_id: task.entity_id
      )

      # Check for auto-escalations if moving to blocked states etc.
      escalate(task_id) if status == :escalated

      task
    end

    def escalate(task_id)
      task = find(task_id)
      return unless task

      task.escalation_level += 1
      task.priority = "Urgent"

      # Simulate notification
      details = "Task #{task.id} escalated due to inaction or explicit request."
      puts "ESCALATION ALERT: #{details}"

      AuditLogService.log(
        user_id: "system",
        action: "TASK_ESCALATED",
        details: { level: task.escalation_level },
        entity_id: task.entity_id
      )
    end
  end
end

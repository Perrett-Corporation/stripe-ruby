# frozen_string_literal: true

require "time"
require "json"

class AuditLogService
  Entry = Struct.new(:id, :timestamp, :user_id, :action, :details, :entity_id, keyword_init: true)

  @logs = []

  class << self
    def log(user_id:, action:, details: {}, entity_id: nil)
      entry = Entry.new(
        id: "audit_#{Time.now.to_i}_#{rand(1000)}",
        timestamp: Time.now.utc,
        user_id: user_id,
        action: action,
        details: details,
        entity_id: entity_id
      )
      @logs << entry
      entry
    end

    def list(filters = {})
      @logs.select do |entry|
        filters.all? do |key, value|
          entry.public_send(key) == value
        end
      end.sort_by(&:timestamp).reverse
    end

    def export_csv
      headers = ["ID", "Timestamp", "User ID", "Action", "Entity ID", "Details"]
      rows = @logs.map do |entry|
        [
          entry.id,
          entry.timestamp.iso8601,
          entry.user_id,
          entry.action,
          entry.entity_id,
          entry.details.to_json,
        ]
      end
      ([headers] + rows).map { |row| row.join(",") }.join("\n")
    end
  end
end

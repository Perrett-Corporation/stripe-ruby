require 'sequel'
DB = Sequel.connect(ENV['QCF_DATABASE_URL'] || "sqlite://#{File.expand_path('../qcf.db', __FILE__)}")

unless DB.table_exists?(:ideas)
  DB.create_table :ideas do
    primary_key :id
    String :title, null: false
    String :description, text: true
    String :source
    DateTime :created_at
  end
end

unless DB.table_exists?(:tasks)
  DB.create_table :tasks do
    primary_key :id
    String :title, null: false
    String :description, text: true
    String :status, default: 'open'
    String :assignee
    DateTime :created_at
    DateTime :updated_at
  end
end

unless DB.table_exists?(:audit_logs)
  DB.create_table :audit_logs do
    primary_key :id
    String :event_type
    String :actor
    String :details, text: true
    DateTime :created_at
  end
end

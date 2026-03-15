require "sinatra"
require "stripe"
require "json"
require_relative "lib/sar_report"
require_relative "lib/aml_report"
require_relative "lib/compliance_training"
require_relative "lib/identity_verification"
require_relative "lib/media_screener"
require_relative "lib/investigation_service"
require_relative "lib/workflow_engine"
require_relative "lib/fincen_connector"
require_relative "lib/escalation_service"
require_relative "lib/shareholder_register_parser"
require_relative "lib/corporate_structure_map"
require_relative "lib/task_management_service"
require_relative "lib/audit_log_service"
require_relative "lib/screening_service"
require_relative "lib/compliance_aggregator"

# Configuration
set :port, 4567
set :bind, "0.0.0.0"
enable :sessions

# Mock Database
$reports = {}
$compliance_officer_key = OpenSSL::PKey::RSA.generate(2048) # In real app, this would be loaded from secure storage/HSM
$current_officer_id = "officer_1" # Simulated logged-in user

# Helper to fetch suspicious transactions from Stripe (or mock if no key)
def fetch_suspicious_transactions
  if ENV["STRIPE_SECRET_KEY"]
    Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
    # Example: Fetch charges that were refunded due to fraud or high risk disputes
    charges = Stripe::Charge.list(limit: 5) # simplified
    charges.data.map do |c|
      {
        id: c.id,
        amount: c.amount,
        currency: c.currency,
        created: c.created,
        description: c.description,
        suspicion_reason: "High Value / Manual Review", # simplified logic
        risk_score: 85,
        customer_id: c.customer,
      }
    end
  else
    # Mock Data
    [
      { id: "ch_mock_1", amount: 500_000, currency: "usd", created: Time.now.to_i, description: "Large transfer",
        suspicion_reason: "Structuring", risk_score: 90, customer_id: "cus_123", },
      { id: "ch_mock_2", amount: 1200, currency: "usd", created: Time.now.to_i - 3600,
        description: "Rapid multiple transactions", suspicion_reason: "Velocity", risk_score: 75, customer_id: "cus_456", },
    ]
  end
end

get "/" do
  @reports = $reports.values
  @training_status = ComplianceTraining.compliant?($current_officer_id)
  @identity_verified = session[:identity_verified]
  @automated_actions = WorkflowEngine.get_recent_actions
  erb :index
end

get "/training" do
  @training_status = ComplianceTraining.get_status($current_officer_id)
  @is_compliant = ComplianceTraining.compliant?($current_officer_id)
  erb :training
end

post "/training/complete" do
  ComplianceTraining.complete_training($current_officer_id, params[:training_id])
  redirect "/training"
end

get "/verify_identity" do
  erb :verify_identity
end

post "/verify_identity" do
  # Simulate document/selfie upload processing
  result = IdentityVerification.verify(params[:image_data], params[:image_data])

  if result[:success]
    session[:identity_verified] = true
    session[:message] = result[:message]
    redirect "/"
  else
    session[:error] = result[:error]
    redirect "/verify_identity"
  end
end

get "/risk_profiles" do
  # Screen all customers involved in current reports + some defaults
  entities = ["cus_123", "cus_456", "Tax Haven Corp"]
  @screened_entities = MediaScreener.batch_screen(entities)
  erb :risk_profiles
end

get "/escalations" do
  # Trigger the batch check on page load to detect new issues
  @new_alerts = EscalationService.run_batch_check(InvestigationService.list_open_investigations.values)
  @escalations = EscalationService.list_escalations
  erb :escalations
end

get "/corporate_structure/:case_id" do
  @case_id = params[:case_id]
  # In a real app, retrieve from Vault
  # doc = DocumentVaultService.list_documents_for_case(@case_id).find { |d| d.doc_type == "Shareholder Register" }
  # content = DocumentVaultService.retrieve_document(doc.id)

  # Mock Document Content (decrypted JSON)
  mock_content = {
    entity: "Global Import Export Ltd",
    country: "Cayman Islands",
    shareholders: [
      {
        name: "Shell Co Alpha",
        percentage: 40,
        type: "company",
        country: "Panama",
        subsidiaries: [
          { name: "Unknown Beneficiary", percentage: 100, type: "individual", country: "Russian Federation" },
        ],
      },
      {
        name: "Offshore Trust X",
        percentage: 30,
        type: "trust",
        country: "British Virgin Islands",
        subsidiaries: [
          { name: "Law Firm Nominee", percentage: 100, type: "individual", country: "Switzerland" },
        ],
      },
      { name: "John Smith", percentage: 30, type: "individual", country: "UK" },
    ],
  }.to_json

  parsed_data = ShareholderRegisterParser.parse(mock_content)
  map = CorporateStructureMap.new(parsed_data[:entity], parsed_data)

  @nodes = map.nodes
  @edges = map.edges
  @risks = map.risks

  erb :corporate_structure
end

post "/escalations/resolve" do
  EscalationService.resolve(params[:escalation_id], params[:resolution_note])
  session[:message] = "Escalation #{params[:escalation_id]} resolved."
  redirect "/escalations"
end

get "/sar/new" do
  @transactions = fetch_suspicious_transactions
  @open_cases = InvestigationService.list_open_investigations.values
  erb :new_sar
end

get "/sar/draft/:case_id" do
  @case_data = InvestigationService.get_case(params[:case_id])
  halt 404, "Case not found" unless @case_data

  # Gather intelligence
  @risk_profile = MediaScreener.screen_entity(@case_data[:subject_id])

  # Filter transactions for this case (mock logic: matching IDs)
  all_txs = fetch_suspicious_transactions

  # Ensure we have transaction IDs as strings/symbols consistent with mock data
  related_ids = @case_data[:related_transaction_ids]
  @related_transactions = all_txs.select { |tx| related_ids.include?(tx[:id]) }

  # Auto-generate narrative
  @draft_narrative = InvestigationService.generate_narrative(@case_data, @risk_profile, @related_transactions)

  erb :sar_draft
end

post "/sar/finalize" do
  report_id = "SAR-#{Time.now.to_i}"
  report = SARReport.new(report_id)

  # Populate from form
  report.subject_info = {
    name: params[:subject_name],
    address: params[:subject_address],
    id: params[:subject_id],
  }

  report.narrative = params[:narrative]

  # Add transactions (re-fetching or passing IDs would be cleaner, here we simplify)
  tx_ids = params[:transaction_ids].split(",")
  all_txs = fetch_suspicious_transactions
  all_txs.each do |tx|
    report.add_transaction(tx) if tx_ids.include?(tx[:id])
  end

  $reports[report_id] = report

  # Trigger Workflow Engine on Filing
  WorkflowEngine.evaluate_sar_filing(report)

  redirect "/"
end

get "/aml/new" do
  @transactions = fetch_suspicious_transactions
  erb :new_aml
end

post "/aml/create" do
  report_id = "AML-#{Time.now.to_i}"
  report = AMLReviewReport.new(report_id, Date.today - 30, Date.today)

  selected_ids = params[:transactions] || []

  # Fetch all potential transactions and filter by selected IDs
  all_suspicious = fetch_suspicious_transactions

  all_suspicious.each do |tx|
    report.add_transaction(tx) if selected_ids.include?(tx[:id])
  end

  $reports[report_id] = report
  redirect "/"
end

post "/sar/create" do
  report_id = "SAR-#{Time.now.to_i}"
  report = SARReport.new(report_id)

  selected_ids = params[:transactions] || []

  # Fetch all potential transactions and filter by selected IDs
  all_suspicious = fetch_suspicious_transactions

  all_suspicious.each do |tx|
    report.add_transaction(tx) if selected_ids.include?(tx[:id])
  end

  $reports[report_id] = report
  redirect "/"
end

post "/reports/:id/sign" do
  is_trained = ComplianceTraining.compliant?($current_officer_id)
  is_verified = session[:identity_verified]

  unless is_trained
    session[:error] = "Compliance Training Incomplete. Cannot sign reports."
    redirect "/training"
  end

  unless is_verified
    session[:error] = "Identity Verification Required. Please verify your identity."
    redirect "/verify_identity"
  end

  report = $reports[params[:id]]
  if report
    report.sign!($compliance_officer_key.to_pem)
    session[:message] = "Report #{params[:id]} digitally signed."
  end
  redirect "/"
end

get "/reports/:id/export/xml" do
  report = $reports[params[:id]]
  content_type "application/xml"
  attachment "#{params[:id]}.xml"
  report.export_xml
end

get "/reports/:id/export/pdf" do
  report = $reports[params[:id]]
  content_type "application/pdf"
  attachment "#{params[:id]}.pdf"

  # Generate PDF to a temporary buffer/file and stream it
  pdf_path = "/tmp/#{params[:id]}.pdf"
  report.export_pdf(pdf_path)
  File.read(pdf_path)
end

post "/reports/:id/submit" do
  report = $reports[params[:id]]
  begin
    # Secure Submission via FinCEN Connector
    result = FinCENConnector.submit_filing(report)

    # Auto-update status
    report.status = "SUBMITTED"

    # Poll for immediate acknowledgment (in background for real app, inline here for demo)
    status_update = FinCENConnector.poll_status(result[:tracking_id])

    session[:message] =
      "Report submitted securely to FinCEN. BSA ID: #{result[:tracking_id]}. Status: #{status_update[:status]} (ACK: #{status_update[:acknowledgment_code]})"
  rescue StandardError => e
    session[:error] = "Submission failed: #{e.message}"
  end
  redirect "/"
end

# --- New Features Logic ---

# 1. Task Management
get "/tasks" do
  AuditLogService.log(
    user_id: $current_officer_id,
    action: "TASK_VIEW_ALL",
    details: { timestamp: Time.now.to_i }
  )
  @my_tasks = TaskManagementService.list($current_officer_id)
  @all_tasks = TaskManagementService.list
  erb :tasks
end

get "/tasks/new" do
  @entity_id = params[:entity_id]
  erb :tasks # Reusing view or could be distinct form
end

post "/tasks/new" do
  TaskManagementService.create(
    title: params[:title],
    description: params[:description],
    entity_id: params[:entity_id],
    assignee_id: params[:assignee_id] || $current_officer_id,
    due_date: Date.parse(params[:due_date])
  )
  redirect "/entity_timeline/#{params[:entity_id]}"
end

post "/tasks/:id/complete" do
  TaskManagementService.update_status(
    task_id: params[:id],
    status: :completed,
    user_id: $current_officer_id
  )
  redirect back
end

post "/tasks/:id/escalate" do
  TaskManagementService.update_status(
    task_id: params[:id],
    status: :escalated,
    user_id: $current_officer_id
  )
  redirect back
end

# 2. Audit Logs
get "/audit_log" do
  @logs = AuditLogService.list
  erb :audit_log
end

get "/audit_log/export" do
  content_type "text/csv"
  attachment "compliance_audit_log_#{Time.now.to_i}.csv"
  AuditLogService.export_csv
end

# 3. Entity Timeline & Screening
get "/entity_timeline/:entity_id" do
  @entity_id = params[:entity_id]
  @entity_name = "Unknown Corp" # Would fetch from DB
  
  # Trigger auto-screening if requested or if timeline empty
  if params[:screen]
    @screening_result = ScreeningService.check(@entity_name, @entity_id)
  end

  @timeline = ComplianceAggregator.build_timeline(@entity_id)
  erb :entity_timeline
end

get "/screen/:entity_id" do
  @entity_id = params[:entity_id]
  @entity_name = params[:name]
  
  # Run check
  @screening_result = ScreeningService.check(@entity_name, @entity_id)
  
  # Refresh timeline view
  @timeline = ComplianceAggregator.build_timeline(@entity_id)
  erb :entity_timeline
end

# 4. SAR Generation
get "/generate_sar/:entity_id" do
  @entity_id = params[:entity_id]
  @entity_name = "Unknown Corp" # Would fetch from DB
  @officer_id = $current_officer_id
  
  @narrative = ComplianceAggregator.generate_sar_narrative(@entity_id, name: @entity_name)
  
  # Fetch docs from vault (mocked in app.rb usually, but we will mock a list here)
  @documents = [
    { id: "doc_1", filename: "passports.pdf", uploaded_at: "2024-02-10" },
    { id: "doc_2", filename: "bank_statements.pdf", uploaded_at: "2024-02-11" }
  ]
  
  AuditLogService.log(
    user_id: $current_officer_id,
    action: "SAR_DRAFT_GENERATED",
    details: { entity: @entity_id },
    entity_id: @entity_id
  )
  
  erb :sar_report
end


class InvestigationService
  require_relative "document_vault_service"

  def self.list_open_investigations
    OPEN_CASES
  end

  def self.get_case_documents(case_id)
    DocumentVaultService.list_documents_for_case(case_id)
  end

  # Mock database of open investigations
  OPEN_CASES = {
    "CASE-2026-001" => {
      id: "CASE-2026-001",
      subject_id: "cus_123",
      subject_name: "Global Import Export Ltd", # Mock business name
      subject_address: "123 Shell Co Lane, Cayman Islands",
      status: "Review", # Stuck in Review
      opened_at: "2026-02-15",
      status_changed_at: "2026-02-20", # Stuck for > 2 weeks
      risk_level: "High",
      previous_risk_level: "Medium", # Risk volatility
      related_transaction_ids: ["ch_mock_1"], # Matches mock data in app.rb
      notes: "Pattern of large round-number wire transfers just below reporting thresholds. Subject entity has no clear online presence.",
      assigned_to: "investigator_A",
      supervisor_email: "supervisor@example.com",
    },
    "CASE-2026-002" => {
      id: "CASE-2026-002",
      subject_id: "cus_456",
      subject_name: "John Doe",
      subject_address: "456Suburbia Dr, Springfield",
      status: "Review",
      opened_at: "2026-03-01",
      status_changed_at: "2026-03-10",
      risk_level: "Medium",
      previous_risk_level: "Medium",
      related_transaction_ids: ["ch_mock_2"],
      notes: "Rapid velocity of small transactions followed by immediate withdrawal.",
      assigned_to: "investigator_B",
      supervisor_email: "supervisor@example.com",
    },
    "CASE-2026-003" => {
      id: "CASE-2026-003",
      subject_id: "cus_789",
      subject_name: "Crypto Ventures LLC",
      subject_address: "789 Blockchain Blvd",
      status: "Open",
      opened_at: "2025-11-15", # Very old case
      status_changed_at: "2025-11-15",
      risk_level: "Critical",
      previous_risk_level: "High",
      related_transaction_ids: [],
      notes: "Dormant account suddenly active with high volume.",
      assigned_to: "investigator_A", # Overloaded investigator
      supervisor_email: "chief_compliance@example.com",
    },
    "CASE-2026-004" => {
      id: "CASE-2026-004",
      subject_id: "cus_999",
      subject_name: "Tax Haven Corp",
      subject_address: "123 Offshore Blvd",
      status: "Review",
      opened_at: "2026-01-20",
      status_changed_at: "2026-01-25",
      risk_level: "High",
      previous_risk_level: "Medium",
      related_transaction_ids: [],
      notes: "Linked to Panama Papers entities.",
      assigned_to: "investigator_C",
      supervisor_email: "supervisor@example.com",
    },
    "CASE-2026-005" => {
      id: "CASE-2026-005",
      subject_id: "cus_000",
      subject_name: "Warlord Y",
      subject_address: "Unknown Location",
      status: "Blocked",
      opened_at: "2024-05-01",
      status_changed_at: "2024-05-02",
      risk_level: "Critical",
      previous_risk_level: "Critical",
      related_transaction_ids: [],
      notes: "Internationally sanctioned individual.",
      assigned_to: "security_team",
      supervisor_email: "legal@example.com",
    },
  }

  def self.list_open_cases
    OPEN_CASES.values
  end

  def self.get_case(case_id)
    OPEN_CASES[case_id]
  end

  def self.generate_narrative(case_data, risk_profile, transactions)
    # Intelligence logic to auto-draft the SAR narrative

    narrative = []
    narrative << "INTRODUCTION: This SAR is being filed pursuant to an internal investigation (#{case_data[:id]}) initiated on #{case_data[:opened_at]} regarding #{case_data[:subject_name]}."

    narrative << "\nINVESTIGATION FINDINGS: #{case_data[:notes]}"

    if risk_profile && risk_profile[:risk_level] != "Low"
      narrative << "\nADVERSE MEDIA SCREENING: The subject entity was flagged with a risk level of '#{risk_profile[:risk_level]}'. Significant hits include: #{risk_profile[:hits].map do |h|
        h[:snippet]
      end.join('; ')}."
    end

    total_amount = transactions.sum { |t| t[:amount] }
    currency = transactions.first ? transactions.first[:currency].upcase : "USD"
    narrative << "\nTRANSACTION ACTIVITY: The activity reported involves #{transactions.count} transaction(s) totaling #{total_amount} #{currency}. The nature of these transactions (#{transactions.map do |t|
      t[:suspicion_reason]
    end.uniq.join(', ')}) is inconsistent with the customer's expected profile."

    narrative << "\nCONCLUSION: Based on the combination of transaction patterns and adverse media hits, we suspect potential money laundering / structuring."

    narrative.join("\n")
  end
end

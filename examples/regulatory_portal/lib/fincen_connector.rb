require "json"
require "time"

class FinCENConnector
  # Mock Endpoint configuration
  BSA_API_ENDPOINT = "https://bsaefiling.fincen.treas.gov/api/v1/submission"

  def self.submit_filing(report)
    # Simulate secure handshake and transmission latency
    sleep 1.5

    # Mock validation logic
    raise "API Error: Report must be digitally signed before submission." if report.status != "signed"

    # Generate a Mock BSA ID (Tracking Number)
    tracking_id = "BSA-#{Time.now.strftime('%Y%m%d')}-#{rand(10_000).to_s.rjust(6, '0')}"

    # Mock API Response
    {
      success: true,
      tracking_id: tracking_id,
      status: "RECEIVED",
      received_at: Time.now.iso8601,
      message: "Submission received successfully. Awaiting validation.",
      filing_type: report.type,
    }
  end

  def self.poll_status(tracking_id)
    # Simulate polling status updates
    sleep 0.5

    # Mock status progression
    {
      tracking_id: tracking_id,
      status: "ACCEPTED", # Could be VALIDATED, REJECTED, ACCEPTED
      acknowledgment_code: "ACK-#{SecureRandom.hex(4).upcase}",
      processed_at: Time.now.iso8601,
    }
  end
end

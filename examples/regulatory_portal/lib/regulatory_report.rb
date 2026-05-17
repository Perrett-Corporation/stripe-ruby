require "openssl"
require "base64"
require "builder"
require "prawn"
require "date"

class RegulatoryReport
  attr_accessor :report_id, :type, :created_at, :status, :transactions, :officer_signature

  def initialize(report_id, type)
    @report_id = report_id
    @type = type
    @created_at = DateTime.now
    @status = "draft"
    @transactions = []
    @officer_signature = nil
  end

  def add_transaction(transaction_data)
    @transactions << transaction_data
  end

  # Simulates digital signing of the report content using a private key
  def sign!(private_key_pem)
    content_to_sign = generate_signature_content
    digest = OpenSSL::Digest.new("SHA256")
    pkey = OpenSSL::PKey::RSA.new(private_key_pem)
    signature = pkey.sign(digest, content_to_sign)
    @officer_signature = Base64.strict_encode64(signature)
    @status = "signed"
    puts "Report #{@report_id} signed successfully."
  end

  def export_xml
    # To be implemented by subclasses or generic XML builder
    raise NotImplementedError
  end

  def export_pdf
    # To be implemented by subclasses or generic PDF builder
    raise NotImplementedError
  end

  # Mock submission to regulatory authority API
  def submit_to_authority!(authority_url)
    raise "Report must be signed before submission." if @status != "signed"

    puts "Submitting Report #{@report_id} to #{authority_url}..."
    # strict implementation would use Net::HTTP to post the XML/PDF
    # This is a simulation.
    { success: true, submission_id: "SUB-#{Time.now.to_i}", timestamp: Time.now }
  end

  private

  def generate_signature_content
    # Simple concatenation of report data for signing
    "#{@report_id}|#{@type}|#{@created_at}|#{@transactions.map { |t| t[:id] }.join(',')}"
  end
end

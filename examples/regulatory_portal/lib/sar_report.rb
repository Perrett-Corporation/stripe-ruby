require_relative "regulatory_report"

class SARReport < RegulatoryReport
  attr_accessor :subject_info, :narrative

  def initialize(report_id)
    super(report_id, "SAR")
    @subject_info = {}
    @narrative = ""
  end

  def export_xml
    # XML format compatible with FinCEN SAR specifications (mock)
    builder = Builder::XmlMarkup.new(indent: 2)
    builder.instruct!
    builder.SARSubmission("xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance") do |sar|
      sar.Header do
        sar.ReportID @report_id
        sar.Type @type
        sar.Date @created_at.to_s
        sar.Signature @officer_signature if @officer_signature
      end

      if @subject_info && !@subject_info.empty?
        sar.SubjectInformation do
          sar.Name @subject_info[:name]
          sar.Address @subject_info[:address]
          sar.ID @subject_info[:id]
        end
      end

      sar.Activity do
        @transactions.each do |tx|
          sar.SuspiciousActivity do
            sar.TransactionID tx[:id]
            sar.Amount tx[:amount]
            sar.Currency tx[:currency]
            sar.Date tx[:created]
            sar.Description tx[:description]
            sar.Reason tx[:suspicion_reason]
          end
        end
      end

      if @narrative && !@narrative.empty?
        sar.Narrative do
          sar.Text @narrative
        end
      end
    end
  end

  def export_pdf(file_path)
    Prawn::Document.generate(file_path) do |pdf|
      pdf.text "Suspicious Activity Report (SAR)", size: 20, style: :bold
      pdf.move_down 20
      pdf.text "Report ID: #{@report_id}"
      pdf.text "Date: #{@created_at}"
      pdf.text "Status: #{@status}"

      if @officer_signature
        pdf.move_down 10
        pdf.text "Digitally Signed: Yes", color: "008000"
        pdf.text "Signature: #{@officer_signature[0..50]}...", size: 8, color: "808080"
      else
        pdf.move_down 10
        pdf.text "Not Signed", color: "FF0000"
      end

      pdf.move_down 20
      pdf.text "Subject Information:", style: :bold
      if @subject_info && !@subject_info.empty?
        pdf.text "Name: #{@subject_info[:name]}"
        pdf.text "Address: #{@subject_info[:address]}"
        pdf.text "ID: #{@subject_info[:id]}"
      else
        pdf.text "N/A"
      end

      pdf.move_down 20
      pdf.text "Suspicious Transactions:", style: :bold

      @transactions.each do |tx|
        pdf.move_down 10
        pdf.text "Transaction ID: #{tx[:id]}"
        pdf.text "Amount: #{tx[:amount]} #{tx[:currency].upcase}"
        pdf.text "Date: #{Time.at(tx[:created])}"
        pdf.text "Reason: #{tx[:suspicion_reason]}"
        pdf.stroke_horizontal_rule
      end

      if @narrative && !@narrative.empty?
        pdf.start_new_page
        pdf.text "Narrative / Conclusion:", style: :bold, size: 14
        pdf.move_down 10
        pdf.text @narrative
      end

      pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 150, 0], width: 150, align: :right
    end
  end
end

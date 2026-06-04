require_relative "regulatory_report"

class AMLReviewReport < RegulatoryReport
  def initialize(report_id, review_period_start, review_period_end)
    super(report_id, "AML-REVIEW")
    @period_start = review_period_start
    @period_end = review_period_end
  end

  def export_xml
    builder = Builder::XmlMarkup.new(indent: 2)
    builder.instruct!
    builder.AMLReviewSubmission do |aml|
      aml.Header do
        aml.ReportID @report_id
        aml.Type @type
        aml.ReviewPeriodStart @period_start
        aml.ReviewPeriodEnd @period_end
        aml.Date @created_at.to_s
        aml.Signature @officer_signature if @officer_signature
      end
      aml.FlaggedTransactions do
        @transactions.each do |tx|
          aml.Transaction do
            aml.ID tx[:id]
            aml.Amount tx[:amount]
            aml.RiskScore tx[:risk_score]
            aml.Customer tx[:customer_id]
          end
        end
      end
    end
  end

  def export_pdf(file_path)
    Prawn::Document.generate(file_path) do |pdf|
      pdf.text "Anti-Money Laundering (AML) Review Report", size: 20, style: :bold
      pdf.move_down 20
      pdf.text "Report ID: #{@report_id}"
      pdf.text "Review Period: #{@period_start} to #{@period_end}"
      pdf.text "Date Generated: #{@created_at}"
      pdf.text "Status: #{@status}"

      if @officer_signature
        pdf.move_down 10
        pdf.text "Digitally Signed by Compliance Officer", color: "008000"
      else
        pdf.move_down 10
        pdf.text "Draft - Pending Signature", color: "FF0000"
      end

      pdf.move_down 20
      pdf.text "Flagged High-Risk Transactions:", style: :bold

      data = [["ID", "Amount", "Risk Score", "Customer"]]
      @transactions.each do |tx|
        data << [tx[:id], "#{tx[:amount]} #{tx[:currency].upcase}", tx[:risk_score].to_s, tx[:customer_id]]
      end

      pdf.table(data, header: true, width: pdf.bounds.width) do
        row(0).style(font_style: :bold, background_color: "CCCCCC")
      end
    end
  end
end

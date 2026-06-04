require "json"

class ShareholderRegisterParser
  # Parses a decrypted document (as string) representing a shareholder register.
  # For this demo, we assume the document is a JSON string describing the structure.
  def self.parse(document_content)
    data = JSON.parse(document_content, symbolize_names: true)

    # Basic validation
    raise "Invalid Register Format" unless data[:entity] && data[:shareholders]

    data
  rescue JSON::ParserError
    # Fallback for demo if it's not JSON (e.g. PDF content simulation)
    # In a real system, OCR/NLP would extract this
    {
      entity: "Unknown Entity (Parse Error)",
      shareholders: [],
    }
  end
end

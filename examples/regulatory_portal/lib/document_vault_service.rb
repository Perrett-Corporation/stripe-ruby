require "openssl"
require "base64"
require "json"
require "fileutils"
require "securerandom"

class DocumentVaultService
  # Configuration for encryption
  CIPHER_ALGO = "aes-256-gcm"
  # In a real app, this key would be in a secure Key Management System (KMS) or HSM
  VAULT_MASTER_KEY = OpenSSL::Random.random_bytes(32)

  # Simulation of a secure storage backend (e.g., S3 bucket with restricted access)
  STORAGE_DIR = File.expand_path("../vault_storage", __dir__)
  FileUtils.mkdir_p(STORAGE_DIR)

  # Database linking documents to cases/entities
  DOCUMENT_REGISTRY = {}

  # Registry of OCR results and case tags keyed by document ID
  OCR_REGISTRY  = {}
  CASE_TAG_REGISTRY = {}  # case_id => [doc_id, ...]

  # Supported document categories
  CATEGORIES = %w[
    Passport
    National\ ID
    Bank\ Statement
    Corporate\ Registration
    Shareholder\ Register
    Proof\ of\ Address
    Financial\ Statement
    Sanctions\ Letter
    Court\ Order
    Other
  ].freeze

  # Fraud patterns that the OCR analysis looks for
  FRAUD_PATTERNS = {
    "structuring"           => /structur|smurfing|\bbelow.{0,20}threshold/i,
    "money_laundering"      => /money.laundering|layering|placement|integration/i,
    "shell_company"         => /shell.compan|nominee|bearer.share|offshore.vehicle/i,
    "sanctions_evasion"     => /sanction.evasion|circumvent.sanction|blocked.country/i,
    "fraud"                 => /fraud|falsif|forger|counterfeit|misrepresent/i,
    "bribery_corruption"    => /bribe|corrupt|kickback|facilitation.payment/i,
    "tax_evasion"           => /tax.evasion|undeclared|hidden.account|offshore.income/i,
    "pep_connection"        => /politically.exposed|senior.official|government.official|minister|president/i,
  }.freeze

  class VaultDocument
    attr_reader :id, :filename, :entity_id, :case_id, :doc_type, :category,
                :uploaded_at, :encryption_metadata
    attr_accessor :ocr_text, :detected_patterns, :tagged_cases

    def initialize(id, filename, entity_id, case_id, doc_type, uploaded_at,
                   encryption_metadata, category: "Other")
      @id                  = id
      @filename            = filename
      @entity_id           = entity_id
      @case_id             = case_id
      @doc_type            = doc_type
      @category            = category
      @uploaded_at         = uploaded_at
      @encryption_metadata = encryption_metadata
      @ocr_text            = nil
      @detected_patterns   = []
      @tagged_cases        = []
    end

    def to_h
      {
        id:                @id,
        filename:          @filename,
        entity_id:         @entity_id,
        case_id:           @case_id,
        doc_type:          @doc_type,
        category:          @category,
        uploaded_at:       @uploaded_at.to_s,
        ocr_processed:     !@ocr_text.nil?,
        detected_patterns: @detected_patterns,
        tagged_cases:      @tagged_cases,
      }
    end
  end

  # Upload a document, encrypt it, and optionally run OCR + case tagging.
  #
  # @param entity_id  [String]
  # @param case_id    [String, nil]
  # @param filepath   [String]  Path to the source file on disk
  # @param doc_type   [String]  MIME type or informal type
  # @param category   [String]  One of CATEGORIES
  # @param run_ocr    [Boolean] Whether to immediately run OCR after upload
  def self.upload_document(entity_id:, case_id:, filepath:, doc_type:,
                           category: "Other", run_ocr: false)
    raise "File not found: #{filepath}" unless File.exist?(filepath)

    filename     = File.basename(filepath)
    file_content = File.read(filepath)
    doc_id       = "doc_#{Time.now.to_i}_#{::SecureRandom.hex(4)}"

    # 1. Encrypt the Content
    cipher = OpenSSL::Cipher.new(CIPHER_ALGO)
    cipher.encrypt
    cipher.key = VAULT_MASTER_KEY
    iv         = cipher.random_iv
    cipher.iv  = iv

    # Authenticated Encryption (GCM) — bind ciphertext to document context
    cipher.auth_data = "#{doc_id}#{entity_id}"

    encrypted_content = cipher.update(file_content) + cipher.final
    auth_tag          = cipher.auth_tag

    # 2. Store the Encrypted Blob
    storage_path = File.join(STORAGE_DIR, "#{doc_id}.enc")
    File.binwrite(storage_path, encrypted_content)

    # 3. Store Metadata & Encryption Params (IV, Tag) — key is never persisted here
    metadata = {
      iv:       Base64.strict_encode64(iv),
      auth_tag: Base64.strict_encode64(auth_tag),
    }

    document = VaultDocument.new(
      doc_id, filename, entity_id, case_id, doc_type,
      Time.now, metadata, category: category
    )

    # 4. Link to Registry
    DOCUMENT_REGISTRY[doc_id] = document

    # 5. Tag document to case
    tag_document_to_case(doc_id, case_id) if case_id

    # 6. Optionally run OCR immediately
    process_ocr(doc_id) if run_ocr

    puts "[Vault] Document uploaded and encrypted: #{doc_id} (Type: #{doc_type}, Category: #{category})"
    document
  end

  # Upload raw content (e.g. from a Rack multipart upload) without a file on disk.
  def self.upload_content(entity_id:, case_id:, filename:, content:, doc_type:,
                          category: "Other", run_ocr: false)
    doc_id = "doc_#{Time.now.to_i}_#{::SecureRandom.hex(4)}"

    cipher = OpenSSL::Cipher.new(CIPHER_ALGO)
    cipher.encrypt
    cipher.key = VAULT_MASTER_KEY
    iv         = cipher.random_iv
    cipher.iv  = iv
    cipher.auth_data = "#{doc_id}#{entity_id}"

    encrypted_content = cipher.update(content) + cipher.final
    auth_tag          = cipher.auth_tag

    storage_path = File.join(STORAGE_DIR, "#{doc_id}.enc")
    File.binwrite(storage_path, encrypted_content)

    metadata = {
      iv:       Base64.strict_encode64(iv),
      auth_tag: Base64.strict_encode64(auth_tag),
    }

    document = VaultDocument.new(
      doc_id, filename, entity_id, case_id, doc_type,
      Time.now, metadata, category: category
    )

    DOCUMENT_REGISTRY[doc_id] = document
    tag_document_to_case(doc_id, case_id) if case_id
    process_ocr(doc_id) if run_ocr

    puts "[Vault] Content uploaded and encrypted: #{doc_id} (#{filename})"
    document
  end

  def self.retrieve_document(doc_id)
    document = DOCUMENT_REGISTRY[doc_id]
    raise "Document not found" unless document

    storage_path = File.join(STORAGE_DIR, "#{doc_id}.enc")
    raise "Storage corruption: File missing for #{doc_id}" unless File.exist?(storage_path)

    encrypted_content = File.binread(storage_path)
    metadata          = document.encryption_metadata

    cipher = OpenSSL::Cipher.new(CIPHER_ALGO)
    cipher.decrypt
    cipher.key      = VAULT_MASTER_KEY
    cipher.iv       = Base64.strict_decode64(metadata[:iv])
    cipher.auth_tag = Base64.strict_decode64(metadata[:auth_tag])
    cipher.auth_data = "#{doc_id}#{document.entity_id}"

    begin
      decrypted_content = cipher.update(encrypted_content) + cipher.final
      puts "[Vault] Document decrypted successfully: #{document.filename}"
      decrypted_content
    rescue OpenSSL::Cipher::CipherError
      puts "[Vault] ALERT: Decryption failed. Integrity check failed or key mismatch."
      nil
    end
  end

  # Run OCR on a stored document and detect fraud patterns in the extracted text.
  # Returns the OCR result hash.  In production this would call a real OCR API
  # (e.g. AWS Textract, Google Vision, or Tesseract).  Here we simulate it by
  # decrypting and reading plaintext content.
  def self.process_ocr(doc_id)
    document = DOCUMENT_REGISTRY[doc_id]
    raise "Document not found: #{doc_id}" unless document

    raw_text = retrieve_document(doc_id) || ""

    # Simulate OCR extraction — in real life this would call an OCR engine
    extracted_text = simulate_ocr_extraction(document.filename, raw_text)

    # Detect fraud patterns in the extracted text
    detected = detect_fraud_patterns(extracted_text)

    # Persist OCR results onto the document record
    document.ocr_text          = extracted_text
    document.detected_patterns = detected

    # Propagate pattern tags to all associated cases
    document.tagged_cases.each do |cid|
      annotate_case_with_patterns(cid, doc_id, detected)
    end

    ocr_result = {
      doc_id:            doc_id,
      filename:          document.filename,
      extracted_text:    extracted_text,
      detected_patterns: detected,
      processed_at:      Time.now.utc,
    }
    OCR_REGISTRY[doc_id] = ocr_result

    AuditLogService.log(
      user_id:   "system_ocr_bot",
      action:    "DOCUMENT_OCR_PROCESSED",
      details:   { doc_id: doc_id, patterns_found: detected.map { |p| p[:pattern] } },
      entity_id: document.entity_id
    )

    puts "[OCR] Processed #{document.filename}: #{detected.count} pattern(s) detected."
    ocr_result
  end

  # Explicitly tag a document to a case (beyond the case_id set at upload).
  def self.tag_document_to_case(doc_id, case_id)
    document = DOCUMENT_REGISTRY[doc_id]
    return unless document

    document.tagged_cases |= [case_id]
    CASE_TAG_REGISTRY[case_id] ||= []
    CASE_TAG_REGISTRY[case_id] |= [doc_id]

    # If OCR has already been run, propagate patterns to the newly tagged case
    if (ocr = OCR_REGISTRY[doc_id])
      annotate_case_with_patterns(case_id, doc_id, ocr[:detected_patterns])
    end
  end

  # Holds per-case OCR annotations: case_id => [{doc_id, pattern, snippet, …}]
  CASE_ANNOTATIONS = {}

  def self.list_case_annotations(case_id)
    CASE_ANNOTATIONS[case_id] || []
  end

  def self.get_ocr_result(doc_id)
    OCR_REGISTRY[doc_id]
  end

  def self.list_documents_for_case(case_id)
    DOCUMENT_REGISTRY.values.select { |doc| doc.case_id == case_id || doc.tagged_cases.include?(case_id) }
  end

  def self.list_documents_for_entity(entity_id)
    DOCUMENT_REGISTRY.values.select { |doc| doc.entity_id == entity_id }
  end

  # ── Private helpers ──────────────────────────────────────────────────────────
  private_class_method def self.simulate_ocr_extraction(filename, raw_text)
    # If the raw content looks like plain text, return it directly.
    # For binary or empty content, produce a simulated extraction keyed by filename.
    return raw_text if raw_text.encoding == Encoding::UTF_8 && raw_text =~ /\w/

    # Fallback simulation based on filename keywords
    case filename.downcase
    when /bank|statement/
      "BANK STATEMENT\nAccount Holder: Global Import Export Ltd\n" \
        "Transactions indicate structuring below reporting threshold.\n" \
        "Multiple cash deposits of $9,800 on consecutive days.\n" \
        "Offshore wire transfers to Cayman Islands account."
    when /passport|id|identification/
      "PASSPORT\nHolder: Unknown Beneficiary\nNationality: Russian Federation\n" \
        "Issue Date: 2019-04-15\nExpiry: 2029-04-14"
    when /incorporation|registration|certificate/
      "CERTIFICATE OF INCORPORATION\nCompany: Shell Co Alpha\n" \
        "Registered: Panama\nNominee Director: Law Firm Nominee\n" \
        "Bearer shares issued to offshore trust."
    when /shareholder|register/
      "SHAREHOLDER REGISTER\nEntity: Offshore Trust X\n" \
        "Beneficiary: Unknown Beneficiary (100%)\nNo beneficial owner declared.\n" \
        "Possible sanctions evasion vehicle."
    else
      "DOCUMENT: #{filename}\nContent extracted via OCR simulation.\n" \
        "No specific fraud indicators automatically detected from filename."
    end
  end

  private_class_method def self.detect_fraud_patterns(text)
    return [] if text.nil? || text.strip.empty?

    FRAUD_PATTERNS.filter_map do |pattern_key, regex|
      matches = text.scan(regex)
      next if matches.empty?

      # Extract a short snippet showing context
      match_data = regex.match(text)
      snippet = if match_data
        start = [match_data.begin(0) - 40, 0].max
        finish = [match_data.end(0) + 40, text.length].min
        "…#{text[start...finish].strip}…"
      else
        ""
      end

      {
        pattern: pattern_key,
        label:   pattern_key.gsub("_", " ").split.map(&:capitalize).join(" "),
        count:   matches.length,
        snippet: snippet,
      }
    end
  end

  private_class_method def self.annotate_case_with_patterns(case_id, doc_id, patterns)
    return if patterns.nil? || patterns.empty?

    CASE_ANNOTATIONS[case_id] ||= []
    patterns.each do |p|
      annotation = {
        doc_id:     doc_id,
        filename:   DOCUMENT_REGISTRY[doc_id]&.filename,
        pattern:    p[:pattern],
        label:      p[:label],
        snippet:    p[:snippet],
        tagged_at:  Time.now.utc,
      }
      # Avoid exact duplicates
      unless CASE_ANNOTATIONS[case_id].any? { |a| a[:doc_id] == doc_id && a[:pattern] == p[:pattern] }
        CASE_ANNOTATIONS[case_id] << annotation
      end
    end
  end
end

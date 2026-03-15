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

  class VaultDocument
    attr_reader :id, :filename, :entity_id, :case_id, :doc_type, :uploaded_at, :encryption_metadata

    def initialize(id, filename, entity_id, case_id, doc_type, uploaded_at, encryption_metadata)
      @id = id
      @filename = filename
      @entity_id = entity_id
      @case_id = case_id
      @doc_type = doc_type
      @uploaded_at = uploaded_at
      @encryption_metadata = encryption_metadata
    end

    def to_h
      {
        id: @id,
        filename: @filename,
        entity_id: @entity_id,
        case_id: @case_id,
        doc_type: @doc_type,
        uploaded_at: @uploaded_at.to_s,
      }
    end
  end

  def self.upload_document(entity_id:, case_id:, filepath:, doc_type:)
    raise "File not found: #{filepath}" unless File.exist?(filepath)

    filename = File.basename(filepath)
    file_content = File.read(filepath)
    doc_id = "doc_#{Time.now.to_i}_#{::SecureRandom.hex(4)}"

    # 1. Encrypt the Content
    cipher = OpenSSL::Cipher.new(CIPHER_ALGO)
    cipher.encrypt
    cipher.key = VAULT_MASTER_KEY
    iv = cipher.random_iv
    cipher.iv = iv

    # Authenticated Encryption (GCM)
    cipher.auth_data = "#{doc_id}#{entity_id}" # Bind encryption to the document context

    encrypted_content = cipher.update(file_content) + cipher.final
    auth_tag = cipher.auth_tag

    # 2. Store the Encrypted Blob
    storage_path = File.join(STORAGE_DIR, "#{doc_id}.enc")
    File.binwrite(storage_path, encrypted_content)

    # 3. Store Metadata & Encryption Params (IV, Tag)
    # We do NOT store the key here.
    metadata = {
      iv: Base64.strict_encode64(iv),
      auth_tag: Base64.strict_encode64(auth_tag),
    }

    document = VaultDocument.new(
      doc_id,
      filename,
      entity_id,
      case_id,
      doc_type,
      Time.now,
      metadata
    )

    # 4. Link to Registry
    DOCUMENT_REGISTRY[doc_id] = document

    puts "[Vault] Document uploaded and encrypted: #{doc_id} (Type: #{doc_type})"
    document
  end

  def self.retrieve_document(doc_id)
    document = DOCUMENT_REGISTRY[doc_id]
    raise "Document not found" unless document

    storage_path = File.join(STORAGE_DIR, "#{doc_id}.enc")
    raise "Storage corruption: File missing for #{doc_id}" unless File.exist?(storage_path)

    encrypted_content = File.binread(storage_path)
    metadata = document.encryption_metadata

    # 1. Decrypt
    cipher = OpenSSL::Cipher.new(CIPHER_ALGO)
    cipher.decrypt
    cipher.key = VAULT_MASTER_KEY
    cipher.iv = Base64.strict_decode64(metadata[:iv])
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

  def self.list_documents_for_case(case_id)
    DOCUMENT_REGISTRY.values.select { |doc| doc.case_id == case_id }
  end

  def self.list_documents_for_entity(entity_id)
    DOCUMENT_REGISTRY.values.select { |doc| doc.entity_id == entity_id }
  end
end

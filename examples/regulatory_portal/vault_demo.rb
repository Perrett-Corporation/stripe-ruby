#!/usr/bin/env ruby
require_relative "lib/document_vault_service"
require_relative "lib/investigation_service"

# This script demonstrates the Encrypted Document Vault System.
# It uploads KYC/KYB documents, encrypts them, and links them to investigation cases.

puts "============================================================"
puts "  ENCRYPTED DOCUMENT VAULT SYSTEM STARTING  "
puts "============================================================"

# Setup: Create some dummy documents to upload
FileUtils.mkdir_p("tmp_docs")
File.write("tmp_docs/passport_copy.pdf", "Run-DMC Passport Content: VALID")
File.write("tmp_docs/incorporation_cert.pdf", "Company Registration: 12345 (Cayman Islands)")
File.write("tmp_docs/bank_statement.pdf", "Bank of Nowhere Statement: $5,000,000")

# 1. Select a Case
case_id = "CASE-2026-001"
entity_id = "cus_123"
puts "Target Case: #{case_id} (Entity: #{entity_id})"
puts "------------------------------------------------------------"

# 2. Upload KYC Documents (Passport)
puts "Uploading ID Document..."
doc1 = DocumentVaultService.upload_document(
  entity_id: entity_id,
  case_id: case_id,
  filepath: "tmp_docs/passport_copy.pdf",
  doc_type: "Passport"
)
puts "  -> ID: #{doc1.id}"

# 3. Upload KYB Documents (Certificate of Incorporation)
puts "Uploading Corporate Document..."
doc2 = DocumentVaultService.upload_document(
  entity_id: entity_id,
  case_id: case_id,
  filepath: "tmp_docs/incorporation_cert.pdf",
  doc_type: "Certificate of Incorporation"
)
puts "  -> ID: #{doc2.id}"

# 4. Upload Evidence (Bank Statement)
puts "Uploading Financial Evidence..."
doc3 = DocumentVaultService.upload_document(
  entity_id: entity_id,
  case_id: case_id,
  filepath: "tmp_docs/bank_statement.pdf",
  doc_type: "Bank Statement"
)
puts "  -> ID: #{doc3.id}"

puts "------------------------------------------------------------"

# 5. Verify Audit Trail: List Documents for Case
puts "Retrieving Document Audit Trail for Case #{case_id}..."
docs = DocumentVaultService.list_documents_for_case(case_id)
docs.each do |doc|
  puts "  [#{doc.doc_type}] #{doc.filename} (Uploaded: #{doc.uploaded_at})"
end

puts "------------------------------------------------------------"

# 6. Verify Encryption & Decryption
puts "Verifying Secure Access for Document #{doc1.id}..."
content = DocumentVaultService.retrieve_document(doc1.id)
puts "  Content Decrypted: \"#{content}\""

puts "============================================================"
puts "VAULT SYSTEM DEMO COMPLETE"
puts "============================================================"

# Cleanup
FileUtils.rm_rf("tmp_docs")

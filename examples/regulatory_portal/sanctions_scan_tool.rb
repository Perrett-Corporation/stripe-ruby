#!/usr/bin/env ruby
require_relative "lib/investigation_service"
require_relative "lib/sanctions_screener"
require_relative "lib/media_screener"
require "json"
require "date"

# This script simulates a real-time global sanctions and adverse media screening tool.
# It automatically scans investigation subjects against mock international watchlists
# (OFAC, EU, UN) and checks adverse media databases.
# Provides immediate risk alerts with source attribution.

puts "============================================================"
puts "  GLOBAL SANCTIONS & ADVERSE MEDIA SCREENING TOOL STARTING  "
puts "============================================================"
puts "Initializing Watchlist Database (OFAC, EU, UN)... [OK]"
puts "Initializing Media Sources (24h News, Leaks)...   [OK]"
puts "Scanning Active Investigations..."
puts "------------------------------------------------------------"

investigations = InvestigationService::OPEN_CASES
alerts_found = 0

investigations.each do |case_id, case_data|
  subject_name = case_data[:subject_name]
  subject_id = case_data[:subject_id]

  puts "Scanning Subject: #{subject_name} (ID: #{subject_id})..."

  # 1. Sanctions Screening
  sanctions_result = SanctionsScreener.check_sanctions(subject_name)

  # 2. Adverse Media Screening (check by ID first, then name if needed)
  media_result = MediaScreener.screen_entity(subject_id)
  if media_result[:hits].empty? && subject_name
    media_result_name = MediaScreener.screen_entity(subject_name)
    media_result = media_result_name unless media_result_name[:hits].empty?
  end

  risk_detected = false

  # Analyze Sanctions Results
  if sanctions_result[:status] == "FLAGGED"
    risk_detected = true
    puts "  [!!!] SANCTIONS ALERT DETECTED"
    sanctions_result[:alerts].each do |alert|
      puts "    > Match Found: #{alert[:match]}"
      puts "    > Source:      #{alert[:source]}"
      puts "    > Risk Level:  #{alert[:risk]}"
      puts "    > Date Added:  #{alert[:date_added]}"
    end
  end

  # Analyze Media Results
  has_critical_media = media_result[:hits].any? { |h| %w[alert negative].include?(h[:sentiment]) }
  if has_critical_media
    risk_detected = true
    puts "  [!!!] ADVERSE MEDIA ALERT"
    media_result[:hits].each do |hit|
      next unless %w[alert negative].include?(hit[:sentiment])

      puts "    > Source:    #{hit[:source]}"
      puts "    > Date:      #{hit[:date]}"
      puts "    > Sentiment: #{hit[:sentiment].upcase}"
      puts "    > Snippet:   #{hit[:snippet]}"
    end
  end

  if risk_detected
    alerts_found += 1
    puts ""
    puts "  ==> ACTION REQUIRED: Immediate escalation triggered."
  else
    puts ""
    puts "  [OK] No sanctions or critical media found."
  end
  puts "------------------------------------------------------------"
end

puts "============================================================"
puts "SCREENING COMPLETE"
puts "Total Subjects Scanned: #{investigations.count}"
puts "High Risk Alerts:       #{alerts_found}"
puts "============================================================"

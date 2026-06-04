class ComplianceTraining
  TRAINING_REQUIREMENTS = [
    { id: 1, title: "AML Fundamentals 2026", required: true },
    { id: 2, title: "KYC/CDD Best Practices", required: true },
    { id: 3, title: "Sanctions Screening Updates", required: true },
    { id: 4, title: "SAR Filing Procedures", required: true },
  ]

  # Mock storage for officer progress
  # In a real app, this would be in a DB related to the current user
  @@officer_progress = {
    "officer_1" => { 1 => true, 2 => true, 3 => false, 4 => false },
  }

  def self.get_requirements
    TRAINING_REQUIREMENTS
  end

  def self.get_status(officer_id)
    progress = @@officer_progress[officer_id] || {}
    completed_count = 0

    TRAINING_REQUIREMENTS.map do |req|
      completed = progress[req[:id]] == true
      completed_count += 1 if completed
      req.merge(completed: completed)
    end
  end

  def self.complete_training(officer_id, training_id)
    @@officer_progress[officer_id] ||= {}
    @@officer_progress[officer_id][training_id.to_i] = true
  end

  def self.compliant?(officer_id)
    status = get_status(officer_id)
    status.all? { |s| !s[:required] || s[:completed] }
  end

  def self.reset(officer_id)
    @@officer_progress[officer_id] = {}
  end
end

class CorporateStructureMap
  attr_reader :nodes, :edges, :risks, :root_id

  def initialize(entity_name, register_data)
    @nodes = []
    @edges = []
    @risks = []
    @root_id = "root"

    # 1. Add Root Node (Target Entity)
    country = register_data[:country] || "Unknown"
    normalized_root = { id: @root_id, label: entity_name, type: "target", country: country }
    @nodes << normalized_root

    # 2. Build Tree
    build_tree(@root_id, register_data[:shareholders])

    # 3. Analyze
    analyze_risks
  end

  def build_tree(parent_id, shareholders)
    return unless shareholders

    shareholders.each_with_index do |sh, idx|
      node_id = "#{parent_id}_#{idx}"
      label = "#{sh[:name]} (#{sh[:percentage]}%)"
      type = sh[:type] || "individual"
      country = sh[:country] || "Unknown"

      node = { id: node_id, label: sh[:name], type: type, country: country }
      @nodes << node

      edge = { from: node_id, to: parent_id, label: "#{sh[:percentage]}%" }
      @edges << edge

      # Recursively process nested structures if available
      build_tree(node_id, sh[:subsidiaries]) if sh[:subsidiaries]
    end
  end

  def analyze_risks
    high_risk_jurisdictions = ["Cayman Islands", "Panama", "British Virgin Islands", "Seychelles", "Cyprus"]

    @nodes.each do |node|
      next unless high_risk_jurisdictions.include?(node[:country])

      severity = node[:type] == "company" ? "critical" : "high"
      msg = "#{node[:label]} is in Mock High-Risk Jurisdiction (#{node[:country]})"
      msg += " - Potential Shell Company Risk" if node[:type] == "company"

      @risks << {
        node_id: node[:id],
        message: msg,
        severity: severity,
      }
    end
  end

  def to_h
    { nodes: @nodes, edges: @edges, risks: @risks }
  end
end

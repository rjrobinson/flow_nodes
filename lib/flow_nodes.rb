# frozen_string_literal: true

require_relative "flow_nodes/version"
require_relative "flow_nodes/base_node"
require_relative "flow_nodes/conditional_transition"
require_relative "flow_nodes/node"
require_relative "flow_nodes/batch_node"
require_relative "flow_nodes/flow"
require_relative "flow_nodes/batch_flow"
require_relative "flow_nodes/async_node"
require_relative "flow_nodes/async_batch_node"
require_relative "flow_nodes/async_parallel_batch_node"
require_relative "flow_nodes/async_flow"
require_relative "flow_nodes/async_batch_flow"
require_relative "flow_nodes/async_parallel_batch_flow"

# FlowNodes is a minimalist, graph-based framework for building complex workflows
# and agentic systems in Ruby. It is a port of the Python PocketFlow library.
module FlowNodes
end

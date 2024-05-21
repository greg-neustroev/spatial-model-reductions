

struct TreeNode
    data::ExperimentData
    parent::Symbol
    childeren::Vector{Symbol}

    function TreeNode(data::ExperimentData, parent::Symbol, children::Vector{Symbol})
        return new(
            data,
            parent,
            children
        )
    end
end

"""
Data structure to represent cluster tree of the spacial reduction.
"""

struct ClusterTree
    nodes::Dict{Symbol,TreeNode}

    function ClusterTree()
        return new(
            Dict(Symbol, TreeNode)
        )
    end


    function AddTreeNode(symbol::Symbol, node::TreeNode)
        nodes[symbol] = node
    end
end
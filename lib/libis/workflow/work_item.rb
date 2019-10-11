# frozen_string_literal: true

require 'backports/rails/hash'
require 'libis/tools/extend/hash'

# Base module for all work items.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the object
# - label: [String] the label of the object
# - parent: [Object|nil] a link to a parent work item. Work items can be organized in any hierarchy you think is
#     relevant for your workflow (e.g. directory[/directory...]/file/line or library/section/book/page). Of course
#     hierarchies are not mandatory.
# - items: [Enumerable] a list of child work items. see above.
# - options: [Hash] a set of options for the task chain on how to deal with this work item. This attribute can be
#     used to fine-tune the behaviour of tasks that support this.
# - properties: [Hash] a set of properties, typically collected during the workflow processing and used to store
#     final or intermediate resulst of tasks.
# - status_log: [Enumberable] a list of all status changes the work item went through.
#
# The module is created so that it is possible to implement an ActiveRecord/Datamapper/... implementation easily.
# A simple in-memory implementation would require:
#
# attr_accessor :parent
# attr_accessor :items
# attr_accessor :options, :properties
# attr_accessor :status_log
# attr_accessor :summary
#
# def initialize
#   self.parent = nil
#   self.items = []
#   self.options = {}
#   self.properties = {}
#   self.status_log = []
# end
#
# protected
#
# ## Method below should be adapted to match the implementation of the status array
#
# def add_status_log(info)
#   self.status_log << info
# end
#
# The implementation should also take care that the public methods #save and #save! are implemented.
# ActiveRecord and Mongoid are known to implement these, but others may not.
#
module Libis::Workflow
  module WorkItem
    include Base::Status
    include Base::Logging

    ### Methods that need implementation:
    #
    # save!
    # parent
    # properties
    # options
    # status_log
    # name
    # name=(name)
    # label
    # label=(label)
    # items
    # add_item
    # <<
    # item_list
    # job

    ### Derived methods. Should work as is when required methods are implemented properly

    def to_s
      send(:name)
    end

    def names
      (send(:parent)&.names || []).push(send(:name)).compact
    end

    def namepath
      names.join('/')
    end

    def labels
      (send(:parent)&.labels || []).push(send(:label)).compact
    end

    def labelpath
      labels.join('/')
    end

    # File name safe version of the to_s output.
    #
    # @return [String] file name safe string
    def safe_name
      to_s.gsub(/[^\w.-]/) { |s| format('%<prefix>s%<ord>02x', prefix: '%', ord: s.ord) }
    end

    # Iterates over the work item clients and invokes code on each of them.
    def each(&block)
      send(:items).each(&block)
    end

    def size
      send(:items).size
    end

    alias count size

    # @return [WorkItem] the root WorkItem object
    def root_item
      send(:parent)&.root_item || self
    end
  end
end

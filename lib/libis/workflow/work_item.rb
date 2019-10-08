# frozen_string_literal: true
require 'backports/rails/hash'
require 'libis/tools/extend/hash'

require_relative 'config'
require_relative 'status'
require_relative 'logging'

module Libis
  module Workflow

    # Base module for all work items.
    #
    # This module lacks the implementation for the data attributes. It functions as an interface that describes the
    # common functionality regardless of the storage implementation. These attributes require some implementation:
    #
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
    module WorkItem
      include Libis::Workflow::Status
      include Libis::Workflow::Logging

      # String representation of the identity of the work item.
      #
      # You may want to overwrite this method as it tries the :name property or whatever #inspect returns if that
      # failes. Typically this should return the key value, file name or id number. If that's what your :name property
      # contains, you're fine.
      #
      # @return [String] string identification for this work item.
      def name
        # noinspection RubyResolve
        self.properties['name'] || self.inspect
      end

      def name=(n)
        # noinspection RubyResolve
        self.properties['name'] = n
      end

      def to_s;
        self.name;
      end

      def names
        (self.parent.names rescue Array.new).push(name).compact
      end

      def namepath;
        self.names.join('/');
      end

      # Label is a more descriptive name
      def label
        # noinspection RubyResolve
        self.properties['label'] || self.name
      end

      def label=(value)
        # noinspection RubyResolve
        self.properties['label'] = value
      end

      def labels
        (self.parent.labels rescue Array.new).push(label).compact
      end

      def labelpath;
        self.labels.join('/');
      end

      # File name safe version of the to_s output.
      #
      # The output should be safe to use as a file name to store work item
      # data. Typical use is when extra file items are created by a task and need to be stored on disk. The default
      # implementation URL-encodes (%xx) all characters except alphanumeric, '.' and '-'.
      #
      # @return [String] file name
      def to_filename
        self.to_s.gsub(/[^\w.-]/) { |s| '%%%02x' % s.ord }
      end

      # Iterates over the work item clients and invokes code on each of them.
      def each(&block)
        self.items.each(&block)
      end

      def size
        self.items.size
      end

      alias_method :count, :size

      # Add a child work item
      #
      # @param [WorkItem] item to be added to the child list :items
      def add_item(item)
        raise NotImplementedError, "Method not implemented: #{self.class}##{__method__.to_s}"
      end

      alias_method :<<, :add_item

      # Get list of items.
      #
      # This method should return a list of items that can be accessed during long processing times.
      def get_items
        raise NotImplementedError, "Method not implemented: #{self.class}##{__method__.to_s}"
      end

      # Get list of items.
      #
      # This method should return a list of items that is safe to iterate over while it is being altered.
      def get_item_list
        raise NotImplementedError, "Method not implemented: #{self.class}##{__method__.to_s}"
      end

      # Return item's parent
      # @return [Libis::Workflow::WorkItem]
      def get_parent
        self.parent
      end

      # go up the hierarchy and return the topmost work item
      #
      # @return [Libis::Workflow::WorkItem]
      def get_root
        self.get_parent&.get_root || self
      end

    end

  end
end

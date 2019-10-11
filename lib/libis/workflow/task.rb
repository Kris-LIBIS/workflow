# frozen_string_literal: true

require 'backports/rails/hash'
require 'backports/rails/string'

require 'libis/tools/parameter'
require 'libis/tools/extend/hash'
require 'libis/tools/logger'

require 'libis/workflow'
require_relative 'base/status'

module Libis::Workflow
  class Task
    include ::Libis::Tools::Logger
    include ::Libis::Tools::ParameterContainer

    include Base::Status
    include Base::TaskConfiguration
    include Base::TaskExecution
    include Base::TaskHierarchy

    attr_accessor :processing_item

    parameter recursive: false, description: 'Run the task on all subitems recursively.'
    parameter abort_recursion_on_failure: false, description: 'Stop processing items recursively if one item fails.'
    parameter retry_count: 0, description: 'Number of times to retry the task if waiting for another process.'
    parameter retry_interval: 10, description: 'Number of seconds to wait between retries.'
    parameter run_always: false, description: 'Always run this task, even if previous tasks have failed.'

    def self.task_classes
      ObjectSpace.each_object(::Class).select { |klass| klass < self && !klass.is_a?(TaskGroup) }
    end

    def initialize(cfg = {})
      @subitems_stopper = false
      @subtasks_stopper = false
      configure cfg[:parameters] || {}
      @action = cfg[:action] || :start
    end

    def check_item_type(klasses, item = nil)
      item ||= workitem
      klasses = [klasses] unless klasses.is_a? Array
      unless klasses.any? { |klass| item.is_a? klass.to_s.constantize }
        raise WorkflowError, "Workitem is of wrong type : #{item.class} - expected #{klasses}"
      end

      true
    end

    def run
      parent&.run || nil
    end

    def work_dir
      run&.job&.work_dir
    end

    def stop_processing_subitems
      @subitems_stopper = true if parameter(:recursive)
    end

    def check_processing_subitems
      if @subitems_stopper
        @subitems_stopper = false
        return false
      end
      true
    end

    def skip_processing_item
      @item_skipper = true
    end

    def item_type?(klass, item = nil)
      item ||= workitem
      item.is_a? klass.to_s.constantize
    end

    private

    def subtasks
      tasks
    end

    def subitems(item = nil)
      (item || workitem).get_item_list
    end

  end
end

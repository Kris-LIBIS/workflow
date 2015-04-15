# encoding: utf-8
require 'backports/rails/hash'
require 'backports/rails/string'

require 'libis/tools/parameter'

require 'libis/workflow'
require 'libis/workflow/base/logger'

module Libis
  module Workflow

    # noinspection RubyTooManyMethodsInspection
    class Task
      include Base::Logger
      include ::Libis::Tools::ParameterContainer

      attr_accessor :parent, :name, :options, :workitem, :tasks

      parameter abort_on_error: false, description: 'Stop all tasks when an error occurs.'
      parameter allways_run: false, description: 'Run this task, even if the item failed a previous task.'
      parameter subitems: false, description: 'Do not process the given item, but only the subitems.'
      parameter recursive: false, description: 'Run the task on all subitems recursively.'

      def self.task_classes
        ObjectSpace.each_object(::Class).select {|klass| klass < self}
      end

      def initialize(parent, cfg = {})
        self.parent = parent
        self.tasks = []
        configure cfg
      end

      def <<(task)
        self.tasks << task
      end

      def run(item)

        check_item_type WorkItem, item

        return if item.failed? unless options[:allways_run]

        if options[:subitems]
            log_started item
            run_subitems item
            log_done(item) unless item.failed?
        else
          run_item(item)
        end

        item.save

      end

      def run_item(item)

        begin

          self.workitem = item

          log_started item

          pre_process item
          process_item item
          post_process item

        rescue WorkflowError => e
          error e.message
          log_failed item

        rescue WorkflowAbort => e
          item.status = to_status :failed
          raise e if parent

        rescue ::Exception => e
          fatal 'Exception occured: %s', e.message
          debug e.backtrace.join("\n")
          log_failed item
        end

        log_done item unless item.failed?

      end

      def names
        (self.parent.names rescue Array.new).push(name).compact
      end

      def namepath; self.names.join('/'); end

      def apply_options(opts)
        o = opts[self.name] || opts[self.names.join('/')]

        default_values.each do |name,_|
          next unless o.key?(name)
          parameter = get_parameter_definition name
          self.options[name] = parameter.parse(o[name])
        end if o and o.is_a? Hash

        self.tasks.each do |task|
          task.apply_options opts
        end
      end

      protected

      def log_started(item)
        item.status = to_status :started
        debug 'Started', item
      end

      def log_failed(item, message = nil)
        warn (message || 'Failed'), item
        item.status = to_status :failed
      end

      def log_done(item)
        debug 'Completed', item
        item.status = to_status :done
      end

      def process_item(item)
        process item
        run_subitems(item) if options[:recursive]
        run_subtasks item
      end

      def process(item)
        # needs implementation unless there are subtasks
        raise RuntimeError, 'Should be overwritten' if self.tasks.empty?
      end

      def pre_process(_)
        # optional implementation
      end

      def post_process(_)
        # optional implementation
      end

      def get_root_item
        self.workitem.root
      end

      def get_work_dir
        get_root_item.work_dir
      end

      def capture_cmd(cmd, *opts)
        out = StringIO.new
        err = StringIO.new
        $stdout = out
        $stderr = err
        status = system cmd, *opts
        return [status, out.string, err.string]
      ensure
        $stdout = STDOUT
        $stderr = STDERR
      end

      def run_subitems(parent_item)
        items = subitems parent_item
        failed = passed = 0
        items.each_with_index do |item, i|
          debug 'Processing subitem (%d/%d): %s', parent_item, i+1, items.count, item.to_s
          run_item item
          if item.failed?
            failed += 1
            if options[:abort_on_error]
              error 'Aborting ...', parent_item
              raise WorkflowAbort.new "Aborting: task #{name} failed on #{item}"
            end
          else
            passed += 1
          end
        end
        if failed > 0
          warn '%d subitem(s) failed', parent_item, failed
          if failed == items.count
            error 'All subitems have failed', parent_item
            log_failed parent_item
            return
          end
        end
        debug '%d of %d subitems passed', parent_item, passed, items.count if items.count > 0
      end

      def run_subtasks(item)
        tasks = subtasks item
        tasks.each_with_index do |task, i|
          debug 'Running subtask (%d/%d): %s', item, i+1, tasks.count, task.name
          task.run item
          if item.failed?
            if task.options[:abort_on_error]
              error 'Aborting ...'
              raise WorkflowAbort.new "Aborting: task #{task.name} failed on #{item}"
            end
            return
          end
        end
      end

      def configure(cfg)
        self.name = cfg[:name] || (cfg[:class] || self.class).to_s.split('::').last
        self.options =
            default_values.merge(
                cfg[:options] || {}
            ).merge(
                cfg.reject { |k, _| [:options].include? k.to_sym }
            ).symbolize_keys!
      end

      def to_status(text)
        [text.to_s.capitalize, self.names]
      end

      def check_item_type(klass, item = nil)
        item ||= self.workitem
        unless item.is_a? klass.to_s.constantize
          raise WorkflowError, "Workitem is of wrong type : #{item.class} - expected #{klass.to_s}"
        end
      end

      def item_type?(klass, item = nil)
        item ||= self.workitem
        item.is_a? klass.to_s.constantize
      end

      private

      def subtasks(item = nil)
        self.tasks.map do |task|
          ((item || self.workitem).failed? and not task.options[:always_run]) ? nil : task
        end.compact
      end

      def subitems(item = nil)
        items = (item || workitem).items
        return items if self.options[:always_run]
        items.reject { |i| i.failed? }
      end

      def default_values
        self.class.default_values
      end

      def self.default_values
        parameters.inject({}) do |hash,parameter|
          hash[parameter.first] = parameter.last[:default]
          hash
        end
      end

    end

  end
end

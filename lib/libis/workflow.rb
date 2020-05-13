require 'libis/exceptions'

require_relative 'workflow/version'

module Libis
  module Workflow

    autoload :MessageRegistry, 'libis/workflow/message_registry'
    autoload :Config, 'libis/workflow/config'

    module Base
      autoload :WorkItem, 'libis/workflow/base/work_item'
      autoload :FileItem, 'libis/workflow/base/file_item'
      autoload :DirItem, 'libis/workflow/base/dir_item'
      autoload :Logging, 'libis/workflow/base/logging'
      autoload :Job, 'libis/workflow/base/job'
      autoload :Run, 'libis/workflow/base/run'
      autoload :Workflow, 'libis/workflow/base/workflow'
    end

    autoload :Status, 'libis/workflow/status'

    autoload :WorkItem, 'libis/workflow/work_item'
    autoload :FileItem, 'libis/workflow/file_item'
    autoload :DirItem, 'libis/workflow/dir_item'

    autoload :Workflow, 'libis/workflow/workflow'
    autoload :Job, 'libis/workflow/job'
    autoload :Run, 'libis/workflow/run'
    autoload :Task, 'libis/workflow/task'
    autoload :TaskGroup, 'libis/workflow/task_group'
    autoload :TaskRunner, 'libis/workflow/task_runner'

    def self.configure
      yield Config.instance
    end

  end
end

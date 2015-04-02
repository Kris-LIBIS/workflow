# encoding: utf-8
require 'libis/workflow/workitems'

class TestDirItem
  include ::Libis::Workflow::DirItem

  def name=(dir)
    raise RuntimeError, "'#{dir}' is not a directory" unless File.directory? dir
    super dir
  end

  def name
    self.properties[:name] || super
  end

end
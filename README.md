[![Build Status](https://travis-ci.org/Kris-LIBIS/workflow.svg?branch=master)](https://travis-ci.org/Kris-LIBIS/workflow)
[![Coverage Status](https://img.shields.io/coveralls/Kris-LIBIS/workflow.svg)](https://coveralls.io/r/Kris-LIBIS/workflow)
[![status](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.badges/status.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)

# LIBIS Workflow

LIBIS Workflow framework

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'LIBIS_Workflow'
```


And then execute:

    $ bundle

Or install it yourself as:

    $ gem install LIBIS_Workflow

## Architecture

This gem is essentially a simple, custom workflow system. The core of the workflow are the tasks. You can - and should -
create your own tasks by creating new classes and include ::LIBIS::Workflow::Task. The ::LIBIS::Workflow::Task module
and the included ::LIBIS::Workflow::Base::Logger module provide the necessary attributes and methods to make them work
in the workflow. See the detailed documentation for the modules for more information.

The objects that the tasks will be working on should derive from the ::LIBIS::Workflow::WorkItem class. When working with
file objects the module ::LIBIS::Workflow::FileItem module can be included for additional file-specific functionality.
Work items can be organized in different types and a hierarchical structure.

All the tasks will be organized into a ::LIBIS::Workflow::WorkflowDefinition which will be able to execute the tasks in 
proper order on all the WorkItems supplied/collected. Each task can be implemented with code to run or simply contain a 
list of child tasks.

Two tasks are predefined:
::LIBIS::Workflow::Tasks::VirusChecker - runs a virus check on each WorkItem that is also a FileItem.
::LIBIS::Workflow::Tasks::Analyzer - analyzes the workflow run and summarizes the results. It is always included as the
last task by the workflow unless you supply a closing task called 'Analyzer' yourself.

The whole ingester workflow is configured by a Singleton object ::LIBIS::Workflow::Config which contains settings for
logging, paths where tasks and workitems can be found and the path to the virus scanner program.

## Usage

You should start by including the following line in your source code:

```ruby
require 'LIBIS_Workflow'
```

This will load all of the LIBIS Workflow framework into your environment, but including only the required parts is OK as
well. This is shown in the examples below.

### Workflows

A ::LIBIS::Workflow::WorkflowDefinition instance contains the definition of a workflow. Once instantiated, it can be run 
by calling the 'run' method. This will create a ::LIBIS::Workflow::WorkflowRun instance, configure it and call the 'run'
method on it. The Workflow constructor takes no arguments, but is should be configured by calling the 'set_config'
method with the workflow configuration as an argument. The 'run' method takes an option Hash as argument.

#### Workflow configuration

A workflow configuration is a Hash with:
* tasks: Array of task descriptions
* start_object: String with class name of the starting object to be created. An istance of this class will be created
  for each run and serves as the root work item for that particular run. 
* input: Hash with input variable definitions

##### Task description
 
is a Hash with:
* class: String with class name of the task
* name: String with the name of the task
* tasks: Array with task definitions of sub-tasks
* options: Hash with additional task configuration options (see 'Tasks - Configuration' for more info)

If 'class' is not present, the default '::LIBIS::Workflow::Task' with the given name will be instantiated, which simply 
iterates over the child items of the given work item and performs each sub-task on each of the child items. If a 'class'
value is given, an instance of that class will be created and the task will be handed the work item to process on. See 
the chapter on 'Tasks' below for more information on tasks.

##### Input variable definition

The key of the input Hash is the unique id of the variable. The value is a Hash with:
* name: String with the name of the input variable
  This value is used for display only
* description: String with descriptive text explaining the use/meaning of the variable
* type: String with the type of the variable
  Currently only 'String', 'Time' and 'Boolean' are supported. If the value is not present, 'String' is asumed.
* default: String with the default value
  If the default value contains the string %s, it will be replaced with the current time in the format yymmddHHMMSS when
  the workflow is started.  For boolean values, 'true', 'yes', 't', 'y' and 1 are all interpreted as boolean true.

All of these Hash keys are optional. Each input variable key and value will be added to the root work item's option Hash.

#### Options

The option Hash contains special run-time configuration parameters for the workflow:
* action: String with the action that should be taken. Currently only 'start' is supported. In the future support for
  'restart' and 'continue' will be added.
* interactive: Boolean that indicates if the user should be queried to input values for variables that have no value set.
  This will pause the workflow run and is therefore not compatible with scheduling the workflow. For unattended runs the
  options should be set to false, causing the run to throw an exception if an input variable is missing a value.
  
Remaining values are considered to be (default) values for the input variables.

#### Run-time configuration

The 'run' method takes an optional Hash as argument which will complement and override the options Hash described in the
previous chapter.
 
Once the workflow is configured and the root work item instantiated, the method will run each top-level task on the root
work item in sequence until all tasks have completed successfully or a task has failed.

### Work items

Creating your own work items is highly recommended and is fairly easy:

```ruby
require 'libis/workflow/workitems'

class MyWorkItem < ::LIBIS::Workflow::WorkItem

  attr_accesor :name

  def initialize
    @name = 'My work item'
    super # Note: this is important as the base class requires some initialization
  end

end
```

Work items that are file-based should also include the ::LIBIS::Workflow::FileItem module:

```ruby
require 'libis/workflow/workitems'

class MyFileItem < ::LIBIS::Workflow::WorkItem
  include ::LIBIS::Workflow::FileItem

  def initialize(file)
    filename = file
    super
  end

  def filesize
    properties[:size]
  end

  def fixity_check(checksum)
    properties[:checksum] == checksum
  end

end
```

## Tasks

Tasks should inherit from ::LIBIS::Workflow::Task and specify the actions it wants to
perform on each work item:

```ruby
class MyTask < ::LIBIS::Workflow::Task
  def process_item(item)
    item.perform_my_action
  rescue Exception => e
    item.set_status(to_status(:failed))
  end

end
```

You have some options to specify the actions:

### Performing an action on each child item of the provided work item

In that case the task should provide a 'process_item' method as above. Each child item will be passed as the argument
to the method and perform whatever needs to be done on the item.

If the action fails the method is expected to set the item status field to failed. This is also shown in the previous
example. If the error is so severe that no other child items should be processed, the action can decide to throw an
exception, preferably a ::LIBIS::Workflow::Exception or a child exception thereof.
  
### Performing an action on the provided work item

If the task wants to perform an action on the work item directly, it should define a 'process' method. The work item is
available to the method as class instance variable 'workitem'. Again the method is responsible to communicate errors
with a failed status or by throwing an exception.

### Combining both

It is possible to perform some action on the parent work item first and then process each child item. Processing the
child items should be done in process_item as usual, but processing the parent item can be done either by defining a
pre_process method or a process method that ends with a 'super' call. Using this should be an exception as it is
recommended to create a seperate task to process the child work items.

### Default behaviour

The default implementation of 'process' is to call 'pre_process' and then call 'process_item' on each child item.

The default implementation for 'process_item' is to run each child task for each given child item. This will raise an
exception unless the workflow has defined some sub-tasks for this task. This means that in the workflow definition tree
each leaf task should either implement it's own 'process_item' method or override the 'process' method. Only non-leaf
nodes in the workflow definition tree are allowed to use the default implementation (by defining only 'name' and 'tasks'
value). See above on 'Workflow configuration' for more info.

### Configuration

The task takes some options that determine how the task will be handling special cases. The options should be passed to
the Task constructor as part of the initialization. The workflow configuration will take care of that.

* quiet: Boolean - default: false
* always_run: Boolean - default: false
* items_first: Boolean - default: false

The quiet option surpresses all logging for this task.

When the option always_run is set, the task will run even when a previous task failed to run on the item before. Note
that successfully running such a task will unmark the item as failed. The status history of the item will show which
tasks failed. Only use this option if you are sure the task will fully recover if the previous tasks failed or did not
run due to a previous failure.
 
The items_fist option determines the processing order. If a task has multiple subtasks and the given workitem has 
multiple subitems, setting the items_first option will cause it to take the first subitem, run the first subtask on it,
then the second subtask and so on. Next it will run the first, second, ... subtask on the second subitem and so on. If
the option is not set or set to false, the first subtask will run on each subitem, then the second subtask on each 
subitem, and so on.

### Convenience functions

#### get_root_item()

Returns the work item that the workflow started with (and is the root/grand parent of all work items in the ingest run).

#### get_work_dir()

Returns the work directory as configured for the current ingest run. The work directory can be used as scrap directory
for creating derived files that can be added as work items to the current flow or for downloading files that will be
processed later. The work directory is not automaticaly cleaned up, which is considered a task for the workflow implementation. 

#### capture_cmd(cmd, *args)

Allows the task to run an external command-line program and capture it's stdout and stderr output at the same time. The
first argument is mandatory and should be the command-line program that has to be executed. An arbitrary number of
command-line arguments may follow.

The return value is an array with three elements: the status code returned by the command, the stdout string and the 
stderr string.

#### names()

An array of strings with the hierarchical path of tasks leading to the current task. Can be usefull for log messages.

#### (debug/info/warn/error/fatal)(message, *args)

Convenience function for creating log entries. The logger set in ::LIBIS::Workflow::Config is used to dump log messages.

The first argument is mandatory and can be:
* an integer. The integer is used to look up the message text in ::LIBIS::Workflow::MessageRegistry.
* a static string. The message text is used as-is.
* a string with placement holders as used in String#%. Args can either be an array or a hash. See also Kernel#sprintf.

The log message is logged to the general logging and attached to the current work item (workitem) unless another
work item is passed as first argument after the message.

#### check_item_type(klass, item = nil)

Checks if the work item is of the given class. 'workitem' is checked if the item argument is not present. If the check 
fails a Runtime exception is thrown which will cause the task to abort if not catched. 

#### item_type?(klass, item = nil)

A less severe variant version of check_item_type which returns a boolean (false if failed).

#### to_status(status)

Simply prepends the status text with the current task name. The output of this function is typically what the work item
status field should be set at.

## Contributing

1. Fork it ( https://github.com/libis/workflow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

[![authors](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.badges/authors.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)
[![views](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.counters/views.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)
[![views 24h](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.counters/views-24h.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)
[![library users](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.badges/library-users.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)
[![xrefs](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.badges/xrefs.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)
[![docs examples](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.badges/docs-examples.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)
[![funcs](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.badges/funcs.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)
[![dependencies](https://sourcegraph.com/api/repos/github.com/Kris-LIBIS/workflow/.badges/dependencies.png)](https://sourcegraph.com/github.com/Kris-LIBIS/workflow)

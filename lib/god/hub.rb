module God
  
  class Hub
    class << self
      # directory to hold conditions and their corresponding metric
      #   key: condition
      #   val: metric
      attr_accessor :directory
    end
    
    self.directory = {}
    
    def self.attach(condition, metric)
      # add the condition to the directory
      self.directory[condition] = metric
      
      # schedule poll condition
      # register event condition
      if condition.kind_of?(PollCondition)
        Timer.get.schedule(condition, 0)
      else
        condition.register
      end
    end
    
    def self.detach(condition)
      # remove the condition from the directory
      self.directory.delete(condition)
      
      # unschedule any pending polls
      Timer.get.unschedule(condition)
      
      # deregister event condition
      if condition.kind_of?(EventCondition)
        condition.deregister
      end
    end
    
    def self.trigger(condition)
      if condition.kind_of?(PollCondition)
        self.handle_poll(condition)
      elsif condition.kind_of?(EventCondition)
        self.handle_event(condition)
      end
    end
    
    def self.handle_poll(condition)
      Thread.new do
        begin
          metric = self.directory[condition]
          watch = metric.watch
        
          watch.mutex.synchronize do
            result = condition.test
          
            msg = watch.name + ' ' + condition.class.name + " [#{result}] " + metric.destination.inspect
            Syslog.debug(msg)
            puts msg
          
            condition.after
          
            dest = metric.destination[result]
            if dest
              watch.move(dest)
            else
              # reschedule
              Timer.get.schedule(condition)
            end
          end
        rescue => e
          message = format("Unhandled exception (%s): %s\n%s",
                           e.class, e.message, e.backtrace.join("\n"))
          Syslog.crit message
          abort message
        end
      end
    end
    
    def self.handle_event(condition)
      Thread.new do
        metric = self.directory[condition]
        watch = metric.watch
        
        watch.mutex.synchronize do
          msg = watch.name + ' ' + condition.class.name + " [true] " + metric.destination.inspect
          Syslog.debug(msg)
          puts msg
          
          dest = metric.destination[true]
          watch.move(dest)
        end
      end
    end
  end
  
end
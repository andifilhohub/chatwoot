# Hard block: disable enterprise tasks in application boot
if defined?(Rails::Server) || defined?(Puma)
  module Enterprise
    module TasksLoader
      def self.load_tasks
        # no-op
      end
    end
  end
end

# frozen_string_literal: true

class ExecutableMock
  module Registry
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def registry
        Thread.current[:executable_mocks] ||= Set.new
      end
    end

    def register_self
      self.class.registry << self
    end

    def deregister_self
      self.class.registry.delete(self)
    end
  end
end

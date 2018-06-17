# frozen_string_literal: true

module SidekiqUniqueJobs
  # Shared logic for dealing with options
  # This class requires 3 methods to be defined in the class including it
  #   1. item (required)
  #   2. options (can be nil)
  #   3. worker_class (can be nil)
  module OptionsWithFallback
    LOCKS = {
      until_and_while_executing: SidekiqUniqueJobs::Lock::UntilAndWhileExecuting,
      until_executed:            SidekiqUniqueJobs::Lock::UntilExecuted,
      until_executing:           SidekiqUniqueJobs::Lock::UntilExecuting,
      until_timeout:             SidekiqUniqueJobs::Lock::UntilTimeout,
      while_executing:           SidekiqUniqueJobs::Lock::WhileExecuting,
    }.freeze

    def unique_enabled?
      SidekiqUniqueJobs.config.enabled && item[UNIQUE_KEY]
    end

    def unique_disabled?
      !unique_enabled?
    end

    def log_duplicate_payload?
      options[LOG_DUPLICATE_KEY] || item[LOG_DUPLICATE_KEY]
    end

    def lock
      @lock = lock_class.new(item)
    end

    def lock_class
      @lock_class ||= begin
        LOCKS.fetch(unique_lock.to_sym) do
          fail UnknownLock, "No implementation for `unique: :#{unique_lock}`"
        end
      end
    end

    def unique_lock
      @unique_lock ||=
        if options.key?(UNIQUE_KEY) && options[UNIQUE_KEY].to_s == 'true'
          warn('unique: true is no longer valid. Please set it to the type of lock required like: ' \
               '`unique: :until_executed`')
          options[UNIQUE_LOCK_KEY] || SidekiqUniqueJobs.default_lock
        else
          lock_type || SidekiqUniqueJobs.default_lock
        end
    end

    def lock_type
      lock_type_from(options) || lock_type_from(item)
    end

    def lock_type_from(hash, key = UNIQUE_KEY)
      return nil if hash[key].is_a?(TrueClass)
      hash[key]
    end

    def options
      @options ||= worker_class.get_sidekiq_options if worker_class.respond_to?(:get_sidekiq_options)
      @options ||= Sidekiq.default_worker_options
      @options ||= {}
      @options &&= @options.stringify_keys
    end
  end
end

module Kontena
  # An Actor that has some value
  # The value does not yet exist when initialized, it is nil
  # Once the value is first updated, then other Actors will be able to observe it
  # When the value later updated, other Actors will also observe those changes
  module Observable
    include Kontena::Logging

    # @return [Object, nil] last updated value, or nil if not observable?
    def observable_value
      @observable_value
    end

    # Obsevable has updated, as has not reset
    # @return [Boolean]
    def observable?
      !!@observable_value
    end

    # Registered Waiters
    #
    # @return [Hash{Wait => Celluloid::Mailbox}]
    def waiters
      @waiters ||= {}
    end

    # Registered Observers
    #
    # @return [Hash{Observe => Celluloid::Proxy::Cell<Observer>}]
    def observers
      @observers ||= {}
    end

    # The Observable has a value. Propagate it to any observing Actors.
    #
    # This will notify any Observers, causing them to yield if ready.
    #
    # The value must be safe for access by multiple threads, even after this update,
    # and even after any later updates. Ideally, it should be immutable (frozen).
    #
    # @param value [Object]
    # @raise [ArgumentError] Update with nil value
    def update_observable(value)
      raise ArgumentError, "Update with nil value" if value.nil?
      debug "update: #{value}"

      @observable_value = value

      notify_observers
    end

    # The Observable no longer has a value
    # This will notify any Observers, causing them to block yields until we update again
    def reset_observable
      @observable_value = nil

      notify_observers
    end

    # @param observer [Celluloid::Proxy::Cell<Observer>]
    # @param observe [Observer::Wait]
    # @return [Object, nil] possible existing value
    def add_waiter(observer, wait)
      if value = @observable_value
        debug "waiter: #{wait} = #{@observable_value.inspect[0..64] + '...'}"

        return value
      else
        debug "waiter: #{wait}..."

        waiters[wait] = observer

        return nil
      end
    end

    # Observer actor is observing this Actor's @value.
    # Updates to value will send to update_observe on given actor.
    # Returns current value.
    #
    # @param observer [Celluloid::Proxy::Cell<Observer>]
    # @param observe [Observer::Observe]
    # @return [Object, nil] possible existing value
    def add_observer(observer, observe)
      debug "observer: #{observe} <- #{@observable_value.inspect[0..64] + '...'}"

      observers[observe] = observer

      return @observable_value
    end

    # Update @value to each Observer::Observe
    def notify_observers
      waiters.each do |wait, observer|
        debug "notify: #{wait} <- #{@observable_value.inspect[0..64] + '...'}"

        wait.value = @observable_value
        observer.mailbox << wait
      end
      waiters.clear # XXX: is this really atomic with all the mailbox << ... calls?

      observers.each do |observe, observer|
        if observer.alive?
          debug "notify: #{observe} <- #{@observable_value.inspect[0..64] + '...'}"

          # XXX: is the Observable's Celluloid.current_actor guranteed to match the Actor[:node_info_worker] Celluloid::Proxy::Cell by identity?
          observer.async.update_observe(observe, Celluloid.current_actor, @observable_value)
        else
          debug "observer died: #{observe}"

          observers.delete(observe)
        end
      end
    end
  end
end

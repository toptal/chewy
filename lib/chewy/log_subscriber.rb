module Chewy
  class LogSubscriber < ActiveSupport::LogSubscriber
    def logger
      Chewy.logger
    end

    def import_objects(event)
      render_action('Import', event) { |payload| payload[:import] }
    end

    def search_query(event)
      render_action('Search', event) { |payload| payload[:request] }
    end

    def delete_query(event)
      render_action('Delete by Query', event) { |payload| payload[:request] }
    end

    def render_action(action, event)
      payload = event.payload
      description = yield(payload)

      return if description.blank?

      subject = payload[:type].presence || payload[:index]
      action = "#{subject} #{action} (#{event.duration.round(1)}ms)"
      action = if ActiveSupport.version >= Gem::Version.new('7.1')
        color(action, GREEN, bold: true)
      else
        color(action, GREEN, true)
      end

      debug("  #{action} #{description}")
    end
  end
end

Chewy::LogSubscriber.attach_to :chewy

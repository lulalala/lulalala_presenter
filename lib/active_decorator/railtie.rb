require 'active_decorator/view_context'
require 'rails'

module ActiveDecorator
  class Railtie < ::Rails::Railtie
    initializer 'active_decorator' do
      ActiveSupport.on_load(:action_controller) do
        require 'active_decorator/monkey/action_controller/base/rescue_from'
        ActionController::Base.send :include, ActiveDecorator::ViewContext::Filter
      end
      ActiveSupport.on_load(:action_mailer) do
        if ActionMailer::Base.respond_to? :before_action
          ActionMailer::Base.send :include, ActiveDecorator::ViewContext::Filter
        end
      end
    end
  end
end

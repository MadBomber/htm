# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # HTM instance for the current request
  def htm
    @htm ||= HTM.new(robot_name: current_robot_name)
  end
  helper_method :htm

  # Allow switching robots via session
  def current_robot_name
    session[:robot_name] || 'explorer'
  end
  helper_method :current_robot_name

  def current_robot_name=(name)
    session[:robot_name] = name
  end
end

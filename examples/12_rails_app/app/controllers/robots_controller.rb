# frozen_string_literal: true

class RobotsController < ApplicationController
  def index
    @robots = HTM::Models::Robot.order(Sequel.desc(:created_at))
  end

  def show
    @robot = HTM::Models::Robot[params[:id]]
    unless @robot
      flash[:alert] = 'Robot not found'
      redirect_to robots_path
      return
    end
    # Default scope already excludes deleted nodes, so no .active needed
    @memory_count = @robot.nodes_dataset.count
    @recent_memories = @robot.nodes_dataset.order(Sequel.desc(:created_at)).limit(10).all
  end

  def new
  end

  def create
    name = params[:name]&.strip

    if name.blank?
      flash[:alert] = 'Robot name is required'
      redirect_to new_robot_path
      return
    end

    if HTM::Models::Robot.where(name: name).any?
      flash[:alert] = 'A robot with that name already exists'
      redirect_to new_robot_path
      return
    end

    robot = HTM::Models::Robot.create(name: name, metadata: {})
    flash[:notice] = "Robot '#{name}' created successfully"
    redirect_to robot_path(robot.id)
  end

  def switch
    robot = HTM::Models::Robot[params[:id]]
    unless robot
      flash[:alert] = 'Robot not found'
      redirect_to robots_path
      return
    end
    self.current_robot_name = robot.name
    flash[:notice] = "Switched to robot '#{robot.name}'"
    redirect_to root_path
  end
end

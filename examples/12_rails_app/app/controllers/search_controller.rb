# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:query]
    @strategies = %i[vector fulltext hybrid]
    @selected_strategy = (params[:strategy] || 'hybrid').to_sym
    @limit = (params[:limit] || 10).to_i
    @timeframe = params[:timeframe].presence || 'all time'

    @results = {}
    @errors = {}

    return unless @query.present?

    # Convert "all time" to nil for HTM (no timeframe filter)
    timeframe_param = @timeframe == 'all time' ? nil : @timeframe

    if params[:compare] == 'true'
      # Compare all strategies
      @strategies.each do |strategy|
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          @results[strategy] = htm.recall(@query, limit: @limit, strategy: strategy, timeframe: timeframe_param, raw: true)
        rescue StandardError => e
          @results[strategy] = []
          @errors[strategy] = e.message
        end
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @results["#{strategy}_time".to_sym] = ((end_time - start_time) * 1000).round(2)
      end
    else
      # Single strategy search
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        @results[@selected_strategy] = htm.recall(@query, limit: @limit, strategy: @selected_strategy, timeframe: timeframe_param, raw: true)
      rescue StandardError => e
        @results[@selected_strategy] = []
        @errors[@selected_strategy] = e.message
        flash.now[:alert] = "Search error: #{e.message}"
      end
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @results["#{@selected_strategy}_time".to_sym] = ((end_time - start_time) * 1000).round(2)
    end
  end
end

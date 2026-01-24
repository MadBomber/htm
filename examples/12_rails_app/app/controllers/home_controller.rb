# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @chat_count = Chat.count rescue 0
    @memory_count = HTM::Models::Node.count rescue 0
  end
end

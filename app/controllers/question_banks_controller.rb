class QuestionBanksController < ApplicationController

  def import
    Question.import(params[:file])
  end

  def index

  end
end

class QuestionBanksController < ApplicationController

  def import
    list_errors = Question.import(params[:file])
    if list_errors.empty?
      flash[:success] = 'Import success!'
      # redirect_to admin_enrollments_path
    else
      flash.now[:danger] = 'WARNING: Some errors have been occurred! Please see downloaded list'
      send_data list_errors, disposition: 'attachment', filename: 'errors.txt'
    end
  end

  def index

  end
end

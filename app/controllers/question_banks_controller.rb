class QuestionBanksController < ApplicationController

  def import
    zip_file = Question.import(params[:file])
    # if list_errors.empty?
    #   flash[:success] = 'Import success!'
    #   # redirect_to admin_enrollments_path
    # else
    #   flash.now[:danger] = 'WARNING: Some errors have been occurred! Please see downloaded list'
    #   logger.info list_errors.inspect
    #   send_data list_errors, disposition: 'attachment', filename: 'errors.txt'
    # end
    send_file(zip_file)
  end

  def index

  end
end

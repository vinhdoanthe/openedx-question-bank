# frozen_string_literal: true

class Question < ApplicationRecord
  require 'fileutils'
  require 'minitar'
  require 'zlib'

  module QuestionType
    CHECKBOX = 'checkbox'
    MULTIPLE_CHOICE = 'multiple_choice'
    NUMERICAL = 'numerical'
    TEXT_INPUT = 'text_input'
  end

  module DifficultLevel
    HARD = 'H'
    MEDIUM = 'M'
    EASY = 'E'
  end

  ## Default sheet name
  module DefaultSheetName
    LIBRARY_DESCRIPTION = 'Library Description'
    CHECKBOXES = 'Checkboxes'
    MULTIPLE_CHOICE_DROPDOWN = 'Multiple Choice-Drop Down'
    NUMERICAL_INPUT = 'Numerical Input'
    TEXT_INPUT = 'Text Input'
  end

  ZIP_FOLDER = 'exported_library'

  def self.import(file)
    spreadsheet = open_spreadsheet(file)
    sheet_names = spreadsheet.sheets
    p sheet_names
    error_questions = []
    # Sheet 1: LIBRARY_DESCRIPTION
    if sheet_names.include?(DefaultSheetName::LIBRARY_DESCRIPTION)
      lib_des_sheet = spreadsheet.sheet(DefaultSheetName::LIBRARY_DESCRIPTION)
      lib_name = lib_des_sheet.a1
      lib_org = lib_des_sheet.a2
      lib_code = lib_des_sheet.a3
    else
      error = [DefaultSheetName::LIBRARY_DESCRIPTION + 'do not existed in the imported file']
      error_questions += error
    end

    # Sheet 2: Checkboxes questions
    if sheet_names.include?(DefaultSheetName::CHECKBOXES)
      spreadsheet.default_sheet = DefaultSheetName::CHECKBOXES
      checkbox_questions, error = read_checkbox spreadsheet
    else
      error = [DefaultSheetName::CHECKBOXES + 'do not existed in the imported file']
    end
    error_questions += error

    logger.info 'error_questions.inspect'
    logger.info error_questions.inspect

    # Sheet 3: Multiple Choice-Drop Down questions
    if sheet_names.include?(DefaultSheetName::MULTIPLE_CHOICE_DROPDOWN)
      spreadsheet.default_sheet = DefaultSheetName::MULTIPLE_CHOICE_DROPDOWN
      multiple_choice_dropdown_questions, error = read_multiple_choice spreadsheet
    else
      error = [DefaultSheetName::MULTIPLE_CHOICE_DROPDOWN + 'do not existed in the imported file']
    end
    error_questions += error

    logger.info 'error_questions.inspect'
    logger.info error_questions.inspect

    # Sheet 4: Numerical Input questions
    if sheet_names.include?(DefaultSheetName::NUMERICAL_INPUT)
      spreadsheet.default_sheet = DefaultSheetName::NUMERICAL_INPUT
      numerical_input_questions, error = read_numerical spreadsheet
    else
      error = [DefaultSheetName::NUMERICAL_INPUT + 'do not existed in the imported file']
    end
    error_questions += error

    # Sheet 5: Text Input questions
    if sheet_names.include?(DefaultSheetName::TEXT_INPUT)
      spreadsheet.default_sheet = DefaultSheetName::TEXT_INPUT
      text_input_questions, error = read_text_input spreadsheet
    else
      error = [DefaultSheetName::TEXT_INPUT + 'do not existed in the imported file']
    end
    error_questions += error

    # Generating question banks
    generate_question_banks lib_name, lib_org, lib_code, checkbox_questions, multiple_choice_dropdown_questions, numerical_input_questions, text_input_questions
    # Return error questions
    # zip_folder = ZIP_FOLDER + lib_name + lib_code + lib_org
    # puts 'zip_folder'
    # p zip_folder
    create_zip_with_errors(ZIP_FOLDER, error_questions)
  end

  def self.create_zip_with_errors zip_folder, errors
    unless errors.empty?
      logger.info errors.inspect
      er_file_name = zip_folder + '/' + 'errors.txt'
      er_file = File.new(er_file_name, 'w+')

      errors.each do |error|
        er_file.puts error
      end
      er_file.close

    end
    library_folder = zip_folder + '/library'
    library_file_name = zip_folder + '/library.zip'

    zip_file = File.new(library_file_name, 'w+')
    zip_file.close
    Minitar.pack(library_folder, File.open(library_file_name, 'wb'))
    puts 'library_file_name'
    p library_file_name
    library_file_name
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when '.csv' then
      Roo::CSV.new(file.path)
    when '.xls' then
      Roo::Excel.new(file.path)
    when '.xlsx' then
      Roo::Excelx.new(file.path)
    else
      raise "Unknown file type: #{file.original_filename}"
    end
  end

  def self.generate_question_banks(lib_name, lib_org, lib_code, checkbox_questions, multiple_choice_dropdown_questions, numerical_input_questions, text_input_questions)
    list_by_lesson = group_by_lesson checkbox_questions, multiple_choice_dropdown_questions, numerical_input_questions, text_input_questions
    separated_list = []

    list_by_lesson.each do |list|
      next if list.nil?
      next if list.empty?

      list_hard = []
      list_medium = []
      list_easy = []
      list.each do |question|
        if question[:difficult_level] == DifficultLevel::EASY
          list_easy.append question
        elsif question[:difficult_level] == DifficultLevel::MEDIUM
          list_medium.append question
        else
          list_hard.append question
        end
      end
      separated_list.append list_easy
      separated_list.append list_medium
      separated_list.append list_hard
    end

    list_tar_gz_files = []
    master_folder = "#{lib_name}_#{lib_org}_#{lib_code}"
    FileUtils.mkdir_p master_folder.to_s

    separated_list.each do |list_questions|
      unless list_questions.empty?
        tar_gz_file = generate_question_bank lib_name, lib_org, lib_code, list_questions
        list_tar_gz_files.append tar_gz_file
      end
    end

    archive_and_download list_tar_gz_files
  end

  def self.generate_question_bank(lib_name, lib_org, lib_code, questions)
    unless questions.nil?
      unless questions.empty?
        first_question = questions.first
        append_code = first_question[:lesson].to_s + first_question[:difficult_level].to_s
        zip_file_name = first_question[:lesson].to_s + '_' + first_question[:difficult_level].to_s
        folder_name = "#{lib_name}_#{lib_org}_#{lib_code}/#{zip_file_name}"
        FileUtils.mkdir_p folder_name.to_s
        # Step 1: Generate folder containing problems and each problem in xml file
        problem_folder = "#{folder_name}/problem"
        FileUtils.mkdir_p problem_folder.to_s

        questions.each do |question|
          parse_to_xml(question, problem_folder)
        end

        new_lib_name = lib_name + '_' + append_code
        new_lib_code = lib_code + '_' + append_code
        # Step 2: Generate library description in xml file, policies folder and assets.json file
        generate_lib_des new_lib_name, lib_org, new_lib_code, questions, folder_name
        # Step 3: Archive to tar.gz file
        zip_recursive folder_name, zip_file_name
      end
    end
  end

  def self.archive_and_download(list_targz_files)
    library_folder = 'exported_library/library'
    FileUtils.rm_r library_folder
    library_file_name = 'exported_library/library.zip'
    FileUtils.mkdir_p library_folder
    list_targz_files.each do |file|
      FileUtils.mv(file, library_folder)
    end

    zip_file = File.new(library_file_name, 'w+')
    zip_file.close
    Minitar.pack(library_folder, File.open(library_file_name, 'wb'))
    library_file_name
  end

  def self.parse_to_xml(question, folder)
    case question[:question_type]
    when QuestionType::CHECKBOX
      write_xml_checkbox question, folder
    when QuestionType::MULTIPLE_CHOICE
      write_xml_multiple_choice question, folder
    when QuestionType::NUMERICAL
      write_xml_numerical question, folder
    when QuestionType::TEXT_INPUT
      write_xml_text_input question, folder
    end
  end

  def self.read_checkbox(sheet)
    questions = []
    errors = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = parse_checkbox_question(row)

      if valid?(question)
        questions.append question
      else
        errors.append errors?(question)
      end
    end

    [questions, errors]
  end

  def self.read_multiple_choice(sheet)
    questions = []
    errors = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = parse_multiple_choice_dropdown_question(row)

      if valid?(question)
        questions.append question
      else
        errors.append errors?(question)
      end
    end

    [questions, errors]
  end

  def self.read_numerical(sheet)
    questions = []
    errors = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = parse_numerical_input_question(row)

      if valid?(question)
        questions.append question
      else
        errors.append errors?(question)
      end
    end

    [questions, errors]
  end

  def self.read_text_input(sheet)
    questions = []
    errors = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = parse_text_input_question(row)

      if valid?(question)
        questions.append question
      else
        errors.append errors?(question)
      end
    end

    [questions, errors]
  end

  def self.write_xml_checkbox(question, folder)
    true_answer_index = question[:answer].split(',')
    true_answer_index = true_answer_index.map(&:strip)

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.problem('display_name' => question[:difficult_level] + question[:tt]) do
        xml.choiceresponse do
          xml.label question[:content]
          xml.checkboxgroup do
            ## Option 1
            if question[:choice1].present?
              xml.choice('correct' => true_answer_index.include?(1.to_s) ? 'true' : 'false') do
                xml.text(question[:choice1])
                if question[:feedback1].present?
                  xml.choicehint('selected' => 'false') do
                    xml.text(question[:feedback1])
                  end
                end
              end
            end
            ## Option 2
            if question[:choice2].present?
              xml.choice('correct' => true_answer_index.include?(2.to_s) ? 'true' : 'false') do
                xml.text(question[:choice2])
                if question[:feedback2].present?
                  xml.choicehint('selected' => 'false') do
                    xml.text(question[:feedback2])
                  end
                end
              end
            end
            ## Option 3
            if question[:choice3].present?
              xml.choice('correct' => true_answer_index.include?(3.to_s) ? 'true' : 'false') do
                xml.text(question[:choice3])
                if question[:feedback3].present?
                  xml.choicehint('selected' => 'false') do
                    xml.text(question[:feedback3])
                  end
                end
              end
            end
            ## Option 4
            if question[:choice4].present?
              xml.choice('correct' => true_answer_index.include?(4.to_s) ? 'true' : 'false') do
                xml.text(question[:choice4])
                if question[:feedback4].present?
                  xml.choicehint('selected' => 'false') do
                    xml.text(question[:feedback4])
                  end
                end
              end
            end
            ## Option 5
            if question[:choice5].present?
              xml.choice('correct' => true_answer_index.include?(5.to_s) ? 'true' : 'false') do
                xml.text(question[:choice5])
                if question[:feedback5].present?
                  xml.choicehint('selected' => 'false') do
                    xml.text(question[:feedback5])
                  end
                end
              end
            end
          end
        end
        if question[:hint].present?
          xml.demandhint do
            xml.hint question[:hint]
          end
        end
      end
    end

    filename = folder + '/' + question[:difficult_level] + question[:tt] + '.xml'
    begin
      outfile = File.new(filename, 'w+')
      File.write(outfile, builder.doc.root.to_xml)
      outfile.close
    rescue Errno::ENOENT => e
      logger.info "Caught the exception: #{e}"
    end
  end

  def self.write_xml_multiple_choice(question, folder)
    true_answer_index = question[:answer].split(',').first ## if have more than 1, choose first
    true_answer_index = true_answer_index.strip.to_i

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.problem('display_name' => question[:difficult_level] + question[:tt]) do
        xml.multiplechoiceresponse do
          xml.label question[:content]
          xml.choicegroup do
            ## Option 1
            if question[:choice1].present?
              xml.choice('correct' => true_answer_index == 1 ? 'true' : 'false') do
                xml.text(question[:choice1])
                if question[:feedback1].present?
                  xml.choicehint do
                    xml.text(question[:feedback1])
                  end
                end
              end
            end
            ## Option 2
            if question[:choice2].present?
              xml.choice('correct' => true_answer_index == 2 ? 'true' : 'false') do
                xml.text(question[:choice2])
                if question[:feedback2].present?
                  xml.choicehint do
                    xml.text(question[:feedback2])
                  end
                end
              end
            end
            ## Option 3
            if question[:choice3].present?
              xml.choice('correct' => true_answer_index == 3 ? 'true' : 'false') do
                xml.text(question[:choice3])
                if question[:feedback3].present?
                  xml.choicehint do
                    xml.text(question[:feedback3])
                  end
                end
              end
            end
            ## Option 4
            if question[:choice4].present?
              xml.choice('correct' => true_answer_index == 4 ? 'true' : 'false') do
                xml.text(question[:choice4])
                if question[:feedback4].present?
                  xml.choicehint do
                    xml.text(question[:feedback4])
                  end
                end
              end
            end
            ## Option 5
            if question[:choice5].present?
              xml.choice('correct' => true_answer_index == 5 ? 'true' : 'false') do
                xml.text(question[:choice5])
                if question[:feedback5].present?
                  xml.choicehint do
                    xml.text(question[:feedback5])
                  end
                end
              end
            end
          end
        end
        if question[:hint].present?
          xml.demandhint do
            xml.hint question[:hint]
          end
        end
      end
    end

    filename = folder + '/' + question[:difficult_level] + question[:tt] + '.xml'
    begin
      outfile = File.new(filename, 'w+')
      File.write(outfile, builder.doc.root.to_xml)
      outfile.close
    rescue Errno::ENOENT => e
      logger.info "Caught the exception: #{e}"
    end
  end

  def self.write_xml_numerical(question, folder)

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.problem('display_name' => question[:difficult_level] + question[:tt]) do
        if question[:answer].present?
          xml.numericalresponse('answer' => question[:answer].strip) do
            xml.label question[:content]
            xml.responseparam('type' => 'tolerance', 'default' => '5')
            xml.formulaequationinput
            if question[:feedback1].present?
              xml.correcthint do
                xml.text(question[:feedback1])
              end
            end
          end
        end
        if question[:hint].present?
          xml.demandhint do
            xml.hint question[:hint]
          end
        end
      end
    end

    filename = folder + '/' + question[:difficult_level] + question[:tt] + '.xml'
    begin
      outfile = File.new(filename, 'w+')
      File.write(outfile, builder.doc.root.to_xml)
      outfile.close
    rescue Errno::ENOENT => e
      logger.info "Caught the exception: #{e}"
    end
  end

  def self.write_xml_text_input(question, folder)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.problem('display_name' => question[:difficult_level] + question[:tt]) do
        xml.stringresponse('answer' => question[:answer].strip) do
          xml.label question[:content]
          if question[:feedback1].present?
            xml.correcthint question[:feedback1]
          end
          xml.textline('size' => '20')
        end
        if question[:hint].present?
          xml.demandhint do
            xml.hint question[:hint]
          end
        end
      end
    end

    filename = folder + '/' + question[:difficult_level] + question[:tt] + '.xml'
    begin
      outfile = File.new(filename, 'w+')
      File.write(outfile, builder.doc.root.to_xml)
      outfile.close
    rescue Errno::ENOENT => e
      logger.info "Caught the exception: #{e}"
    end
  end

  def self.generate_lib_des(lib_name, lib_org, lib_code, problems_list, folder)
    if problems_list.empty?
      return
    end
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.library('xblock-family' => 'xblock.v1', 'display_name' => lib_name, 'org' => lib_org, 'library' => lib_code) do
        problems_list.each do |problem|
          xml.problem('url_name' => problem[:difficult_level].to_s + problem[:tt].to_s)
        end
      end
    end

    # Create library.xml
    filename = folder + '/' + 'library.xml'
    begin
      outfile = File.new(filename, 'w+')
      File.write(outfile, builder.doc.root.to_xml)
      outfile.close
    rescue Errno::ENOENT => e
      logger.info "Caught the exception: #{e}"
    end

    # Create policies folder & policies.json
    policies_folder = folder + '/' + 'policies'
    FileUtils.mkdir_p policies_folder

    filename = policies_folder + '/' + 'assets.json'
    begin
      outfile = File.new(filename, 'w+')
      File.write(outfile, '{}')
      outfile.close
    rescue Errno::ENOENT => e
      logger.info "Caught the exception: #{e}"
    end
  end

  def self.zip_recursive(directory, filename)
    full_file_name = directory + filename + '.tar.gz'
    zip_file = File.new(full_file_name, 'w+')
    zip_file.close
    Minitar.pack(directory, File.open(full_file_name, 'wb'))
    full_file_name
  end

  def self.group_by_lesson(checkbox_questions, multiple_choice_dropdown_questions, numerical_input_questions, text_input_questions)
    lesson_list = []
    list_by_lesson = []

    unless checkbox_questions.nil?
      checkbox_questions.each do |question|
        if lesson_list.include? question[:lesson]
        else
          lesson_list.append(question[:lesson])
          list_by_lesson[question[:lesson].to_i] = []
        end
        list_by_lesson[question[:lesson].to_i].append(question)
      end
    end

    unless multiple_choice_dropdown_questions.nil?
      multiple_choice_dropdown_questions.each do |question|
        if lesson_list.include? question[:lesson]
        else
          lesson_list.append(question[:lesson])
          list_by_lesson[question[:lesson].to_i] = []
        end
        list_by_lesson[question[:lesson].to_i].append(question)
      end
    end

    unless numerical_input_questions.nil?
      numerical_input_questions.each do |question|
        if lesson_list.include? question[:lesson]
        else
          lesson_list.append(question[:lesson])
          list_by_lesson[question[:lesson].to_i] = []
        end
        list_by_lesson[question[:lesson].to_i].append(question)
      end
    end

    unless text_input_questions.nil?
      text_input_questions.each do |question|
        if lesson_list.include? question[:lesson]
        else
          lesson_list.append(question[:lesson])
          list_by_lesson[question[:lesson].to_i] = []
        end
        list_by_lesson[question[:lesson].to_i].append(question)
      end
    end

    list_by_lesson
  end

  def self.parse_checkbox_question(row)
    {
        tt: row[0].cell_value,
        course_code: row[1].cell_value,
        lesson: row[2].cell_value,
        lo: row[3].cell_value,
        content: row[4].cell_value,
        difficult_level: row[5].cell_value,
        choice1: row[6].nil? ? '' : row[6].cell_value,
        choice2: row[7].nil? ? '' : row[7].cell_value,
        choice3: row[8].nil? ? '' : row[8].cell_value,
        choice4: row[9].nil? ? '' : row[9].cell_value,
        choice5: row[10].nil? ? '' : row[10].cell_value,
        answer: row[11].nil? ? '' : row[11].cell_value,
        hint: row[12].nil? ? '' : row[12].cell_value,
        feedback1: row[13].nil? ? '' : row[13].cell_value,
        feedback2: row[14].nil? ? '' : row[14].cell_value,
        feedback3: row[15].nil? ? '' : row[15].cell_value,
        feedback4: row[16].nil? ? '' : row[16].cell_value,
        feedback5: row[17].nil? ? '' : row[17].cell_value,
        question_type: QuestionType::CHECKBOX
    }
  end

  def self.parse_multiple_choice_dropdown_question(row)
    {
        tt: row[0].cell_value,
        course_code: row[1].cell_value,
        lesson: row[2].cell_value,
        lo: row[3].cell_value,
        content: row[4].cell_value,
        difficult_level: row[5].cell_value,
        choice1: row[6].nil? ? '' : row[6].cell_value,
        choice2: row[7].nil? ? '' : row[7].cell_value,
        choice3: row[8].nil? ? '' : row[8].cell_value,
        choice4: row[9].nil? ? '' : row[9].cell_value,
        choice5: row[10].nil? ? '' : row[10].cell_value,
        answer: row[11].nil? ? '' : row[11].cell_value,
        hint: row[12].nil? ? '' : row[12].cell_value,
        feedback1: row[13].nil? ? '' : row[13].cell_value,
        feedback2: row[14].nil? ? '' : row[14].cell_value,
        feedback3: row[15].nil? ? '' : row[15].cell_value,
        feedback4: row[16].nil? ? '' : row[16].cell_value,
        feedback5: row[17].nil? ? '' : row[17].cell_value,
        status: row[18].nil? ? '' : row[18].cell_value,
        question_type: QuestionType::MULTIPLE_CHOICE
    }
  end

  def self.parse_numerical_input_question(row)
    {
        tt: row[0].cell_value,
        course_code: row[1].cell_value,
        lesson: row[2].cell_value,
        lo: row[3].cell_value,
        content: row[4].cell_value,
        difficult_level: row[5].cell_value,
        answer: row[6].nil? ? '' : row[6].cell_value,
        hint: row[7].nil? ? '' : row[7].cell_value,
        feedback1: row[8].nil? ? '' : row[8].cell_value,
        feedback2: row[9].nil? ? '' : row[9].cell_value,
        feedback3: row[10].nil? ? '' : row[10].cell_value,
        feedback4: row[11].nil? ? '' : row[11].cell_value,
        feedback5: row[12].nil? ? '' : row[12].cell_value,
        status: row[13].nil? ? '' : row[13].cell_value,
        question_type: QuestionType::NUMERICAL
    }
  end

  def self.parse_text_input_question(row)
    {
        tt: row[0].cell_value,
        course_code: row[1].cell_value,
        lesson: row[2].cell_value,
        lo: row[3].cell_value,
        content: row[4].cell_value,
        difficult_level: row[5].cell_value,
        answer: row[6].nil? ? '' : row[6].cell_value,
        hint: row[7].nil? ? '' : row[7].cell_value,
        feedback1: row[8].nil? ? '' : row[8].cell_value,
        feedback2: row[9].nil? ? '' : row[9].cell_value,
        feedback3: row[10].nil? ? '' : row[10].cell_value,
        feedback4: row[11].nil? ? '' : row[11].cell_value,
        feedback5: row[12].nil? ? '' : row[12].cell_value,
        status: row[13].nil? ? '' : row[13].cell_value,
        question_type: QuestionType::TEXT_INPUT
    }
  end

  # def self.valid?(question)
  #   if question[:tt].present? && question[:course_code].present? &&
  #       question[:lesson].present? && question[:lo].present? && question[:content].present? &&
  #       question[:difficult_level].present? && question[:answer].present?
  #     return true
  #   end
  #   false
  # end

  def self.valid?(question)
    if question[:tt].present? && question[:course_code].present? &&
        question[:lesson].present? && question[:content].present? &&
        question[:difficult_level].present? && question[:answer].present?
      return true
    end
    false
  end

  # def self.errors?(question)
  #   if question[:tt].present? && question[:course_code].present? &&
  #       question[:lesson].present? && question[:content].present? &&
  #       question[:difficult_level].present? && question[:answer].present?
  #     nil
  #   else
  #     "#{question[:tt]} - #{question[:course_code]} - #{question[:lesson]} - #{question[:lo]} - #{question[:difficult_level]} - #{question[:answer]} - #{question[:question_type]}"
  #   end
  # end

  def self.errors?(question)
    if question[:tt].present? && question[:course_code].present? &&
        question[:lesson].present? && question[:content].present? &&
        question[:difficult_level].present? && question[:answer].present?
      nil
    else
      "#{question[:tt]} - #{question[:course_code]} - #{question[:lesson]} - #{question[:difficult_level]} - #{question[:answer]} - #{question[:question_type]}"
    end
  end
end

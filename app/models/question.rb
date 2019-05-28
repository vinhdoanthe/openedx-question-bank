# frozen_string_literal: true

class Question < ApplicationRecord
  module QuestionType
    CHECKBOX = 'CHECKBOX'
    MULTIPLE_CHOICE = 'MULTIPLE_CHOICE'
    NUMERICAL = 'NUMERICAL'
    TEXT_INPUT = 'TEXT_INPUT'
  end

  module DifficultLevel
    HARD = 'H'
    MEDIUM = 'M'
    EASY = 'E'
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)
    # Sheet 1: LIBRARY_DESCRIPTION
    lib_des_sheet = spreadsheet.sheet('Library Description')
    lib_name = lib_des_sheet.a1
    lib_org = lib_des_sheet.a2
    lib_code = lib_des_sheet.a3

    puts "#{lib_name} - #{lib_org} - #{lib_code}"

    # Sheet 2: Checkboxes questions
    spreadsheet.default_sheet = 'Checkboxes'
    checkbox_questions = read_checkbox spreadsheet
    puts "checkbox_questions #{checkbox_questions.inspect}"

    # Sheet 3: Multiple Choice-Drop Down questions
    spreadsheet.default_sheet = 'Multiple Choice-Drop Down'
    multiple_choice_dropdown_questions = read_multiple_choice spreadsheet
    puts "multiple_choice_dropdown_questions #{multiple_choice_dropdown_questions.inspect}"

    # Sheet 4: Numerical Input questions
    spreadsheet.default_sheet = 'Numerical Input'
    numerical_input_questions = read_numerical spreadsheet
    puts "numerical_input_questions #{numerical_input_questions.inspect}"

    # Sheet 5: Text Input questions
    spreadsheet.default_sheet = 'Text Input'
    text_input_questions = read_text_input spreadsheet
    puts "text_input_questions #{text_input_questions.inspect}"

    # Generating question banks
    generate_question_banks lib_name, lib_org, lib_code, checkbox_questions, multiple_choice_dropdown_questions, numerical_input_questions, text_input_questions
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
    seperated_list = []

    list_by_lesson.each do |list|
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
      seperated_list.append list_easy
      seperated_list.append list_medium
      seperated_list.append list_hard
    end

    list_targz_files = []
    seperated_list.each do |list_questions|
      targz_file = generate_question_bank lib_name, lib_org, lib_code, list_questions
      list_targz_files.append targz_file
    end

    archive_and_download list_targz_files
  end

  def self.generate_question_bank lib_name, lib_org, lib_code, questions
    unless questions.nil?
      unless questions.empty?
        # Step 1: Generate folder containing problems and each problem in xml file

        # Step 2: Generate library description in xml file, policies folder and assets.json file

        # Step 3: Archive to tar.gz file
      end
    end
  end

  def self.archive_and_download list_targz_files

  end

  def self.parse_to_xml(question, type)
    case type
    when QuestionType::CHECKBOX
      write_xml_checkbox question
    when QuestionType::MULTIPLE_CHOICE
      write_xml_multiple_choice question
    when QuestionType::NUMERICAL
      write_xml_numerical question
    when QuestionType::TEXT_INPUT
      write_xml_text_input question
    end
  end

  def self.read_checkbox(sheet)
    puts "sheet #{sheet.inspect}"
    questions = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = {
          tt: row[1].cell_value,
          course_code: row[2].cell_value,
          lesson: row[3].cell_value,
          lo: row[4].cell_value,
          content: row[5].cell_value,
          difficult_level: row[6].cell_value,
          choice1: row[7].cell_value,
          choice2: row[8].cell_value,
          choice3: row[9].cell_value,
          choice4: row[10].cell_value,
          choice5: row[11].cell_value,
          answer: row[12].cell_value,
          hint: row[13].cell_value,
          feedback1: row[14].cell_value,
          feedback2: row[15].cell_value,
          feedback3: row[16].cell_value,
          feedback4: row[17].cell_value,
          feedback5: row[18].cell_value,
          question_type: QuestionType::CHECKBOX
      }
      questions.append question
    end
    questions
  end

  def self.read_multiple_choice(sheet)
    questions = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = {
          tt: row[1].cell_value,
          course_code: row[2].cell_value,
          lesson: row[3].cell_value,
          lo: row[4].cell_value,
          content: row[5].cell_value,
          difficult_level: row[6].cell_value,
          choice1: row[7].cell_value,
          choice2: row[8].cell_value,
          choice3: row[9].cell_value,
          choice4: row[10].cell_value,
          choice5: row[11].cell_value,
          answer: row[12].cell_value,
          hint: row[13].cell_value,
          feedback1: row[14].cell_value,
          feedback2: row[15].cell_value,
          feedback3: row[16].cell_value,
          feedback4: row[17].cell_value,
          feedback5: row[18].cell_value,
          status: row[19].cell_value,
          question_type: QuestionType::MULTIPLE_CHOICE
      }
      questions.append question
    end
    questions
  end

  def self.read_numerical(sheet)
    questions = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = {
          tt: row[1].cell_value,
          course_code: row[2].cell_value,
          lesson: row[3].cell_value,
          lo: row[4].cell_value,
          content: row[5].cell_value,
          difficult_level: row[6].cell_value,
          answer: row[7].cell_value,
          hint: row[8].cell_value,
          feedback1: row[9].cell_value,
          feedback2: row[10].cell_value,
          feedback3: row[11].cell_value,
          feedback4: row[12].cell_value,
          feedback5: row[13].cell_value,
          status: row[14].cell_value,
          question_type: QuestionType::NUMERICAL
      }
      questions.append question
    end
    questions
  end

  def self.read_text_input(sheet)
    questions = []
    sheet.each_row_streaming(offset: 1) do |row|
      next if row[1].nil?
      next if row[1].cell_value.nil?

      question = {
          tt: row[1].cell_value,
          course_code: row[2].cell_value,
          lesson: row[3].cell_value,
          lo: row[4].cell_value,
          content: row[5].cell_value,
          difficult_level: row[6].cell_value,
          answer: row[7].cell_value,
          hint: row[8].cell_value,
          feedback1: row[9].cell_value,
          feedback2: row[10].cell_value,
          feedback3: row[11].cell_value,
          feedback4: row[12].cell_value,
          feedback5: row[13].cell_value,
          status: row[14].cell_value,
          question_type: QuestionType::TEXT_INPUT
      }
      questions.append question
    end
    questions
  end

  def self.write_xml_checkbox(question)
    ;
  end

  def self.write_xml_multiple_choice(question)
    ;
  end

  def self.write_xml_numerical(question)
    ;
  end

  def self.write_xml_text_input(question)
    ;
  end

  def self.generate_lib_des(lib_name, lib_org, lib_code, problems_list)
    ;
  end

  def self.zip_recursive(directory)
    ;
  end

  def self.group_by_lesson(checkbox_questions, multiple_choice_dropdown_questions, numerical_input_questions, text_input_questions)
    lesson_list = []
    list_by_lesson = []

    checkbox_questions.each do |question|
      if lesson_list.include? question[:lesson]
      else
        lesson_list.append(question[:lesson])
        list_by_lesson[question[:lesson]] = []
      end
      list_by_lesson[question[:lesson]].append(question)
    end

    multiple_choice_dropdown_questions.each do |question|
      if lesson_list.include? question[:lesson]
      else
        lesson_list.append(question[:lesson])
        list_by_lesson[question[:lesson]] = []
      end
      list_by_lesson[question[:lesson]].append(question)
    end

    numerical_input_questions.each do |question|
      if lesson_list.include? question[:lesson]
      else
        lesson_list.append(question[:lesson])
        list_by_lesson[question[:lesson]] = []
      end
      list_by_lesson[question[:lesson]].append(question)
    end

    text_input_questions.each do |question|
      if lesson_list.include? question[:lesson]
      else
        lesson_list.append(question[:lesson])
        list_by_lesson[question[:lesson]] = []
      end
      list_by_lesson[question[:lesson]].append(question)
    end

    list_by_lesson
  end

end

require 'rails_helper'

RSpec.describe GameQuestion, type: :model do
   # Задаем локальную переменную game_question, доступную во всех тестах этого
  # сценария: она будет создана на фабрике заново для каждого блока it,
  # где она вызывается.
  let(:game_question) do
    FactoryBot.create(:game_question, a: 2, b: 1, c: 4, d: 3)
  end

  # Группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # Тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq(
        'a' => game_question.question.answer2,
        'b' => game_question.question.answer1,
        'c' => game_question.question.answer4,
        'd' => game_question.question.answer3
      )
    end

    it 'correct .answer_correct?' do
      # Именно под буквой b в тесте мы спрятали указатель на верный ответ
      expect(game_question.answer_correct?('b')).to be_truthy
    end
  end

  context 'game methods' do
    it 'correct .level & .text delegates' do
      expect(game_question.text).to eq(game_question.question.text)
      expect(game_question.level).to eq(game_question.question.level)
    end
  end

  context '.correct_answer_key' do
    it 'return correct key' do
      expect(game_question.correct_answer_key).to eq 'b'
    end
    it 'return not correct key' do
      expect(game_question.correct_answer_key).not_to eq 'a'
    end
  end


  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }

  context 'user helpers' do
    it 'correct audience_help' do
      # проверяем, что этой подсказки нету
      expect(game_question.help_hash).not_to include(:audience_help)

      game_question.add_audience_help

      expect(game_question.help_hash).to include(:audience_help)
      expect(game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
    end

    it '#help_hash return hash' do
      expect(game_question.help_hash).to eq({})

      game_question.help_hash[:first_key] = 'first value'
      game_question.help_hash[:last_key] = 'last value'

      expect(game_question.save).to be_truthy

      gq_from_db = GameQuestion.find(game_question.id)

      expect(gq_from_db.help_hash).to eq({first_key: 'first value', last_key: 'last value'})
    end

    it '#50/50' do
      # проверяем, что этой подсказки нету
      expect(game_question.help_hash).not_to include(:fifty_fifty)

      game_question.add_fifty_fifty

      expect(game_question.help_hash).to include(:fifty_fifty)
      expect(game_question.help_hash[:fifty_fifty].size).to eq(2)
      expect(game_question.help_hash[:fifty_fifty]).to include('b')
    end

    it '#friend_call' do
      # проверяем, что этой подсказки нету
      expect(game_question.help_hash).not_to include(:friend_call)

      game_question.add_friend_call

      expect(game_question.help_hash).to include(:friend_call)
      expect(game_question.help_hash[:friend_call]).to be
    end
  end

end

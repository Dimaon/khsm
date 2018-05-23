require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
      # RANDOM при создании игры.
      generate_questions(60)

      game = nil

      # Создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
        # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
      }.to change(Game, :count).by(1).and(
        # GameQuestion.count +15
        change(GameQuestion, :count).by(15).and(
          # Game.count не должен измениться
          change(Question, :count).by(0)
        )
      )

      # Проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      # Проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end

    it 'correct initialize' do
      expect(game_w_questions.finished_at).to eq nil
      expect(game_w_questions.current_level).to eq 0
      expect(game_w_questions.is_failed).to be_falsey
      expect(game_w_questions.prize).to eq 0
    end
  end

  # Тесты на основную игровую логику
  context 'game mechanics' do
    # Правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # Текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # Перешли на след. уровень так как предидущий ответ был верный
      expect(game_w_questions.current_level).to eq(1) # level + 1

      # Ранее текущий вопрос стал предыдущим
      expect(game_w_questions.current_game_question).not_to eq(q)

      # Игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end
  end

  context 'game methods' do
    it 'correct .take_money!' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)
      game_w_questions.take_money!
      prize = game_w_questions.prize

      expect(prize).to be > 0
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end
  end

  context '.status' do
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq :won
    end

    # Если с момента создания вопроса прошло более 35 минут
    it ':timeout' do
      game_w_questions.is_failed = true
      game_w_questions.created_at =  Time.now - (Game::TIME_LIMIT + 1.second)
      expect(game_w_questions.status).to eq :timeout
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq :fail
    end

    # По-умолчанию возваращает статус money
    it ':money' do
      expect(game_w_questions.status).to eq :money
    end
  end

  context '.current_game_question' do
    it 'return valid instance of GameQuestion' do
      expect(game_w_questions.current_game_question).to be_instance_of(GameQuestion)
      expect(game_w_questions.current_level).to eq 0
    end
  end

  context '.previous_level' do
    it 'correct previous_level' do
      expect(game_w_questions.previous_level).to eq -1
    end
  end

  context 'answer_current_question!' do
   let!(:q) { game_w_questions.current_game_question }
   let!(:level) { game_w_questions.current_level }

    # False если игра закончена
    it 'return false if finished' do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be_falsey
    end

    # False если время на игру вышло
    it 'return false if time_out!' do
      game_w_questions.created_at =  Time.now - 36.minutes # (Game::TIME_LIMIT + 1.second)
      expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be_falsey
    end

    # Если ответили верно и это не последний уровень
    it 'correct answer after not final question' do
      expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be_truthy

      # Перешли на след. уровень так как предыдущий ответ был верный
      expect(game_w_questions.current_level).to eq(1) # level + 1
    end

    # Если ответили не верно (верный ответ "d")
    it 'incorrect answer' do
      expect(game_w_questions.answer_current_question!('c')).to be_falsey
      # уровень не увеличивается так как предидущий ответ был не верный
      expect(game_w_questions.current_level).not_to eq(1)
      #  заканчиваем игру методом finish_game! и возвращаем результаты
      expect(game_w_questions.prize).to eq 0
      expect(game_w_questions.is_failed).to be_truthy
    end

    # Если ответили верно и вопрос последний
    it 'last question and answer is correct' do
      15.times { game_w_questions.answer_current_question!(q.correct_answer_key) }
      #  заканчиваем игру методом finish_game! и возвращаем результаты
      expect(game_w_questions.current_level).to eq 15
      expect(game_w_questions.prize).to eq 1_000_000 # Game::PRIZES[Question::QUESTION_LEVELS.max]
      expect(game_w_questions.is_failed).to be_falsey
    end
  end
end

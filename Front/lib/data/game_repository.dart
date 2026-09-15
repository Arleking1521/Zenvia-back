import '../models/game.dart';

abstract class GameRepository {
  Future<GameSessionData> startGame(GameStartRequest request);

  Future<GameNextResult> getNextQuestion(int sessionId);

  Future<GameAnswerResult> answerSingle({
    required int sessionId,
    required int questionId,
    required int answerId,
  });

  Future<GameAnswerResult> answerMatching({
    required int sessionId,
    required int questionId,
    required Map<int, int> pairs,
  });

  Future<GameFinishResult> finishGame(int sessionId);
}

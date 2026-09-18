import 'package:dio/dio.dart';

import '../models/game.dart';
import '../models/language.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'game_repository.dart';

class ApiGameRepository implements GameRepository {
  final ApiClient client;

  ApiGameRepository(this.client);

  @override
  Future<GameSessionData> startGame(GameStartRequest request) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        ApiConfig.api('game-sessions/'),
        data: {
          'language': request.language.apiCode,
          'topic': request.topicId,
          'game_type': request.gameType.apiCode,
          'question_count': request.questionCount,
        },
      );
      return _session(response.data ?? const {});
    } on DioException catch (e) {
      throw GameApiException(_message(e));
    }
  }

  @override
  Future<GameNextResult> getNextQuestion(int sessionId) async {
    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        ApiConfig.api('game-sessions/$sessionId/next/'),
      );
      final data = response.data ?? const {};
      final complete = data['complete'] == true;
      final rawQuestion = _map(data['question']);
      return GameNextResult(
        complete: complete,
        question: rawQuestion == null ? null : _question(rawQuestion),
      );
    } on DioException catch (e) {
      throw GameApiException(_message(e));
    }
  }

  @override
  Future<GameAnswerResult> answerSingle({
    required int sessionId,
    required int questionId,
    required int answerId,
  }) async {
    return _answer(
      sessionId,
      {
        'question_id': questionId,
        'answer_id': answerId,
      },
    );
  }

  @override
  Future<GameAnswerResult> answerMatching({
    required int sessionId,
    required int questionId,
    required Map<int, int> pairs,
  }) async {
    return _answer(
      sessionId,
      {
        'question_id': questionId,
        'pairs': pairs.entries
            .map(
              (entry) => {
                'concept_id': entry.key,
                'word_id': entry.value,
              },
            )
            .toList(),
      },
    );
  }

  Future<GameAnswerResult> _answer(
    int sessionId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        ApiConfig.api('game-sessions/$sessionId/answer/'),
        data: payload,
      );
      final data = response.data ?? const {};
      final rawSession = _map(data['session']) ?? const <String, dynamic>{};
      final pairRows = data['pair_results'];
      final pairs = <PairAnswerResult>[];
      if (pairRows is List) {
        for (final raw in pairRows) {
          final row = _map(raw);
          if (row == null) continue;
          pairs.add(
            PairAnswerResult(
              conceptId: _int(row['concept_id']),
              wordId: _int(row['word_id']),
              correctWordId: _int(row['correct_word_id']),
              correct: row['correct'] == true,
            ),
          );
        }
      }
      return GameAnswerResult(
        correct: data['correct'] == true,
        correctItems: _int(data['correct_items']),
        wrongItems: _int(data['wrong_items']),
        correctAnswerId: _nullableInt(data['correct_answer_id']),
        pairResults: pairs,
        session: _session(rawSession),
      );
    } on DioException catch (e) {
      throw GameApiException(_message(e));
    }
  }

  @override
  Future<GameFinishResult> finishGame(int sessionId) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        ApiConfig.api('game-sessions/$sessionId/finish/'),
        data: const <String, dynamic>{},
      );
      final data = response.data ?? const {};
      final session = _session(_map(data['game']) ?? const {});
      return GameFinishResult(
        session: session,
        totalXp: _int(data['total_xp']),
        xpRequested: data.containsKey('xp_requested')
            ? _int(data['xp_requested'])
            : session.xpEarned,
        xpGranted: data.containsKey('xp_granted')
            ? _int(data['xp_granted'])
            : session.xpEarned,
        dailyXp: data.containsKey('daily_xp')
            ? _int(data['daily_xp'])
            : session.xpEarned,
        dailyXpLimit: data.containsKey('daily_xp_limit')
            ? _int(data['daily_xp_limit'])
            : 0,
        dailyXpRemaining: data.containsKey('daily_xp_remaining')
            ? _int(data['daily_xp_remaining'])
            : 0,
        dailyLimitReached: data['daily_limit_reached'] == true,
      );
    } on DioException catch (e) {
      throw GameApiException(_message(e));
    }
  }

  GameSessionData _session(Map<String, dynamic> row) {
    return GameSessionData(
      id: _int(row['id']),
      gameType: GameTypeX.fromApiCode(row['game_type']?.toString()),
      languageCode: row['language_code']?.toString() ?? '',
      topicId: _int(row['topic']),
      questionCount: _int(row['question_count']),
      roundsAnswered: _int(row['rounds_answered']),
      correctCount: _int(row['correct_count']),
      wrongCount: _int(row['wrong_count']),
      xpEarned: _int(row['xp_earned']),
      finished: row['finished_at'] != null,
    );
  }

  GameQuestionData _question(Map<String, dynamic> row) {
    final promptRow = _map(row['prompt']);
    return GameQuestionData(
      id: _int(row['id']),
      sequence: _int(row['sequence']),
      total: _int(row['total']),
      gameType: GameTypeX.fromApiCode(row['game_type']?.toString()),
      prompt: promptRow == null
          ? null
          : GamePrompt(
              kind: promptRow['kind']?.toString() ?? '',
              text: promptRow['text']?.toString(),
              transcription: promptRow['transcription']?.toString(),
              imageUrl: promptRow['image']?.toString(),
              audioUrl: promptRow['audio']?.toString(),
            ),
      options: _options(row['options']),
      left: _options(row['left']),
      right: _options(row['right']),
    );
  }

  List<GameOption> _options(dynamic value) {
    if (value is! List) return const [];
    final result = <GameOption>[];
    for (final raw in value) {
      final row = _map(raw);
      if (row == null) continue;
      result.add(
        GameOption(
          id: _int(row['id']),
          text: row['text']?.toString(),
          transcription: row['transcription']?.toString(),
          imageUrl: row['image']?.toString(),
        ),
      );
    }
    return result;
  }

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['error'] ?? data['non_field_errors'];
      if (detail is List && detail.isNotEmpty) return detail.first.toString();
      if (detail != null) return detail.toString();
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return 'Не удалось выполнить запрос к игре.';
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}

class GameApiException implements Exception {
  final String message;
  const GameApiException(this.message);

  @override
  String toString() => message;
}

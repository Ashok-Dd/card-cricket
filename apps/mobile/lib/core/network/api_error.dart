import 'package:dio/dio.dart';

/// Nest's default exception filter returns `{ message: string | string[] }`.
/// Use this everywhere a caught error needs to become on-screen text instead
/// of a raw exception/stack trace.
String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is List) return message.join(', ');
      return message.toString();
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      // The backend runs on a free tier that spins down when idle — the
      // very first request after a gap can take a while to get a response
      // while it wakes back up, which is what actually shows up as a raw
      // Dio timeout message if left unhandled. This happens on any
      // request, not just app launch (which has its own "waking up"
      // splash-screen animation), so any screen's error text needs to
      // explain it too.
      return "The server is waking up (this can take up to a minute on the free tier) — please try again.";
    }
    return error.message ?? 'Something went wrong. Please try again.';
  }
  return error.toString();
}

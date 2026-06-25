class ApiResponse<T> {
  const ApiResponse({required this.data, required this.statusCode});

  final T data;
  final int statusCode;
}

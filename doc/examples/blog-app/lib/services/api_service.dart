// ignore_for_file: inference_failure_on_function_invocation

import 'package:dio/dio.dart';
import 'package:smart_cache/smart_cache.dart';
import '../models/post.dart';

class ApiService {
  final Dio _dio;
  final SmartCacheManager? _cache;

  ApiService({Dio? dio, SmartCacheManager? cache})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://jsonplaceholder.typicode.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            )),
        _cache = cache {
    if (_cache != null) {
      _dio.interceptors.add(SmartCacheDioInterceptor(_cache));
    }
  }

  Future<List<Post>> getPosts() async {
    final response = await _dio.get('/posts');
    final data = response.data as List;
    return data.map((json) => Post.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Post> getPost(int id) async {
    final response = await _dio.get('/posts/$id');
    return Post.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Post> createPost(Post post) async {
    final response = await _dio.post(
      '/posts',
      data: post.toJson(),
    );
    return Post.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Post> updatePost(int id, Post post) async {
    final response = await _dio.put(
      '/posts/$id',
      data: post.toJson(),
    );
    return Post.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePost(int id) async {
    await _dio.delete('/posts/$id');
  }
}

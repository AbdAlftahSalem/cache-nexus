import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cache_nexus_example/models/post.dart';
import 'package:cache_nexus_example/services/api_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late ApiService apiService;

  setUp(() {
    mockDio = MockDio();
    apiService = ApiService(dio: mockDio);
  });

  group('ApiService', () {
    final mockPosts = [
      {'id': 1, 'userId': 1, 'title': 'Test Post', 'body': 'Test Body'},
      {'id': 2, 'userId': 2, 'title': 'Another Post', 'body': 'Another Body'},
    ];

    final mockPost = {
      'id': 1,
      'userId': 1,
      'title': 'Test Post',
      'body': 'Test Body',
    };

    test('getPosts returns list of Post', () async {
      when(() => mockDio.get('/posts')).thenAnswer(
        (_) async => Response(
          data: mockPosts,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/posts'),
        ),
      );

      final posts = await apiService.getPosts();

      expect(posts, isA<List<Post>>());
      expect(posts.length, 2);
      expect(posts[0].id, 1);
      expect(posts[0].title, 'Test Post');
      expect(posts[1].id, 2);
      verify(() => mockDio.get('/posts')).called(1);
    });

    test('getPost returns single Post', () async {
      when(() => mockDio.get('/posts/1')).thenAnswer(
        (_) async => Response(
          data: mockPost,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/posts/1'),
        ),
      );

      final post = await apiService.getPost(1);

      expect(post, isA<Post>());
      expect(post.id, 1);
      expect(post.title, 'Test Post');
      verify(() => mockDio.get('/posts/1')).called(1);
    });

    test('createPost returns created Post', () async {
      final input = Post(
        id: 99,
        userId: 1,
        title: 'New Post',
        body: 'New Body',
      );
      final response = {
        'id': 99,
        'userId': 1,
        'title': 'New Post',
        'body': 'New Body',
      };

      when(() => mockDio.post('/posts', data: input.toJson())).thenAnswer(
        (_) async => Response(
          data: response,
          statusCode: 201,
          requestOptions: RequestOptions(path: '/posts'),
        ),
      );

      final post = await apiService.createPost(input);

      expect(post, isA<Post>());
      expect(post.id, 99);
      expect(post.title, 'New Post');
      verify(() => mockDio.post('/posts', data: input.toJson())).called(1);
    });
  });
}

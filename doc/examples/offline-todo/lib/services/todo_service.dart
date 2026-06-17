import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../models/todo.dart';

class TodoService extends InheritedWidget {
  final SmartCacheManager cache;
  final SyncEngine syncEngine;

  TodoService({
    super.key,
    required this.cache,
    required this.syncEngine,
    required super.child,
  });

  static TodoService of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TodoService>()!;
  }

  Future<List<Todo>> getTodos() async {
    return cache.get<List<Todo>>(
      key: 'todos',
      fetcher: () async => <Todo>[],
      ttl: const Duration(hours: 24),
    );
  }

  Future<void> addTodo(Todo todo) async {
    // 1. Add to cache immediately (instant UI update)
    final todos = await getTodos();
    await cache.set<List<Todo>>(key: 'todos', data: [...todos, todo]);

    // 2. Queue for sync when online
    await cache.enqueueSyncTask(
      SyncTask(
        id: 'create_${todo.id}',
        key: 'todos',
        endpoint: 'https://api.example.com/todos',
        method: 'POST',
        body: todo.toJson(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteTodo(String id) async {
    // 1. Remove from cache immediately
    final todos = await getTodos();
    await cache.set<List<Todo>>(
      key: 'todos',
      data: todos.where((t) => t.id != id).toList(),
    );

    // 2. Queue for sync when online
    await cache.enqueueSyncTask(
      SyncTask(
        id: 'delete_$id',
        key: 'todos',
        endpoint: 'https://api.example.com/todos/$id',
        method: 'DELETE',
        body: id,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> toggleTodo(String id) async {
    final todos = await getTodos();
    final updatedTodos = todos.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(completed: !todo.completed);
      }
      return todo;
    }).toList();
    await cache.set<List<Todo>>(key: 'todos', data: updatedTodos);
  }

  @override
  bool updateShouldNotify(TodoService oldWidget) {
    return false;
  }
}

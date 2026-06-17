// ignore_for_file: inference_failure_on_function_invocation

import 'package:flutter/material.dart';
import 'package:smart_cache/smart_cache.dart';
import '../models/todo.dart';
import '../services/todo_service.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _controller = TextEditingController();
  bool _isOnline = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTodo() {
    if (_controller.text.trim().isEmpty) return;

    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _controller.text.trim(),
    );

    TodoService.of(context).addTodo(todo);
    _controller.clear();
  }

  void _deleteTodo(String id) {
    TodoService.of(context).deleteTodo(id);
  }

  void _toggleTodo(String id) {
    TodoService.of(context).toggleTodo(id);
  }

  void _toggleOnline() {
    setState(() => _isOnline = !_isOnline);
    NetworkStatus.setMockStatus(_isOnline);
  }

  @override
  Widget build(BuildContext context) {
    final todoService = TodoService.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Todos'),
        actions: [
          Row(
            children: [
              Switch(
                value: _isOnline,
                onChanged: (_) => _toggleOnline(),
              ),
              Text(_isOnline ? 'Online' : 'Offline'),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: SmartCacheBuilder<List<Todo>>(
        cache: todoService.cache,
        cacheKey: 'todos',
        builder: (context, todos) {
          if (todos == null || todos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No todos yet'),
                  Text('Add a todo to get started'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return ListTile(
                leading: Checkbox(
                  value: todo.completed,
                  onChanged: (_) => _toggleTodo(todo.id),
                ),
                title: Text(
                  todo.title,
                  style: TextStyle(
                    decoration: todo.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteTodo(todo.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Todo'),
              content: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Enter todo title',
                ),
                onSubmitted: (_) {
                  _addTodo();
                  Navigator.pop(context);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    _addTodo();
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
